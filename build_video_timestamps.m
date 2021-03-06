function frame_ts_info = build_video_timestamps(video_dir,cameraName,video2nlg,varargin)

pnames = {'recType'};
dflts  = {'seq'};
[recType] = internal.stats.parseArgs(pnames,dflts,varargin{:});

switch recType
    case 'seq'
        metadataDateFormatSpec = {'MM/dd/yyyy HH:mm:ss:SSSSSS','yy:MM:dd HH:mm:ss SSSSSS'};
        delimiter = ',';
        importFormatSpec = '%f%s%[^\n\r]';
        nHeader = 0;
        EOLChar = '\n';
        vid_file_ext = '.mp4';
        metadata_file_ext = '.ts.csv';
    case 'avi'
        metadataDateFormatSpec = {'yy:MM:dd HH:mm:ss.SSS'};
        delimiter = '\t';
        importFormatSpec = '%f%s';
        nHeader = 2;
        EOLChar = '\n';
        vid_file_ext = '.avi';
        metadata_file_ext = '_Timers.txt';
end

format_spec_idx = 1;

video_files = dir(fullfile(video_dir, ['*' cameraName '*' vid_file_ext]));
n_video_files = length(video_files);
video_fnames = cell(1,n_video_files);
video_files_frame_numbers = cell(1,n_video_files);
frameDateTimes = cell(1,n_video_files);
frame_file_idx = cell(1,n_video_files);

for f = 1:n_video_files
    video_fnames{f} = [video_files(f).folder filesep video_files(f).name];
    
    metaDataFName = [video_fnames{f}(1:end-length(vid_file_ext)) metadata_file_ext];
    fileID = fopen(metaDataFName,'r');
    metadataArray = textscan(fileID, importFormatSpec, 'Delimiter', delimiter,...
        'HeaderLines',nHeader,'EndOfLine',EOLChar,'ReturnOnError', false);
    fclose(fileID);
    frameTimes = metadataArray{:, 2};
    
    try
        frameDateTimes{f} = datetime(frameTimes,'InputFormat',metadataDateFormatSpec{format_spec_idx})';
    catch
        format_spec_idx = format_spec_idx + 1;
        frameDateTimes{f} = datetime(frameTimes,'InputFormat',metadataDateFormatSpec{format_spec_idx})';
    end
    
    frame_file_idx{f} = f*ones(1,length(frameTimes));
    
    video_files_frame_numbers{f} = 1:length(frameTimes);
end

frameTS = [frameDateTimes{:}];
frame_file_idx = [frame_file_idx{:}];
video_files_frame_numbers = [video_files_frame_numbers{:}];

nlg_frame_ts = video2nlg_time(video2nlg,frameTS);
frame_ts_info = struct('timestamps',frameTS,'timestamps_nlg',nlg_frame_ts,'file_frame_number',video_files_frame_numbers,'fileIdx',frame_file_idx,'videoFNames',{video_fnames});



end