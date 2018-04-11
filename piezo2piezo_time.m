function corr_t = piezo2piezo_time(piezo2piezo,t)
%% Helper function to convert from one piezo logger time to another.
% INPUT:
%
% piezo2piezo: Structure of outputs from align_avi_to_nlg with fields:
%   'shared_piezo_pulse_times','first_piezo_pulse_time'
%
% t: Piezo 2 time in ms
%
% OUTPUT:
%
% corr_t: Piezo 1 time in ms

t = t - piezo2piezo.first_piezo_pulse_time(2);
aligned_piezo_times = (piezo2piezo.shared_piezo_pulse_times{2} - piezo2piezo.first_piezo_pulse_time(2));
clock_differences_at_pulses = (piezo2piezo.shared_piezo_pulse_times{1} - piezo2piezo.first_piezo_pulse_time(1)) - aligned_piezo_times;
estimated_clock_differences = interp1(aligned_piezo_times,clock_differences_at_pulses,t,'linear','extrap');
corr_t = t + estimated_clock_differences;
end
