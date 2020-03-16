function [shared_nlg_pulse_times, shared_audio_pulse_times, total_samples_by_file, first_nlg_pulse_time, first_audio_pulse_time] ...
    = align_avi_to_nlg(audio_dir,nlg_dir,corr_pulse_err,correct_end_off,correct_loop,session_strings,varargin)
%%
% Function to correct for clock drift between avisoft audio recordings and
% NLG neural recordings.
%
% INPUT:
% audio_dir: directory with .wav files that include TTL pulses to align
%
% nlg_dir: directory with EVENT file that includes TTL pulses to align
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

pnames = {'fs_wav','wav_file_nums','nlg_off_by_day','out_of_order_correction'};
dflts  = {250e3,[],false,[]};
[fs_wav,wav_file_nums,nlg_off_by_day,out_of_order_correction] = internal.stats.parseArgs(pnames,dflts,varargin{:});

save_options_parameters_CD_figure = 1;
nlg_ttl_str = 'Digital input port status';

 % extract TTL pulses and time

[audio_time_din, total_samples_by_file] = get_avi_ttl_pulses(audio_dir,wav_file_nums,fs_wav);
[audio_pulses, audio_pulse_times] = ttl_times2pulses(audio_time_din,'correct_err',corr_pulse_err,'correct_end_off',correct_end_off,'correct_loop',correct_loop,'out_of_order_correction',out_of_order_correction);

%%

nlg_time_din = get_nlg_ttl_pulses(nlg_dir,session_strings,nlg_ttl_str,nlg_off_by_day);
[nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'correct_err',corr_pulse_err,'correct_end_off',correct_end_off,'correct_loop',correct_loop,'out_of_order_correction',out_of_order_correction);


%% synchronize audio --> NLG
if length(unique(nlg_pulse))/length(nlg_pulse) ~= 1 || length(unique(audio_pulses))/length(audio_pulses) ~= 1 
    disp('repeated pulses!');
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