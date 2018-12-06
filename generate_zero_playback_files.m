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
% Input:    'FS':   nominal sampling rate of player (avisoft: 1MHz; Motu
%                       soundcard: 192000Hz ), default = 1MHz
%               'TotalDuration':   total time covered by playback files, start to finish in hours
%                                           default: 1h
%               'FileDuration':     time covered by a single wav file in min, set to 6min by default
%               'InterPulseTrainInterval': Time in seconds between 2 pulse
%                                          train onsets, default value set at 5s
%               'InterPulseInterval': Time in ms between 2 pulses in a pulse train  (set to 15ms due to Deuteron hardware limitations)
%               'StartOffset': Time in seconds after which the TTL pulses
%                               should be encoded in the first file.
%                               default is 0. The first pulse train occurs
%                               after StartOffset seconds and InterPulseInterval ms
%               'TTLCode':  A string indicating how the TTL should be encoded. 'LSB' = last significant beat (avisoft configuration)
%                                   'Value' = exact wav vector value (matlab-soundmexpro-motu configuration)
%               'Path':     A sting indicating where the wav files should be
%                              generated. Default=pwd
%               
%%%

FIG=0; % set to 1 to see debugging plot

%% Determining input arguments
% Sorting input arguments
Pnames = {'FS','TotalDuration', 'FileDuration', 'InterPulseTrainInterval', 'InterPulseInterval','StartOffset', 'TTLCode', 'Path', 'Stereo'};

% Calculating default values of input arguments
FS=1e6; % nominal sampling rate of player (avisoft: 1MHz; Motu soundcard: 192000Hz );
TotalDuration = 1; % total time covered by playback files, start to finish in hours
FileDuration = 6; % time covered by a single wav file in mins, set to 6min by default
IPTI = 5; % Time in seconds between 2 pulse train onsets  
IPI = 15; % Time in ms between 2 pulses in a pulse train  (set to 15ms due to Deuteron hardware limitations)
StartOffset = 0; % Time in second after which TTL pulses should be written in the file default is none
TTLCode = 'LSB'; % How the TTL should be encoded LSB = last significant beat (avisoft configuration) Value = exact wav vector value (matlab-soundmexpro-motu configuration)
Out_Path = pwd;

% Get input arguments
Dflts  = {FS TotalDuration FileDuration IPTI IPI StartOffset TTLCode Out_Path};
[FS, TotalDuration, FileDuration, IPTI, IPI, StartOffset, TTLCode, Out_Path] = internal.stats.parseArgs(Pnames,Dflts,varargin{:});

% Defining the number of files and their length
TotalDuration_samp = TotalDuration*3600*FS; 
FileDuration_samp = FileDuration*60*FS; % # samples on an individual playback files
N_chunk = ceil(TotalDuration_samp/FileDuration_samp); % number of files to be produced

% Defining pulse shapes and numbers per file
N_ttl_digits = 5; % maximum number of digits in a pulse (i.e. up to 10,000 pulses)
Base_ttl_length = ceil(FS*1e-3); % maximum resolution of Deuteron loggers is 1ms, we want a number of samples that corresponds at least to 1ms
Min_ttl_length  = 5; % set to 5ms due to Deuteron hardware limitations
IPTI_samp = IPTI*FS; % interval between pulse trains in sample units
IPI_samp = IPI*Base_ttl_length; % interval between pulses within individual pulse trains in sample units
StartOffset_samp = StartOffset*FS; % Offset at the beginning of the file if desired
PulseTrain_position = (1+StartOffset_samp):IPTI_samp:FileDuration_samp; % exact position of pulse trains in sample units
if PulseTrain_position(end)>=(FileDuration_samp - N_ttl_digits*(IPI_samp + (Min_ttl_length+9)*Base_ttl_length))
    PulseTrain_position = PulseTrain_position(1:(end-1)); % discarding the last pulse train that most likely would not have time to be fully encoded
end
N_pulse_per_chunk = length(PulseTrain_position); % number of pulse trains in a file



%% Constructing pulse sequences

pulse_k = 1; % pulse counter
for chunk = 1:N_chunk % loop through each file or 'chunk'
    Wav_file = zeros(1,FileDuration_samp,'double'); % times when TTL status should be set to 'high' 
    if strcmp(TTLCode, 'LSB')
        Wav_file = bitset(Wav_file,1,1); % setting all first digits to 1
    elseif strcmp(TTLCode, 'Value')
        % we keep the wavfile as is
    else
        error('Format of TTL encoding is unknown:%s\nTTLCode should be set to LSB or Value\n', TTLCode);
    end
    
    for pulse = 1:N_pulse_per_chunk  % code each pulse train separately
        Pulse_offset = PulseTrain_position(pulse); % total amount of time taken up by the previous pulse trains and ipti's (inter pulse train interval) and other pulses already within this pulse train
        d = 1; % which digit are we on
        while d <= N_ttl_digits % max pulse = 99,999
            if pulse_k/(10^(d-1))>=1 % determine the total number of digits we need for this number
                Pulse_offset = Pulse_offset+ IPI_samp; % always add IPI_samp in front of each digit
                pulse_digit_str = num2str(pulse_k); % convert pulse number to string to separate out digits
                pulse_digit = str2double(pulse_digit_str(d)); % convert the digit we are encoding now back to a number
                digit_pulse = ones(1,Base_ttl_length*(pulse_digit+Min_ttl_length));
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
    
    if strcmp(TTLCode, 'LSB') && FIG
        plot(bitget(Wav_file,1))
        xticks(0:FS*60:length(Wav_file))
        xticklabels(0:1:(length(Wav_file)/(FS*60)))
        xlabel('Time in min')
        ylabel('bit value')
        ylim([-0.5 1.5])
        Wav_file = int16(Wav_file); % convert to signed 16-bit integers
        pause(1)
    elseif strcmp(TTLCode, 'Value') && FIG
        plot(Wav_file)
        xticks(0:FS*60:length(Wav_file))
        xticklabels(0:1:(length(Wav_file)/(FS*60)))
        xlabel('Time in min')
        ylabel('sound pressure')
        ylim([-0.5 1.5])
        pause(1)
    elseif strcmp(TTLCode, 'LSB') && ~FIG
        Wav_file = int16(Wav_file); % convert to signed 16-bit integers
    end
    
  
    audiowrite(fullfile(Out_Path,['unique_ttl' num2str(chunk) '.wav']),Wav_file,FS); % save as a .WAV file
end

%% Saving parameters to unique_ttl_params.mat
% Set up the date
Today = datestr(now, 'yymmdd_HHMM');
save(fullfile(Out_Path, [Today 'unique_ttl_params.mat']), 'FS', 'TotalDuration', 'FileDuration', 'IPTI', 'IPI','TTLCode', 'Min_ttl_length', 'Base_ttl_length', 'N_ttl_digits');
            
end