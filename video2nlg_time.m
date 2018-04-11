function corr_t = video2nlg_time(video2nlg,t)
%% Helper function to convert from Video time to NLG time.
% INPUT:
%
% audio2nlg: Structure of outputs from align_video_to_nlg with fields:
%   'shared_nlg_pulse_times','shared_video_pulse_times','first_video_pulse_time','first_nlg_pulse_time'
%
% t: Avisoft time in ms
%
% OUTPUT:
%
% corr_t: NLG time in ms

t = milliseconds(t - video2nlg.first_video_pulse_time);
aligned_shared_video_pulse_times = milliseconds((video2nlg.shared_video_pulse_times - video2nlg.first_video_pulse_time));
clock_differences_at_pulses = (video2nlg.shared_nlg_pulse_times - video2nlg.first_nlg_pulse_time) - aligned_shared_video_pulse_times;
estimated_clock_differences = interp1(aligned_shared_video_pulse_times,clock_differences_at_pulses,t,'linear','extrap');
corr_t = t  + estimated_clock_differences;
end
