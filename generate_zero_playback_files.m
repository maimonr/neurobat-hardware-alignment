function generate_zero_playback_files(varargin)  
%%%
% A script to generate so-called 'zero playback' files for synchronizing
% the avisoft or matlab-soundmexpro-motu audio recording system with the Audio
% or neural loggers from Deuteron. This script
% generates and saves a number of large (~700 MB w/ fs = 1MHz and file
% length = 6 minutes or w/ fs= 192 000Hz and file duration 30min)
% .WAV files which are meant to be played throug the
% avisoft player or the sound card (matlab-soundmexpro-motu soundcard).
% For Avisfot, these files have the desired TTL status encoded on their
% least significant bit (LSB) which is how the avisoft player reads out
% what TTL status it should send out. 
% For matlab-soundmexpro, these files have the desired TTL status encoded
% in their actual value (value between 0 and 1).
% ENCODING SCHEME: This script produces TTL pulses to be encoded in the
% following manner: every dt>delay a pulse train is sent out encoding for a
% number in the sequence 1,2,3,4...
% Each pulse train is composed of a variable
% number of TTL pulses spaced by 15 ms (due to limitations imposed by
% deuteron loggers).
% Each pulse within a pulse train is between 5 and 14 ms
% (minimum pulse length is also dictated by hardware limitations). In
% order to encode these pulse trains each number being encoded is broken up
% into its composite digits (e.g. 128 = [1,2,8]). We then add 5 to each of
% these values. The resulting value is the length of the TTL pulses within 
% this pulse train.  
% E.G. :
% In order to encode pulse #128 we break 128 into [1,2,8] and add 5 to
% arrive at [6,7,13]. We set the first 6 ms to TTL 'high', the next 15 ms to
% TTL 'low', the next 7 ms to TTL 'high', the next 15ms to TTL 'low', and the
% next 13ms to TTL 'high.'
% NOTE: Avisoft reads TTL's 'upside-down', meaning 'high' here is set to
% 'low' for Avisoft


% This function takes the following input specified as ('parameter1',
% value1, 'parameter2', value2...)
% Input:    'FS':   nominal sampling rate of player (avisoft: 1e6Hz; Motu
%                       soundcard: 192000Hz ), default = 1e6Hz
%               'FS_offset':    set to 93 for actual avisoft playback rate
%                                   of 1000093, default = 0;
%               'TotalDuration':   total time covered by playback files, start to finish in hours
%                                           default: 1h
%               'FileDuration':     time covered by a single wav file in hours, set to 0.1 (6min) by default
%               'InterPulseTrainInterval': Time in seconds between 2 pulse
%                                                       train onsets, default value set at 15s
%               'InterPulseInterval': Time in ms between 2 pulses in a pulse train  (set to 15ms due to Deuteron hardware limitations)
%               'TTLCode':  A string indicating how the TTL should be encoded. 'LSB' = last significant beat (avisoft configuration)
%                                   'Value' = exact wav vector value (matlab-soundmexpro-motu configuration)
%               
%%%

%% Determining input arguments
% Sorting input arguments
Pnames = {'FS','FS_offset','TotalDuration', 'FileDuration', 'InterPulseTrainInterval', 'InterPulseInterval', 'TTLCode'};

% Calculating default values of input arguments
Fs=1e6; % nominal sampling rate of player (avisoft: 1e6Hz; Motu soundcard: 192000Hz );
Nom_fs_offset = 0; % set to 93 for actual avisoft playback rate of 1000093
TotalDuration = 1; % total time covered by playback files, start to finish in hours
FileDuration = 0.1; % time covered by a single wav file in hours, set to 6min by default
IPTI = 5; % Time in seconds between 2 pulse train onsets  
IPI = 15; % Time in ms between 2 pulses in a pulse train  (set to 15ms due to Deuteron hardware limitations)
TTLCode = 'LSB'; % How the TTL should be encoded LSB = last significant beat (avisoft configuration) Value = exact wav vector value (matlab-soundmexpro-motu configuration)

% Get input arguments
Dflts  = {Fs Nom_fs_offset TotalDuration FileDuration IPTI IPI TTLCode};
[Fs, Nom_fs_offset, TotalDuration, FileDuration, IPTI, IPI, TTLCode] = internal.stats.parseArgs(Pnames,Dflts,varargin{:});

% Find out the right sampling rate correction that could need to be done at the
% end
if Nom_fs_offset
    actual_fs = Fs + Nom_fs_offset;
    [p,q] = rat(actual_fs / Fs); % determine integers at which we can approximately resample data from 'fs' to 'actual_fs' such that the resulting playback files are played back at the actual fs, the playback is correct
end

% Defining the number of files and their length
TotalDuration_samp = TotalDuration*3600*Fs; 
FileDuration_samp = FileDuration*3600*Fs; % # samples on an individual playback files
N_chunk = ceil(TotalDuration_samp/FileDuration_samp); % number of files to be produced

% Defining pulse shapes and numbers per file
Base_ttl_length = Fs*1e-3; % maximum resolution of Deuteron loggers is 1ms
Min_ttl_length  = 5; % set to 5ms due to Deuteron hardware limitations
IPTI_samp = IPTI*Fs; % interval between pulse trains in sample units
PulseTrain_position = 0:IPTI_samp:FileDuration_samp; % exact position of pulse trains in sample units
PulseTrain_position = PulseTrain_position(1:end-1); % discarding the last pulse train that most likely would not have time to finish
IPI_samp = IPI*Fs*1e-3; % interval between pulses within individual pulse trains in sample units
N_pulse_per_chunk = length(PulseTrain_position); % number of pulse trains in a file
N_ttl_digits = 5; % maximum number of digits in a pulse (i.e. up to 10,000 pulses)


%% Constructing pulse sequences

pulse_k = 1; % pulse counter
for chunk = 1:N_chunk % loop through each file or 'chunk'
    Wav_file = zeros(1,FileDuration_samp,'double'); % times when TTL status should be set to 'high' 
    if strcmp(TTLCode, 'LSB')
        Wav_file = bitset(Wav_file,1,1); % setting all first digits to 1
    elseif strcmp(TTLCode, 'Value')
    else
        error('Format of TTL encoding is unknown:%s\nTTLCode should be set to LSB or Value\n', TTLCode);
    end
    
    for pulse = 1:N_pulse_per_chunk  % code each pulse train separately
        Pulse_offset = PulseTrain_position(pulse); % total amount of time taken up by the previous pulse trains and ipti's (inter pulse train interval) and other pulses already within this pulse train
        d = 1; % which digit are we on
        while d <= N_ttl_digits % max pulse = 10,0000
            if pulse_k/(10^(d-1))>=1 % determine the total number of digits we need for this number
                Pulse_offset = Pulse_offset+ IPI_samp; % always add IPI_samp in front of each digit
                pulse_digit_str = num2str(pulse_k); % convert pulse number to string to separate out digits
                pulse_digit = str2double(pulse_digit_str(d)); % convert the digit we are encoding now back to a number
                digit_pulse = ones(Base_ttl_length*pulse_digit+(Min_ttl_length*Base_ttl_length));
                if strcmp(TTLCode, 'Value')
                    Wav_file(Pulse_offset : (Pulse_offset + length(digit_pulse) -1)) = digit_pulse; % pulse is encoded as TTL 'high'
                elseif strcmp(TTLCode, 'LSB')
                    Wav_file(Pulse_offset : (Pulse_offset + length(digit_pulse) -1)) = bitset(Wav_file(Pulse_offset : (Pulse_offset + length(digit_pulse) -1)),1,0); % pulse is encoded as TTL 'off' in the LSB
                end
                d = d + 1; % next digit
                Pulse_offset = Pulse_offset + length(digit_pulse); % store placement for next combination of IPI + pulse within this pulse train
            else
                d = inf; % go on to next pulse
            end
        end
        pulse_k = pulse_k + 1;
    end
    
    
    if Nom_fs_offset
        Wav_file = int16(resample(Wav_file,p,q)); % resample the data to the actual fs and convert to 16 bit integers
    end
    audiowrite(['unique_ttl' num2str(chunk) '.wav'],Wav_file,Fs); % save as a .WAV file
end
end