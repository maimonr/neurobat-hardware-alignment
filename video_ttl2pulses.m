function [pulse_idx, pulse_time] = video_ttl2pulses(eventMarkers,pulse_dt)
if strcmp(getenv('USER'), 'elie')
    unique_ttls_dir = '/Volumes/JulieBatsDrive/';
else
    unique_ttls_dir = 'C:\Users\phyllo\Documents\Maimon\misc\nlg_alignment\unique_ttls\';
end

pulse_edges_per_digit = 2;
times = [eventMarkers.TimeString];
ttl_diffs = seconds(diff(times));
chunk_times = [times(1) times(ttl_diffs>pulse_dt) times(1)];
diffs_chunk = ttl_diffs(ttl_diffs>pulse_dt);
n_chunks = length(diffs_chunk);
chunks = cell(1,n_chunks);
for chunk = 1:n_chunks
    chunk_on = chunk_times(chunk);
    chunk_off = chunk_times(chunk+1) + seconds(1e-3);
    if chunk == 1
        chunks{chunk} = times((times>=chunk_on) & (times<chunk_off));
    else
        chunks{chunk} = times((times>chunk_on) & (times<chunk_off));
    end
end
chunk_lengths = cellfun(@length,chunks);
pulse_time = cellfun(@(x) x(1),chunks);

unique_ttl_info = load(fullfile(unique_ttls_dir, 'unique_ttl_params.mat'),'n_pulse_per_chunk','n_chunk','delay','fs');
chunk_delay = unique_ttl_info.delay/unique_ttl_info.fs;

inter_file_diffs = unique_ttl_info.n_pulse_per_chunk:(unique_ttl_info.n_pulse_per_chunk):n_chunks;
pulse_idx = 1:n_chunks;

try
    assert(all(abs(diffs_chunk(inter_file_diffs) - 2*chunk_delay)<1));
    assert(all(abs(diffs_chunk(setdiff(1:n_chunks,inter_file_diffs)) - chunk_delay)<1));
    
    n_unique_pulses = unique_ttl_info.n_pulse_per_chunk*unique_ttl_info.n_chunk;
    
    proper_digit_pattern = ceil(max(1,log10(max(1,abs(mod(1:n_chunks,n_unique_pulses))+1))));
    loop_points = rem(1:n_chunks,n_unique_pulses)==0;
    proper_digit_pattern(loop_points) = ceil(max(log10(max(1,abs(n_unique_pulses)+1)),1));
    
    assert(all(chunk_lengths/pulse_edges_per_digit == proper_digit_pattern))    
catch err
    keyboard
end
end

function pulse_idx = correct_missing_chunks(pulse_idx,diffs_chunk,chunk_delay,inter_file_diffs)

pulse_idx_orig = pulse_idx;
error_tolerance = 1;
error_idx = find((diffs_chunk ./ [1 diff(pulse_idx)])>(chunk_delay+error_tolerance));
[~,error_pulse_idx] = setdiff(pulse_idx(error_idx),inter_file_diffs);

while ~isempty(error_pulse_idx)
    pulse_idx(error_idx(error_pulse_idx(1)):end) = pulse_idx(error_idx(error_pulse_idx(1)):end)+1;
    error_idx = find((diffs_chunk ./ [1 diff(pulse_idx)])>(chunk_delay+error_tolerance));
    [~,error_pulse_idx] = setdiff(pulse_idx(error_idx),inter_file_diffs);
end

keyboard;
end