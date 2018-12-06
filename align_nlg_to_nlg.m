function [shared_nlg_pulse_times, first_nlg_pulse_time] = align_nlg_to_nlg(base_dirs,ttl_pulse_dt,session_strings)
%%
% Function to correct for clock drift between two loggers.
%
% INPUT:
% base_dir: base directories of the two loggers for one experiment. 
%
% ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop: see help for
% ttl_times2pulses.m
%
% session_strings: cell of strings used to demarcate start and stop of
% time period to analyze in this script from EVENTLOG file.
%
% OUTPUT:
%
% shared_nlg_pulse_times: times (ms) in piezo time when TTL pulses arrived on
% the piezo Tx. To be used with nlg2nlg_time to locally interpolate
% differences between time on streampix and piezo and correct for those
% differences.
%
% first_nlg_pulse_time: time (ms, in piezo time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align two loggers
% times before scaling by estimated clock differences.

corr_pulse_err = true;
correct_end_off = true;
correct_loop = true;

save_options_parameters_CD_figure = 1;
%%%

nlg_pulse = cell(1,length(base_dirs));
nlg_pulse_times = cell(1,length(base_dirs));

for n = 1:length(base_dirs)
    
    eventfile = dir([base_dirs{n} '*EVENTS.mat']); % load file with TTL status info
    assert(length(eventfile)==1)
    load(fullfile(eventfile.folder,eventfile.name));
    
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
    
    % extract only relevant TTL status changes
    event_types_and_details = event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
    event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
    
    din = cellfun(@(x) contains(x,'Digital in'),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
    nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes
    [nlg_pulse{n}, nlg_pulse_times{n}] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop); % extract TTL pulses and time
end

%% synchronize piezo --> piezo
if length(unique(nlg_pulse{1}))/length(nlg_pulse{1}) ~= 1 || length(unique(nlg_pulse{2}))/length(nlg_pulse{2}) ~= 1 
    display('repeated pulses!');
    keyboard;
end
shared_pulse_nlg_idx = cell(1,2);
[~, shared_pulse_nlg_idx{1}, shared_pulse_nlg_idx{2}] = intersect(nlg_pulse{1},nlg_pulse{2}); % determine which pulses are on both the NLG and video recordings

% extract only shared pulses
shared_nlg_pulse_times = {nlg_pulse_times{1}(shared_pulse_nlg_idx{1}),nlg_pulse_times{2}(shared_pulse_nlg_idx{2})};

first_nlg_pulse_time = [shared_nlg_pulse_times{1}(1) shared_nlg_pulse_times{2}(1)];

clock_differences_at_pulses = (shared_nlg_pulse_times{1} - first_nlg_pulse_time(1)) - (shared_nlg_pulse_times{2} - first_nlg_pulse_time(2)); % determine difference between piezo loggers' timestamps when pulses arrived

figure
hold on
plot((shared_nlg_pulse_times{1} - first_nlg_pulse_time(1)),clock_differences_at_pulses,'.-');
xlabel('Incoming Piezo Pulse Times')
ylabel('Difference between piezo 1 clock and piezo 2 clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,[base_dir 'piezo_data\logger' num2str(logger_nums(end)) filesep 'CD_correction_video_piezo.fig'])
end
end