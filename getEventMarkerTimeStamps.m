function eventMarkers = getEventMarkerTimeStamps(fName)

dateYear = regexp(fName,'(?<=neurologger_recording)\d{4}','match');
dateYear = str2double(dateYear{1});
xmlStruct = parseXML(fName);
data = xmlStruct.Children;
markers = arrayfun(@(x) strcmpi(x.Name,'eventmarker'),data);
data = data(markers);
nChild = length(data);
eventMarkers = struct('TimeString',[],'FrameIndex',[]);
dataFields = {'TimeString','FrameIndex'};
dataConvFunc = {@(x) datetime(x,'InputFormat','eee MMM dd HH:mm:ss.SSSSSS') @(x) str2double(x)};
for c = 1:nChild
    for d = 1:length(dataFields)
        idx = strcmp({data(c).Attributes.Name},dataFields{d});
        eventMarkers(c).(dataFields{d}) = dataConvFunc{d}(data(c).Attributes(idx).Value);
        if strcmp(dataFields{d},'TimeString')
            eventMarkers(c).(dataFields{d}).Year = dateYear;
        end
    end
end


end