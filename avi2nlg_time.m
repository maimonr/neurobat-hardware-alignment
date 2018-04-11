function corr_t = avi2nlg_time(audio2nlg,t)
%% Helper function to convert from Avisoft time to NLG time.
% INPUT:
%
% audio2nlg: Structure of outputs from align_avi_to_nlg with fields:
%   'shared_nlg_pulse_times','shared_audio_pulse_times','total_samples_by_file','first_audio_pulse_time','first_nlg_pulse_time'
%
% t: Avisoft time in ms
%
% OUTPUT:
%
% corr_t: NLG time in ms

t = t - audio2nlg.first_audio_pulse_time; % align audio time to first TTL pulse
aligned_audio_pulses = (audio2nlg.shared_audio_pulse_times - audio2nlg.first_audio_pulse_time); % align audio pulses to first TTL pulse
clock_differences_at_pulses = (audio2nlg.shared_nlg_pulse_times - audio2nlg.first_nlg_pulse_time) - aligned_audio_pulses; % align NLG time and assess time differences across pulses
estimated_clock_differences = interp1(aligned_audio_pulses,clock_differences_at_pulses,t,'linear','extrap'); % interpolate (and possibly extrapolate) time differences all points requested in t
corr_t = t + estimated_clock_differences; % correct audio time by adding in differences from NLG time
end
