function vid_time_din = get_vid_ttl_pulses_from_aud(vid_dir,audio_chunk_size)

aud_data_fnames = dir(fullfile(vid_dir,'*.aac'));

ts_fnames = dir(fullfile(vid_dir,'*.ts.csv'));
aud_ts_idx = cellfun(@(x) contains(x,'_aud'),{ts_fnames.name});
aud_ts_fnames = ts_fnames(aud_ts_idx);

assert(length(aud_data_fnames) == length(aud_ts_fnames))

aud_date_fmt = 'yyyy:MM:dd HH:mm:ss.SSSSSS';

all_edge_ts_interp = cell(1,length(aud_ts_fnames));

for file_k = 1:length(aud_ts_fnames)
    text = fileread(fullfile(aud_ts_fnames(file_k).folder,aud_ts_fnames(file_k).name));
    text = strsplit(text,{',','\n','\r'});
    text = text(4:end);
    idx = cellfun(@(x) ~contains(x,'us') && contains(x,':'),text);
    text = text(idx);
    aud_ts = datetime(text,'InputFormat',aud_date_fmt);
    
    audData = audioread(fullfile(aud_data_fnames(file_k).folder,aud_data_fnames(file_k).name));
    aud_data_bin = audData>0.7;
    allEdge = find(diff([0; aud_data_bin]) == 1 | diff([0; aud_data_bin]) == -1);
    
    ts_chunk_starts = 1:audio_chunk_size:(audio_chunk_size*length(aud_ts));
    all_edge_ts_interp{file_k} = interp1(ts_chunk_starts,aud_ts,allEdge);
    
end

vid_time_din = vertcat(all_edge_ts_interp{:})';
end