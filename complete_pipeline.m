% Complete pipeline

%% user input

mode = 3; % 1 for artefact rejection, 2 for HFO detection, 3 for both

art_rej_inputPath = '/u/project/rstaba/DATA/Rat/Sham/3096/D13/';
art_rej_outputPath = '/u/project/rstaba/DATA/Rat/Sham/3096/D13/clean/';
hfo_detection_inputPath = '/u/project/rstaba/DATA/Rat/Sham/3096/D13/clean/';
hfo_detection_outputPath = '/u/project/rstaba/DATA/Rat/Sham/3096/D13/clean/hfo/'; % if adding /fr folder, modify freqini & freqend in HFO_Detection_ripplelab.m

% read index of file to be analyzed from environment variables
idx_file = str2double(getenv('SGE_TASK_ID'));

% assign artefact rejection params
confg.channels            = 'all'; 
confg.window_minutes      = 10;
confg.th                  = 5;
confg.boundary_artefacts  = 0.3;
confg.freq_band           = [500 750];
confg.artWinDuration      = 5;
confg.window_width        = 3;
confg.min_art_duration    = 0.005;
% confg.channels            = 'all';
confg.interval            = 'all';
confg.SaveFig             = 0; % 1 to save figures 

% assign hfo detection params
chan2Analyze = [1 3:6]; % chan2Analyze = [] to analyze all channels just in mode 2

% assign frequency bands for ripples and fast ripples in Hz
ripples = [80 200];
fast_ripples = [200 500];

%%Functions to be executed according to the mode
if mode == 1
    remove_artefacts_3V(art_rej_inputPath,idx_file,art_rej_outputPath,confg);
elseif mode == 2
    % ripples
    HFO_Detection_ripppleLab(hfo_detection_inputPath,hfo_detection_outputPath,chan2Analyze,idx_file,ripples);
    % fast ripples
    HFO_Detection_ripppleLab(hfo_detection_inputPath,hfo_detection_outputPath,chan2Analyze,idx_file,fast_ripples);
else
    if isnumeric(confg.channels)
        chan2Analyze = 1:length(confg.channels);
    else
        chan2Analyze = [];
    end
    
    f_name = remove_artefacts_3V(art_rej_inputPath,idx_file,art_rej_outputPath,confg);
    filestruct(1).folder = art_rej_outputPath;
    filestruct(1).name = [f_name(1:end-4) '_clean.edf'];
    % ripples
    HFO_Detection_ripppleLab(hfo_detection_inputPath,hfo_detection_outputPath,chan2Analyze,idx_file,ripples,filestruct);
    % fast ripples
    HFO_Detection_ripppleLab(hfo_detection_inputPath,hfo_detection_outputPath,chan2Analyze,idx_file,fast_ripples,filestruct);

end
    