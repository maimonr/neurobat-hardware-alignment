% When using extract_Nlg_data.m to extract the voltage trace data from
% Neurologger .DAT file and saving as .mat files, we do not save a time
% stamp for each voltage sample. Instead, we save all information needed to
% calculate the time stamps in the same .mat file as the voltage data, and
% use this function to calculate the time stamps for the samples we're
% interested in.
% 7/12/2016, Wujie Zhang
% Last updated, 9/5/2016, Wujie Zhang
%
% Inputs:
% -sample_indices: the indices of the AD count or voltage samples in a
% single channel, counting from the beginning of the recording, whose time
% stamps we'd like to calculate; can be arrays of any dimensions, and the
% indices don't need to be in increasing order
% -indices_of_first_samples: for a given channel, the indices of the first
% sample of every Nlg .DAT file, counting from the beginning of the
% recording; this is the same for all recording channels; this has been
% saved in the same .mat file as the voltage data by extract_Nlg_data.m
% -timestamps_of_first_samples_usec: the time stamps of the first sample of
% each file for each channel; this has been saved in the same .mat file as
% the voltage data by extract_Nlg_data.m
% -sampling_period_usec: the sampling period in us for the samples in a
% given recording channel; this has been saved in the same .mat file as the
% voltage data by extract_Nlg_data.m
%
% Output:
% -timestamps_usec: an array with the same dimensions as sample_indices,
% whose elements are the time stamps for corresponding samples in
% sample_indices

function timestamps_usec=get_timestamps_for_Nlg_voltage_all_samples(nSamp,indices_of_first_samples,timestamps_of_first_samples_usec,sampling_period_usec,logger_transceiver_CD_data)
timestamps_usec=nan(1,nSamp); % initialize an array of NaNs the same size as sample_indices
indices_of_first_samples = [indices_of_first_samples nSamp];
for file_i=1:length(indices_of_first_samples)-1 % for each of the Nlg .DAT files
    idx = indices_of_first_samples(file_i):indices_of_first_samples(file_i+1);
    timestamps_usec(idx)=timestamps_of_first_samples_usec(file_i)+((0:length(idx)-1)*sampling_period_usec); % time stamp of a requested sample = time stamp of the first sample in that file + number of sampling periods since that first sample * sampling period
end

if nargin > 4 && ~isempty(logger_transceiver_CD_data)
    Estimated_CD = zeros(1,nSamp);
    if strcmp(logger_transceiver_CD_data.Clock_difference_estimation, 'fit')
        slope_and_intercept=polyfit((logger_transceiver_CD_data.CD_logger_stamps-mean(logger_transceiver_CD_data.CD_logger_stamps))/std(logger_transceiver_CD_data.CD_logger_stamps),logger_transceiver_CD_data.CD_sec, 1); % reduce magnitude of input for numerical stability
        Estimated_CD = 1e6 * polyval(slope_and_intercept,(timestamps_usec-mean(logger_transceiver_CD_data.CD_logger_stamps))/std(logger_transceiver_CD_data.CD_logger_stamps));
    elseif strcmp(logger_transceiver_CD_data.Clock_difference_estimation, 'interpolation')
        Estimated_CD = interp1(logger_transceiver_CD_data.CD_logger_stamps, logger_transceiver_CD_data.CD_sec*1e6, timestamps_usec,'linear','extrap');
    end
    timestamps_usec = timestamps_usec - Estimated_CD;
end

