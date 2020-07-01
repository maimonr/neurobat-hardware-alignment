function nlg_time_din = get_nlg_ttl_pulses(nlg_dir,session_strings,nlg_ttl_str,nlg_off_by_day)

if isfile(nlg_dir)
    eventData = load(nlg_dir);
else
    eventfile = dir(fullfile(nlg_dir,'*EVENTS.mat')); % load file with TTL status info
    try
        assert(length(eventfile)==1)
    catch
        [fname,nlg_dir] = uigetfile(nlg_dir,'select events file');
        eventfile = dir(nlg_dir,fname);
        assert(length(eventfile)==1)
    end
    eventData = load(fullfile(eventfile.folder,eventfile.name));
end

session_start_and_end = zeros(1,2);
start_end = {'start','stop'};

for s = 1:2
    session_string_pos = find(cellfun(@(x) ~isempty(strfind(x,session_strings{s})),eventData.event_types_and_details));
    if numel(session_string_pos) ~= 1
        if numel(session_string_pos) > 1
            display(['more than one session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
        elseif numel(session_string_pos) == 0
            display(['couldn''t find session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
        end
        keyboard;
        session_string_pos = input('input index into variable event_types_and_details');
    end
    session_start_and_end(s) = eventData.event_timestamps_usec(session_string_pos);
end

if nlg_off_by_day
    nlg_event_time_corr = (60*60*24)*1e6;
    event_timestamps_usec = eventData.event_timestamps_usec - nlg_event_time_corr;
else
    event_timestamps_usec = eventData.event_timestamps_usec;
end

%% extract only relevant TTL status changes
event_types_and_details = eventData.event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));

din = cellfun(@(x) contains(x,nlg_ttl_str),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes

end