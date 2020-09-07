function [vid_time_din,vid_time_din_sample] = get_vid_ttl_pulses_from_aud(vid_dir,audio_chunk_size)

aud_data_fnames = dir(fullfile(vid_dir,'*.aac'));

ts_fnames = dir(fullfile(vid_dir,'*.ts.csv'));
aud_ts_idx = cellfun(@(x) contains(x,'_aud'),{ts_fnames.name});
aud_ts_fnames = ts_fnames(aud_ts_idx);
n_aud_files = length(aud_ts_fnames);

assert(length(aud_data_fnames) == n_aud_files)

aud_date_fmt = 'yyyy:MM:dd HH:mm:ss.SSSSSS';

[all_edge_ts_interp,all_edge_idx] = deal(cell(1,n_aud_files));
audio_fs = zeros(1,n_aud_files);
cum_samples = 0;
for file_k = 1:n_aud_files
    text = fileread(fullfile(aud_ts_fnames(file_k).folder,aud_ts_fnames(file_k).name));
    text = strsplit(text,{',','\n','\r'});
    text = text(4:end);
    idx = cellfun(@(x) ~contains(x,'us') && contains(x,':'),text);
    text = text(idx);
    aud_ts = datetime(text,'InputFormat',aud_date_fmt);
    
    audio_fName = fullfile(aud_data_fnames(file_k).folder,aud_data_fnames(file_k).name);
    [audData,audio_fs(file_k)] = audioread(audio_fName);
    aud_data_bin = audData>0.7;
    allEdge = find(diff([0; aud_data_bin]) == 1 | diff([0; aud_data_bin]) == -1);
    
    ts_chunk_starts = 1:audio_chunk_size:(audio_chunk_size*length(aud_ts));
    all_edge_idx{file_k} = allEdge + cum_samples;
    all_edge_ts_interp{file_k} = interp1(ts_chunk_starts,aud_ts,allEdge);
    cum_samples = cum_samples + length(audData);
end
audio_fs = unique(audio_fs);
assert(length(audio_fs) == 1)
vid_time_din = vertcat(all_edge_ts_interp{:})';
all_edge_idx = vertcat(all_edge_idx{:})';
vid_time_din_sample = 1e3*all_edge_idx/audio_fs;

end