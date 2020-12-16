function csc_idx = get_nlg_samples_from_timestamps(indices_of_first_samples,timestamps_of_first_samples_usec,audio2nlg,query_ts)

file_start_times = 1e-3*timestamps_of_first_samples_usec - audio2nlg.first_nlg_pulse_time;
file_idx = [find(file_start_times < query_ts(1),1,'last') find(file_start_times > query_ts(2),1,'first')];
if length(file_idx) < 2
    csc_idx = [];
    return
end
file_idx = file_idx(1):file_idx(2);

sample_idx = indices_of_first_samples(file_idx(1)):indices_of_first_samples(file_idx(end));
sample_timestamps = interp1(indices_of_first_samples(file_idx),file_start_times(file_idx),sample_idx);
[~,call_sample_idx] = inRange(sample_timestamps,query_ts);
csc_idx = sample_idx(call_sample_idx);

end