function [shared_nlg_pulse_times, shared_vid_pulse_times, first_nlg_pulse_time, first_vid_pulse_time] ...
    = align_video_to_nlg_aud(vid_dir,nlg_dir,corr_pulse_err,correct_end_off,correct_loop,session_strings,varargin)
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

pnames = {'audio_chunk_size','nlg_off_by_day','out_of_order_correction'};
dflts  = {2^8,false,[]};
[audio_chunk_size,nlg_off_by_day,out_of_order_correction] = internal.stats.parseArgs(pnames,dflts,varargin{:});

save_options_parameters_CD_figure = true;
nlg_ttl_str = 'Digital input port status';

 % extract TTL pulses and time
 
[vid_time_din,vid_time_din_sample] = get_vid_ttl_pulses_from_aud(vid_dir,audio_chunk_size);
[vid_pulses, ~ ,used_time_idx] = ttl_times2pulses(vid_time_din_sample,'correct_err',corr_pulse_err,'correct_end_off',correct_end_off,'correct_loop',correct_loop,'out_of_order_correction',out_of_order_correction); 
vid_pulse_times = vid_time_din(used_time_idx);

nlg_time_din = get_nlg_ttl_pulses(nlg_dir,session_strings,nlg_ttl_str,nlg_off_by_day);
[nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'correct_err',corr_pulse_err,'correct_end_off',correct_end_off,'correct_loop',correct_loop,'out_of_order_correction',out_of_order_correction);


%% synchronize audio --> NLG
if length(unique(nlg_pulse))/length(nlg_pulse) ~= 1 || length(unique(vid_pulses))/length(vid_pulses) ~= 1 
    disp('repeated pulses!');
    keyboard;
end

[~, shared_pulse_nlg_idx, shared_pulse_audio_idx] = intersect(nlg_pulse,vid_pulses); % determine which pulses are on both the NLG and avisoft recordings

% extract only shared pulses
shared_nlg_pulse_times = nlg_pulse_times(shared_pulse_nlg_idx);
shared_vid_pulse_times = vid_pulse_times(shared_pulse_audio_idx);

first_nlg_pulse_time = shared_nlg_pulse_times(1);
first_vid_pulse_time = shared_vid_pulse_times(1);

clock_differences_at_pulses = (shared_nlg_pulse_times - first_nlg_pulse_time) - milliseconds(shared_vid_pulse_times - first_vid_pulse_time); % determine difference between NLG and avisoft timestamps when pulses arrived
clock_diff_range = median(clock_differences_at_pulses(end-10:end)) - median(clock_differences_at_pulses(1:10));
err_differences_idx = find(diff(abs(clock_differences_at_pulses)) > clock_diff_range) + 1;
clock_differences_at_pulses(err_differences_idx) = [];
shared_vid_pulse_times(err_differences_idx) = [];
shared_nlg_pulse_times(err_differences_idx) = [];

figure
hold on
plot(shared_vid_pulse_times-first_vid_pulse_time,clock_differences_at_pulses,'.-');
xlabel('Incoming Video Pulse Times')
ylabel('Difference between NLG clock and video clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,fullfile(vid_dir,'CD_correction_video_nlg.fig'))
end
end