function [shared_nlg_pulse_times, shared_audio_pulse_times, total_samples_by_file, first_nlg_pulse_time, first_audio_pulse_time] = align_avi_to_nlg(base_dir,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop,wav_file_nums,session_strings,varargin)
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
%%%
fs_wav = 250e3 + 21; % add in 21 to correct for difference between nominal avisoft clock time and actual clock time (value determined empirically)
avi_wav_bits = 16; % number of bits in each sample of avisoft data
wav2bit_factor = 2^(avi_wav_bits-1); % factor to convert .WAV data to bits readable by 'bitand' below

audio_dir = [base_dir 'audio\ch1\']; % where the audio .WAV files are stored
wav_files = dir([audio_dir '*.wav']); % all .WAV files in directory
wav_file_nums = find(cellfun(@(x) ismember(str2num(x(end-7:end-4)),wav_file_nums),{wav_files.name})); % extract only requested .WAV files
audio_time_din = [];
total_samples = 0;
total_samples_by_file = zeros(1,length(wav_files));
nlg_off_by_day = 0;
nlg_event_time_corr = (60*60*24)*1e6;

save_options_parameters_CD_figure = 1;

if ~isempty(varargin)
    out_of_order_correction = varargin{1};
    out_of_order = 1;
else
    out_of_order = 0;
end

for w = 1:max(wav_file_nums) % run through all requested .WAV files and extract audio data and TTL status at each sample
    if ismember(w,wav_file_nums)
        data = audioread([audio_dir wav_files(w).name]); % load audio data
        ttl_status = bitand(data*wav2bit_factor + wav2bit_factor,1); % read TTL status off least significant bit of data
        audio_time_din = [audio_time_din (1e3*(total_samples + find(sign(diff(ttl_status))~=0)')/fs_wav)];
        total_samples_by_file(w) = length(data);
        total_samples = total_samples + total_samples_by_file(w);
    else
        audio_info_struct = audioinfo([audio_dir wav_files(w).name]);
        total_samples_by_file(w) = audio_info_struct.TotalSamples;
        total_samples = total_samples + total_samples_by_file(w);
    end
end

if out_of_order
    [audio_pulses, audio_pulse_times] = ttl_times2pulses(audio_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop,out_of_order_correction); % extract TTL pulses and time
else
    [audio_pulses, audio_pulse_times] = ttl_times2pulses(audio_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop); % extract TTL pulses and time
end
%%

eventfile = [base_dir 'nlxformat\EVENTS.mat']; % load file with TTL status info
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

if nlg_off_by_day
    event_timestamps_usec = event_timestamps_usec - nlg_event_time_corr;
end

% extract only relevant TTL status changes
event_types_and_details = event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));

din = cellfun(@(x) ~isempty(strfind(x,'Digital in')),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes

if out_of_order
    [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop,out_of_order_correction); % extract TTL pulses and time
else
    [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop); % extract TTL pulses and time
end

%% synchronize audio --> NLG
if length(unique(nlg_pulse))/length(nlg_pulse) ~= 1 || length(unique(audio_pulses))/length(audio_pulses) ~= 1 
    display('repeated pulses!');
    keyboard;
end

[~, shared_pulse_nlg_idx, shared_pulse_audio_idx] = intersect(nlg_pulse,audio_pulses); % determine which pulses are on both the NLG and avisoft recordings

% extract only shared pulses
shared_nlg_pulse_times = nlg_pulse_times(shared_pulse_nlg_idx);
shared_audio_pulse_times = audio_pulse_times(shared_pulse_audio_idx);

first_nlg_pulse_time = shared_nlg_pulse_times(1);
first_audio_pulse_time = shared_audio_pulse_times(1);

clock_differences_at_pulses = (shared_nlg_pulse_times - first_nlg_pulse_time) - (shared_audio_pulse_times - first_audio_pulse_time); % determine difference between NLG and avisoft timestamps when pulses arrived

figure
hold on
plot(shared_audio_pulse_times-first_audio_pulse_time,clock_differences_at_pulses,'.-');
xlabel('Incoming Audio Pulse Times')
ylabel('Difference between NLG clock and avisoft clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,fullfile(audio_dir,'CD_correction_avisoft_nlg.fig'))
end
end