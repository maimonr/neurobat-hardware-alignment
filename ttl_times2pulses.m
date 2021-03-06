function [pulse_idx, pulse_time, used_time_idx] = ttl_times2pulses(times,varargin)
%%%
% Decodes spacing between TTL pulses into unique numbers
% INPUTS
% times: vector of times when TTL status changed (both on and off) in
% units of ms
%
% pulse_dt: time (ms) between pulses. Use a time less than the minimum time
% between pulses (e.g. with 5s spacing and a maximum pulse train length of
% 75ms, use approx. 4.9s; however, 4s would be sufficient)
%
% correct_err: 1 to find and correct out-of-order pulses due to e.g.
% misreading of TTL time by NLG or rounding error. Will not correct looping
% of unique TTL files. 0 to not correct for these errors.
%
% correct_end_off: 1 to find and correct erroneous 'off' TTL at the end of
% the zero playback files. 0 to not correct for these errors.
%
% correct_loop: 1 to find and correct for looping through playback files
% (e.g. if only 1 hr of playback files are prepared, and recording lasts
% 1.5 hrs). NOTE: will only correct for ONE loop, >1 loops will
% throw an error. 0 to not correct for this error.
%
% OPTIONAL INPUT:
% If the playback of TTL pulse files is out of order or random such that
% the pulses coming into avisoft are not monotonically increasing, include
% a vector
%
% NOTE: Using correct_end_off and correct_loop can be avoided by better
% constructing zero playback files (i.e. removing 'off' TTL at the end of
% files, and preparing enough total files for recording time).
%
% OUTPUTS
% pulse_idx: vector of length of the number of pulses counted. Should
% contain the vector 1:n_pulses if decoding worked properly.
%
% pulse_time: time in ms from input 'times' when each pulse occurred.
%
% err_pulses: index of pulses in 'pulse_idx' where a pulse was out of
% order.
%
% ENCODING SCHEME: This script expects TTL pulses to be encoded in the
% following manner: every dt>pulse_dt a pulse train arrives encoding for a
% number in the sequence 1,2,3,4... always increasing by 1, but not
% necessarily starting with 1. Each pulse train is composed of a variable
% number of TTL pulses spaced by 15 ms (due to limitations imposed by NLG
% hardware). Each pulse within a pulse train is between 5 and 14 ms
% (minimum pulse length is also dictated by NLG hardware limitations). In
% order to decode these pulse trains, differences between each change in
% TTL status are calculated. Every other one of those differences are
% extracted (i.e. we skip the 15ms spacing between pulses) and 5 is
% subtracted from that time difference. The resulting numbers are strung
% together to form the digits of the pulse number we are decoding.
% E.G. :
% 5s after the last pulse we see a set of TTL status change times spaced by
% 6, 15, 7, 15, and 13 ms. We look at every other number (odd indices) and subtract 5,
% arriving at 1,2,8 which stands for the 128th pulse in sequence. The time
% when the 6ms long pulse arrived is stored as the 'pulse_time'
% correspoding to the element of 'pulse_idx' stored as 128.
%
% Maimon Rose 9/2/16, further comented by Julie E Elie
%%%

unique_ttl_fname = which('unique_ttl_params.mat');
if isempty(unique_ttl_fname)
    if strcmp(getenv('USER'), 'elie')
        unique_ttls_dir_dflt = '/Volumes/JulieBatsDrive/';
    else
        unique_ttls_dir_dflt  = 'C:\Users\phyllo\Documents\Maimon\misc\nlg_alignment\unique_ttls\';
    end
else
    unique_ttls_dir_dflt = fileparts(unique_ttl_fname);
end
pnames = {'pulse_dt','min_pulse_dt','correct_err','correct_end_off','correct_loop','check_loop_twice','manual_bad_err_corr','min_pulse_value','out_of_order_correction','unique_ttls_dir'};
dflts  = {4e3,0.1,1,0,0,0,0,5,[],unique_ttls_dir_dflt};
[pulse_dt,min_pulse_dt,correct_err,correct_end_off,correct_loop,check_loop_twice,manual_bad_err_corr,min_pulse_value,out_of_order_correction,unique_ttls_dir] = internal.stats.parseArgs(pnames,dflts,varargin{:});

if isdatetime(times)
    ttl_diffs = milliseconds(diff(times));
else
    ttl_diffs = diff(times);
end

used_time_idx = 1:length(times);

ttl_diff_idx = [true ttl_diffs > min_pulse_dt];
times = times(ttl_diff_idx);
used_time_idx = used_time_idx(ttl_diff_idx);

if isdatetime(times)
    ttl_diffs = milliseconds(diff(times));
    extraMillisecond = milliseconds(1);
else
    ttl_diffs = diff(times);
    extraMillisecond = 1;
end

chunk_times = [times(1) times(ttl_diffs>pulse_dt) times(end)]; % time points that are at the end of each TTL pulse train 
diffs_chunk = ttl_diffs(ttl_diffs>pulse_dt); % durations of all inter-pulse train intervals in the recording
[chunks,idx_chunks] = deal(cell(1,length(diffs_chunk))); % will contain all the time point of TTL status change for each the set of (inter-pulse train interval + pulse train)

out_of_order = ~isempty(out_of_order_correction);

%% Loop through detected  sets of (inter-pulse train interval + pulse train) and retrieve pulse index
for chunk = 1:length(diffs_chunk) % we could potentially miss the last TTL pulse if there was less than 4s of recording after it?
    chunk_on = chunk_times(chunk);
    chunk_off = chunk_times(chunk+1) + extraMillisecond; % This +1ms could be replaced by <= in the following lines: (times<=chunk_off)?
    if chunk == 1
        current_chunk_idx = (times>=chunk_on) & (times<chunk_off);
        chunks{chunk} = times(current_chunk_idx);
        idx_chunks{chunk} = used_time_idx(current_chunk_idx);
    else
        current_chunk_idx = (times>chunk_on) & (times<chunk_off);
        chunks{chunk} = times(current_chunk_idx);
        idx_chunks{chunk} = used_time_idx(current_chunk_idx);
    end
end
idx_chunks = idx_chunks(cellfun(@length,chunks)>1);
chunks = chunks(cellfun(@length,chunks)>1);
pulse_time = cellfun(@(x) x(1),chunks); % time of first rising edge in each pulse train
used_time_idx = cellfun(@(x) x(1),idx_chunks);

if isdatetime(times)
    chunk_diffs = cellfun(@(x) round(milliseconds(diff(x))),chunks,'UniformOutput',0); % durations between each raising or falling edges in the pulse train
else
    chunk_diffs = cellfun(@(x) round(diff(x)),chunks,'UniformOutput',0); % durations between each raising or falling edges in the pulse train
end
pulse_idx = cellfun(@(x) str2double(regexprep(num2str(x(1:2:length(x)) - min_pulse_value),'[^\w'']','')),chunk_diffs); % Pulse indices
pulse_idx_orig = pulse_idx; % save these pulses indices before applying further checks

%% Deal with errors of TTL pulses detection
err_pulses = intersect(find(pulse_idx - [pulse_idx(1)-1 pulse_idx(1:end-1)]~=1),... find pulses which 'stick out' from both neighboring pulses
    find(pulse_idx-[pulse_idx(2:end) pulse_idx(end)+1]~=-1));
% Should be find(diff(pulse_idx) ~= 1)) if we want to find any
% discrepancy...
if correct_end_off % end of 'zero signal' TTL file may have erroneous TTL pulse at end, correct if so
    load(fullfile(unique_ttls_dir,'unique_ttl_params.mat'),'n_pulse_per_chunk');
    end_offs = err_pulses(rem(pulse_idx(err_pulses-1),n_pulse_per_chunk)==0); % check if erroneous TTL pulse comes at end of chunk (i.e. end of unique TTL file) by find err pulses with rem(pulse_idx,n_pulse_per_chunk) = 0
    end_offs = union(end_offs,find(isnan(pulse_idx)));
    pulse_idx(end_offs) = []; % remove those pulses
    pulse_time(end_offs) = [];
    used_time_idx(end_offs) = [];
end

if out_of_order
    if length(pulse_idx) == length(out_of_order_correction)
        pulse_idx = pulse_idx + out_of_order_correction;
    else
        disp('correction of different length than pulses');
        keyboard;
    end
end

if correct_loop
    [pulse_idx, check_loop_twice] = check_loop(pulse_idx,unique_ttls_dir);
end

if correct_err
    [pulse_idx, pulse_time, used_time_idx] = correct_lone_pulse_errors(pulse_idx,pulse_time,used_time_idx,manual_bad_err_corr);
    [pulse_idx, pulse_time, used_time_idx] = correct_out_of_order_pulse_errors(pulse_idx,pulse_time,used_time_idx);
end

if check_loop_twice
    disp('checking for loop after correcting for errors');
    [pulse_idx, ~] = check_loop(pulse_idx,unique_ttls_dir); 
end

figure;
hold on
plot(pulse_idx_orig,'rx');
plot(pulse_idx);
xlabel('pulse rank')
ylabel('pulse index')
legend('original pulse indices', 'indices after correction')
end

function [pulse_idx, check_loop_twice] = check_loop(pulse_idx,unique_ttls_dir)
load(fullfile(unique_ttls_dir,'unique_ttl_params.mat'),'n_pulse_per_chunk','n_chunk');
loop_rep_idx = find(pulse_idx==n_pulse_per_chunk*n_chunk);
expected_num_rep = floor(length(pulse_idx)/(n_pulse_per_chunk*n_chunk));

if length(loop_rep_idx) ~= expected_num_rep
    fprintf('Expected %d repetitions, %d repetitions found \n',expected_num_rep,length(loop_rep_idx))
    disp(['loop points at ' num2str(loop_rep_idx)])
    keyboard
    loop_rep_idx = input('input correct loop point idxs');
    pulse_idx(loop_rep_idx) = n_pulse_per_chunk*n_chunk;
end

if isempty(loop_rep_idx)
    check_loop_twice = 1;
    disp('no loop found!');
elseif length(loop_rep_idx) == 1
    pulse_idx(loop_rep_idx+1:end) = pulse_idx(loop_rep_idx+1:end) + pulse_idx(loop_rep_idx);
    check_loop_twice = 0;
else
    try
        assert(~any(mod(loop_rep_idx,n_pulse_per_chunk*n_chunk)))
    catch
        disp(['loop points at ' num2str(loop_rep_idx)])
        disp('loop points out of order, enter loop point idxs')
        keyboard
        loop_rep_idx = input('input correct loop point idxs');
    end
    if length(loop_rep_idx) > 1
        for loop = loop_rep_idx
            if length(pulse_idx)>loop
                pulse_idx(loop+1:end) = pulse_idx(loop+1:end) + pulse_idx(loop) - (pulse_idx(loop+1)-1);
            end
        end
    else
        pulse_idx(loop_rep_idx+1:end) = pulse_idx(loop_rep_idx+1:end) + pulse_idx(loop_rep_idx);
    end
    check_loop_twice = 0;
end
end

function [pulse_idx, pulse_time, used_time_idx] = correct_lone_pulse_errors(pulse_idx,pulse_time,used_time_idx,manual_bad_err_corr)

err_pulses = intersect(find(pulse_idx-[pulse_idx(1)-1 pulse_idx(1:end-1)]~=1),... 
    find(pulse_idx-[pulse_idx(2:end) pulse_idx(end)+1]~=-1));

if pulse_idx(end) - pulse_idx(end-1) ~=1
    err_pulses = [err_pulses length(pulse_idx)];
end

if sum(diff(err_pulses)<2)~=0
    disp([num2str(sum(diff(err_pulses)<2)) ' adjacent error pulses!']);
    if manual_bad_err_corr
        bad_err = err_pulses([diff(err_pulses)<2 false] | [false fliplr(abs(diff(fliplr(err_pulses)))<2)]);
        err_pulses = setdiff(err_pulses,bad_err);
        try
            pulse_idx(err_pulses) = pulse_idx(err_pulses-1)+1;
        catch
            pulse_idx(err_pulses) = pulse_idx(err_pulses+1)-1;
        end
        keyboard;
        for err_k = 1:length(bad_err)
            return_to_code = input('return to code?');
            if return_to_code == 1
                keyboard;
            end
            replace_bad_err = input('replace (1) bad error pulse or remove (2) bad error pulse and surrounding pulses?');
            if replace_bad_err == 1
                display(['bad error pulse value and adjacent values: ' num2str(pulse_idx([bad_err(err_k)-1 bad_err(err_k) bad_err(err_k)+1]))]);
                pulse_idx(bad_err(err_k)) = input(['replace pulse idx of ' num2str(pulse_idx(bad_err(err_k))) ' with what value?']);
            elseif replace_bad_err == 2
                bad_err_to_remove = [bad_err(err_k) bad_err(err_k)+1 bad_err(err_k)-1];
                bad_err_to_remove = bad_err_to_remove(bad_err_to_remove>1 & bad_err_to_remove<=length(pulse_idx));
                pulse_idx(bad_err_to_remove) = [];
                pulse_time(bad_err_to_remove) = [];
                used_time_idx(bad_err_to_remove) = [];
            end
        end
    else
        bad_err = err_pulses([diff(err_pulses)<2 false] | [false fliplr(abs(diff(fliplr(err_pulses)))<2)]);
        err_pulses = setdiff(err_pulses,bad_err);
        try
            pulse_idx(err_pulses) = pulse_idx(err_pulses-1)+1;
        catch
            pulse_idx(err_pulses) = pulse_idx(err_pulses+1)-1;
        end
        bad_err_to_remove = [];
        for err_k = 1:length(bad_err)
            bad_err_to_remove = [bad_err_to_remove bad_err(err_k) bad_err(err_k)+1 bad_err(err_k)-1]; %#ok<AGROW>
        end
        bad_err_to_remove = bad_err_to_remove(bad_err_to_remove>1 & bad_err_to_remove<=length(pulse_idx));
        bad_err_to_remove = unique(bad_err_to_remove);
        pulse_idx(bad_err_to_remove) = [];
        pulse_time(bad_err_to_remove) = [];
        used_time_idx(bad_err_to_remove) = [];
    end
else
    try
        pulse_idx(err_pulses) = pulse_idx(err_pulses-1)+1;
    catch
        pulse_idx(err_pulses) = pulse_idx(err_pulses+1)-1;
    end
end

end

function [pulse_idx, pulse_time, used_time_idx] = correct_out_of_order_pulse_errors(pulse_idx,pulse_time,used_time_idx)

err_pulses = find(diff(pulse_idx)<1,1);

while ~isempty(err_pulses)
    err_to_remove = [err_pulses-1 err_pulses err_pulses+1];
    pulse_idx(err_to_remove) = [];
    pulse_time(err_to_remove) = [];
    used_time_idx(err_to_remove) = [];
    err_pulses = find(diff(pulse_idx)<1,1);
end

end