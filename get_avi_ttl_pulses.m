function [audio_time_din, total_samples_by_file] = get_avi_ttl_pulses(audio_dir,wav_file_nums,fs_wav)

avi_wav_bits = 16; % number of bits in each sample of avisoft data
wav2bit_factor = 2^(avi_wav_bits-1); % factor to convert .WAV data to bits readable by 'bitand' below

wav_files = dir(fullfile(audio_dir,'*.wav')); % all .WAV files in directory
if ~isempty(wav_file_nums)
    wav_file_nums = find(cellfun(@(x) ismember(str2num(x(end-7:end-4)),wav_file_nums),{wav_files.name})); % extract only requested .WAV files
else
    wav_file_nums = 1:length(wav_files);
end
audio_time_din = [];
total_samples = 0;
total_samples_by_file = zeros(1,length(wav_files));


for w = 1:max(wav_file_nums) % run through all requested .WAV files and extract audio data and TTL status at each sample
    if ismember(w,wav_file_nums)
        try
            data = audioread(fullfile(audio_dir,wav_files(w).name)); % load audio data
        catch err
            if strcmp(err.identifier,'MATLAB:audiovideo:audioread:Unexpected')
               disp('Corrupted File!')
               total_samples_by_file(w) = 0;
               continue
            else
                rethrow(err)
            end
        end
        ttl_status = bitand(data*wav2bit_factor + wav2bit_factor,1); % read TTL status off least significant bit of data
        audio_time_din = [audio_time_din (1e3*(total_samples + find(sign(diff(ttl_status))~=0)')/fs_wav)]; %#ok<AGROW>
        total_samples_by_file(w) = length(data);
        total_samples = total_samples + total_samples_by_file(w);
    else
        audio_info_struct = audioinfo(fullfile(audio_dir,wav_files(w).name));
        total_samples_by_file(w) = audio_info_struct.TotalSamples;
        total_samples = total_samples + total_samples_by_file(w);
    end
end


end