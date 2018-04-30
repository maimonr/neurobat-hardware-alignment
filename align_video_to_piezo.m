function [shared_piezo_pulse_times, shared_video_pulse_times, first_piezo_pulse_time, first_video_pulse_time] = align_video_to_piezo(base_dir,cameraNum,ttl_pulse_dt,logger_num,session_strings,varargin)
%%
% Function to correct for clock drift between streampix video recordings and
% piezoelectric audio recordings.
%
% INPUT:
% base_dir: base directory of experiment. This script expects this
% directory to contain the subfolders 'video\Camera #\' and 'piezo_data\'.
%
% ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop: see help for
% ttl_times2pulses.m
%
% wav_file_nums: vector of integers correspoding to .WAV file numbers to
% analyze.
%
% session_strings: cell of strings used to demarcate start and stop of
% time period to analyze in this script from EVENTLOG file.
%
% OUTPUT:
%
% shared_piezo_pulse_times: times (ms) in piezo time when TTL pulses arrived on
% the piezo Tx. To be used with video2piezo_time to locally interpolate
% differences between time on streampix and piezo and correct for those
% differences.
%
% shared_video_pulse_times: times (ms) in streampix time when TTL pulses arrived 
% on streampix. To be used with video2piezo_time to locally interpolate
% differences between time on video and piezo and correct for those
% differences.
%
%
% first_piezo_pulse_time: time (ms, in piezo time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align video and piezo
% times before scaling by estimated clock differences.
%
% first_video_pulse_time: time (ms, in video time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align video and piezo
% times before scaling by estimated clock differences.

if ~isempty(varargin)
    out_of_order_correction = varargin{1};
    out_of_order = 1;
else
    out_of_order = 0;
end

corr_pulse_err = true;
correct_end_off = true;
correct_loop = true;

save_options_parameters_CD_figure = 1;
%%%

video_dir = [base_dir 'video' filesep 'Camera '  num2str(cameraNum) filesep];

video_files = dir([video_dir '*.mp4']);
n_video_files = length(video_files);
eventMarkers = cell(1,n_video_files);

for f = 1:n_video_files
    video_fname = [video_files(f).folder filesep video_files(f).name];
        
    xmlFName = [video_fname(1:end-3) 'xml'];
    eventMarkers{f} = getEventMarkerTimeStamps(xmlFName);
    
end
eventMarkers = [eventMarkers{:}];

[video_pulse, video_pulse_times] = video_ttl2pulses(eventMarkers,ttl_pulse_dt/1e3);
%%

eventfile = [base_dir 'piezo_data' fiesep 'logger' num2str(logger_num) filesep 'EVENTS.mat']; % load file with TTL status info
load(eventfile);

session_start_and_end = zeros(1,2);
start_end = {'start','end'};

for s = 1:2
    session_string_pos = find(cellfun(@(x) ~isempty(strfind(x,session_strings{s})),event_types_and_details));
    if numel(session_string_pos) ~= 1
        if numel(session_string_pos) > 1
            display(['more than one session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
        elseif numel(session_string_pos) == 0
            display(['couldn''t find session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
        end
        keyboard;
        session_string_pos = input('input index into variable event_types_and_details');
    end
    session_start_and_end(s) = event_timestamps_usec(session_string_pos);
end

% extract only relevant TTL status changes
event_types_and_details = event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));

din = cellfun(@(x) contains(x,'Digital in'),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes

if out_of_order
    [piezo_pulse, piezo_pulse_times] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop,out_of_order_correction); % extract TTL pulses and time
else
    [piezo_pulse, piezo_pulse_times] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop); % extract TTL pulses and time
end

%% synchronize video --> NLG
if length(unique(piezo_pulse))/length(piezo_pulse) ~= 1 || length(unique(video_pulse))/length(video_pulse) ~= 1 
    display('repeated pulses!');
    keyboard;
end

[~, shared_pulse_piezo_idx, shared_pulse_video_idx] = intersect(piezo_pulse,video_pulse); % determine which pulses are on both the NLG and video recordings

% extract only shared pulses
shared_piezo_pulse_times = piezo_pulse_times(shared_pulse_piezo_idx);
shared_video_pulse_times = video_pulse_times(shared_pulse_video_idx);

first_piezo_pulse_time = shared_piezo_pulse_times(1);
first_video_pulse_time = shared_video_pulse_times(1);

aligned_shared_video_pulse_times = milliseconds((shared_video_pulse_times - first_video_pulse_time));

clock_differences_at_pulses = (shared_piezo_pulse_times - first_piezo_pulse_time) - aligned_shared_video_pulse_times; % determine difference between NLG and avisoft timestamps when pulses arrived

figure
hold on
plot(aligned_shared_video_pulse_times,clock_differences_at_pulses,'.-');
xlabel('Incoming Audio Pulse Times')
ylabel('Difference between NLG clock and avisoft clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,fullfile(video_dir,'CD_correction_video_piezo.fig'))
end
end