function corr_t = nlg2nlg_time(nlg2nlg,t)
%% Helper function to convert from one nlg logger time to another.
% INPUT:
%
% nlg2nlg: Structure of outputs from align_avi_to_nlg with fields:
%   'shared_nlg_pulse_times','first_nlg_pulse_time'
%
% t: nlg 2 time in ms
%
% OUTPUT:
%
% corr_t: nlg 1 time in ms

t = t - nlg2nlg.first_nlg_pulse_time(2);
aligned_nlg_times = (nlg2nlg.shared_nlg_pulse_times{2} - nlg2nlg.first_nlg_pulse_time(2));
clock_differences_at_pulses = (nlg2nlg.shared_nlg_pulse_times{1} - nlg2nlg.first_nlg_pulse_time(1)) - aligned_nlg_times;
estimated_clock_differences = interp1(aligned_nlg_times,clock_differences_at_pulses,t,'linear','extrap');
corr_t = t + estimated_clock_differences;
end
