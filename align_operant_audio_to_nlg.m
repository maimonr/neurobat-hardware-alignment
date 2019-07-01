function [shared_nlg_pulse_times, shared_audio_pulse_times, total_samples_by_file, first_nlg_pulse_time, first_audio_pulse_time] ...
    = align_operant_audio_to_nlg(audio_dir,logger_dir,exp_start_time,session_strings,varargin)
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
fs_audio = 192e3; % add in 21 to correct for difference between nominal avisoft clock time and actual clock time (value determined empirically)
ttl_level_threshold = 0.5;
save_options_parameters_CD_figure = 1;
nlg_ttl_str = 'pin number 1';

ttl_params_fname = dir(fullfile(audio_dir,['*' exp_start_time 'unique_ttl_params.mat']));
if isempty(ttl_params_fname)
    ttl_params_fname = dir('Y:\users\maimon\adult_operant_recording\190328_0923unique_ttl_params.mat');
end
    
ttl_params = load(fullfile(ttl_params_fname.folder,ttl_params_fname.name));

min_ttl_separation = ttl_params.Min_ttl_length-2; % in ms

ttl_file_fnames = dir(fullfile(audio_dir, sprintf('*%s*ttl*.wav',exp_start_time)));% all ttl recordings .WAV files for the requested experiment/session (soundmexpro format)
ttl_file_numbers = cellfun(@(x) str2double(x(strfind(x,'ttl_')+length('ttl_'):strfind(x,'.wav')-1)),{ttl_file_fnames.name});
[~,ttl_file_order] = sort(ttl_file_numbers,'ascend');
ttl_file_fnames = ttl_file_fnames(ttl_file_order);
ttl_file_numbers = ttl_file_numbers(ttl_file_order);
n_ttl_files = length(ttl_file_fnames);

assert(all(diff(ttl_file_numbers)==1))

wav_file_fnames = dir(fullfile(audio_dir, sprintf('*%s*mic1*.wav',exp_start_time)));% all ttl recordings .WAV files for the requested experiment/session (soundmexpro format)
wav_file_numbers = cellfun(@(x) str2double(x(strfind(x,'mic1_')+length('mic1_'):strfind(x,'.wav')-1)),{wav_file_fnames.name});
[~,wav_file_order] = sort(wav_file_numbers,'ascend');
wav_file_fnames = wav_file_fnames(wav_file_order);

mismatch_samples = zeros(1,n_ttl_files);

if any([wav_file_fnames.bytes] ~= [ttl_file_fnames.bytes])
   disp('Mismatch in TTL vs WAV file samples')
   keyboard
   fix_mismatch_flag = input('Attempt to fix mismatched TTL & WAV files?');
   if fix_mismatch_flag
       for k = find([wav_file_fnames.bytes] ~= [ttl_file_fnames.bytes])
           audio_info(1) = audioinfo(fullfile(wav_file_fnames(k).folder,wav_file_fnames(k).name));
           audio_info(2) = audioinfo(fullfile(ttl_file_fnames(k).folder,ttl_file_fnames(k).name));
           mismatch_samples(k) = diff([audio_info.TotalSamples]);
       end
   end
end


audio_ttl_pulse_times = [];
total_samples = 0;
total_samples_by_file = zeros(1,n_ttl_files);

if ~isempty(varargin)
    out_of_order_correction = varargin{1};
    out_of_order = 1;
else
    out_of_order = 0;
end

for k = 1:n_ttl_files % run through all requested .WAV files and extract audio data and TTL status at each sample
    
    try
        [ttl_status, fs] = audioread(fullfile(ttl_file_fnames(k).folder, ttl_file_fnames(k).name));
    catch err
        if strcmp(err.identifier,'MATLAB:audiovideo:audioread:endoffile')
            continue
        end
    end
    
    assert(fs == fs_audio)
    
    if mismatch_samples(k) > 0
        ttl_status = ttl_status(1+mismatch_samples(k):end);
    elseif mismatch_samples(k) < 0
        ttl_status = [zeros(abs(mismatch_samples(k)),1); ttl_status];
    end
    
    ttl_pulse_times = (1e3*(total_samples + find(abs(diff(ttl_status))>ttl_level_threshold)')/fs_audio);
    ttl_pulse_times = ttl_pulse_times([true diff(ttl_pulse_times)> min_ttl_separation]);
    
    audio_ttl_pulse_times = [audio_ttl_pulse_times ttl_pulse_times];
    total_samples_by_file(k) = length(ttl_status);
    total_samples = total_samples + total_samples_by_file(k);
    
end

if out_of_order
    [audio_pulses, audio_pulse_times] = ttl_times2pulses(audio_ttl_pulse_times,'out_of_order_correction',out_of_order_correction); % extract TTL pulses and time
else
    [audio_pulses, audio_pulse_times] = ttl_times2pulses(audio_ttl_pulse_times); % extract TTL pulses and time
end

% delays between files are in increments of samples per buffer (e.g. 1024).
% This can be seen by finding the increments between the observed file
% change times which only take on a limited number of values. To correct
% for this, find the difference between the observed and expected interval
% between adjacent TTL pulse (e.g. 5s) and add that amount of time back to
% all times in that file. 

%%
% inter_pulse_times =  diff(audio_pulse_times);
% file_change_ttl_idx = find([false inter_pulse_times-ttl_separation<-1 & rem(audio_pulses(1:end-1),n_pulse_per_file)==0]);
% n_file_change_ttls = length(file_change_ttl_idx);
% 
% if n_file_change_ttls ~= n_ttl_files-1
%    disp('mismatch between file change correction and number of ttl files')
%    keyboard
% end
% 
% file_change_dT = ttl_separation - inter_pulse_times(file_change_ttl_idx-1);
% 
% audio_pulse_times_file_change_corrected = audio_pulse_times;
% for k = 1:n_file_change_ttls 
%     audio_pulse_times_file_change_corrected(file_change_ttl_idx(k):end) = audio_pulse_times_file_change_corrected(file_change_ttl_idx(k):end) + file_change_dT(k);
% end
% 
% audio_pulse_time_orig = audio_pulse_times;
% audio_pulse_times = audio_pulse_times_file_change_corrected;

%%

eventfile = dir(fullfile(logger_dir,'*EVENTS.mat')); % load file with TTL status info
assert(length(eventfile)==1)
s = load(fullfile(eventfile.folder,eventfile.name));
event_types_and_details = s.event_types_and_details;
event_timestamps_usec = s.event_timestamps_usec;

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


%% extract only relevant TTL status changes
event_types_and_details = event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));

din = cellfun(@(x) contains(x,nlg_ttl_str),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes

if out_of_order
    [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'out_of_order_correction',out_of_order_correction); % extract TTL pulses and time
else
    [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din); % extract TTL pulses and time
end

%%
loop_rep_idx = find(diff(nlg_pulse)>1);
%%
if ~isempty(loop_rep_idx)
    disp('Repeated pulses detected, attempt to correct for looped pulses?')
    keyboard
    correct_loop = input('Correct loop?');
    if correct_loop
        if length(loop_rep_idx) > 1
            for loop = loop_rep_idx
                if length(nlg_pulse)>loop
                    nlg_pulse(loop+1:end) = nlg_pulse(loop+1:end) + nlg_pulse(loop) - (nlg_pulse(loop+1)-1);
                end
            end
        else
            nlg_pulse(loop_rep_idx+1:end) = nlg_pulse(loop_rep_idx+1:end) + nlg_pulse(loop_rep_idx);
        end
    end
end
%%

r = corrcoef(nlg_pulse,1:length(nlg_pulse));

if r(2) < 0.99
    [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'min_pulse_value',7);
    r = corrcoef(nlg_pulse,1:length(nlg_pulse));
    while r(2) < 0.99
        disp('nlg pulses may not be linear due to inconsistent pulse reading on Tx, input new ''min_pulse_value''');
        keyboard
        min_pulse_value = input('min_pulse_value = ');
        if ~isempty(min_pulse_value) && isnumeric(min_pulse_value)
            [nlg_pulse, nlg_pulse_times] = ttl_times2pulses(nlg_time_din,'min_pulse_value',min_pulse_value);
            r(2) = corrcoef(nlg_pulse,1:length(nlg_pulse));
        else
            break
        end
    end
end

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
%%
if save_options_parameters_CD_figure
    saveas(gcf,fullfile(audio_dir,'CD_correction_avisoft_nlg.fig'))
end
end