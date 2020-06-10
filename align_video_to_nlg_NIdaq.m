function [shared_nlg_pulse_times, shared_video_pulse_times, first_nlg_pulse_time, first_video_pulse_time] = align_video_to_nlg_NIdaq(video_dir,event_fname,cameraNum,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop,session_strings,varargin)
%%
% Function to correct for clock drift between avisoft audio recordings and
% NLG neural recordings.
%
% INPUT:
% base_dir: base directory of experiment. This script expects this
% directory to contain the subfolders 'audio\ch1\' and 'nlxformat\'.
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
% shared_nlg_pulse_times: times (ms) in NLG time when TTL pulses arrived on
% the NLG Tx. To be used with avi2nlg_time to locally interpolate
% differences between time on AVI and NLG and correct for those
% differences.
%
% shared_audio_pulse_times: times (ms) in AVI time when TTL pulses arrived 
% on the AVI recorder. To be used with avi2nlg_time to locally interpolate
% differences between time on AVI and NLG and correct for those
% differences.
%
% total_samples_by_file: number of audio samples in each audio file. Used
% in order to determine time within a given audio file that is part of a
% longer recording.
%
% first_nlg_pulse_time: time (ms, in NLG time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align audio and NLG
% times before scaling by estimated clock differences.
%
% first_audio_pulse_time: time (ms, in AVI time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align audio and NLG
% times before scaling by estimated clock differences.

pnames = {'nlg_off_by_day','out_of_order_correction'};
dflts  = {false,[]};
[nlg_off_by_day,out_of_order_correction] = internal.stats.parseArgs(pnames,dflts,varargin{:});

save_options_parameters_CD_figure = 1;

video_files = dir(fullfile(video_dir,['Camera ' num2str(cameraNum) '*.mp4']));
n_video_files = length(video_files);
eventMarkers = cell(1,n_video_files);

for f = 1:n_video_files
    video_fname = [video_files(f).folder filesep video_files(f).name];
        
    xmlFName = [video_fname(1:end-3) 'xml'];
    if exist(xmlFName,'file')
        eventMarkers{f} = getEventMarkerTimeStamps(xmlFName);
    end
    
end
eventMarkers = [eventMarkers{:}];

[video_pulse, video_pulse_times] = video_ttl2pulses(eventMarkers,ttl_pulse_dt/1e3);
%%

nlg_time_din = get_nlg_ttl_pulses(event_fname,session_strings,nlg_ttl_str,nlg_off_by_day);
[nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'correct_err',corr_pulse_err,'correct_end_off',correct_end_off,'correct_loop',correct_loop,'out_of_order_correction',out_of_order_correction);

%% synchronize video --> NLG
if length(unique(nlg_pulse))/length(nlg_pulse) ~= 1 || length(unique(video_pulse))/length(video_pulse) ~= 1 
    disp('repeated pulses!');
    keyboard;
end

[~, shared_pulse_nlg_idx, shared_pulse_video_idx] = intersect(nlg_pulse,video_pulse); % determine which pulses are on both the NLG and video recordings

% extract only shared pulses
shared_nlg_pulse_times = nlg_pulse_times(shared_pulse_nlg_idx);
shared_video_pulse_times = video_pulse_times(shared_pulse_video_idx);

first_nlg_pulse_time = shared_nlg_pulse_times(1);
first_video_pulse_time = shared_video_pulse_times(1);

aligned_shared_video_pulse_times = milliseconds((shared_video_pulse_times - first_video_pulse_time));

clock_differences_at_pulses = (shared_nlg_pulse_times - first_nlg_pulse_time) - aligned_shared_video_pulse_times; % determine difference between NLG and avisoft timestamps when pulses arrived

figure
hold on
plot(aligned_shared_video_pulse_times,clock_differences_at_pulses,'.-');
xlabel('Incoming Audio Pulse Times')
ylabel('Difference between NLG clock and avisoft clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,fullfile(video_dir,'CD_correction_video_nlg.fig'))
end
end