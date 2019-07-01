function [fName, f_num, file_event_pos] = get_avi_time_from_nlg(audio2nlg,audio_dir,nlg_time)

fs = 250e3;

wav_files_struct = dir(fullfile(audio_dir,'*.WAV'));
wav_file_names = {wav_files_struct.name};
wav_file_nums = cellfun(@(x) str2double(x(end-10:end-4)),wav_file_names);

samples_by_file = audio2nlg.total_samples_by_file;
time_at_file_start = 1e3*([0 cumsum(samples_by_file(1:end-1))]/fs) - audio2nlg.first_audio_pulse_time;
wav_file_idx = find(time_at_file_start - nlg_time > 0, 1, 'first')-1;
file_start_sample = round(1e-3*(nlg_time - time_at_file_start(wav_file_idx))*fs);
if ~isempty(file_start_sample)
    fName = fullfile(wav_files_struct(wav_file_idx).folder,wav_files_struct(wav_file_idx).name);
    file_event_pos = repmat(file_start_sample,1,2);
    f_num = wav_file_nums(wav_file_idx);
else
    [fName, f_num, file_event_pos] = deal([]);
end


end