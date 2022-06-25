
function HFO_Detection_ripppleLab(EDF_folder_path,save_folder_path,chan2Analyze,idx_file,freq_band,varargin)

%%% USER INPUT

% HFO Method parameters
st_HFOSettings.s_FreqIni = freq_band(1);           % Filter freqs lower limit; if set for FR, add /fr folder to path!
st_HFOSettings.s_FreqEnd = freq_band(2);           % Filter freqs upper limit; if set for FR, add /fr folder to path!
st_HFOSettings.s_RMSWindow = 3;                    % RMS window time (ms)
st_HFOSettings.s_RMSThres = 5;                     % Threshold for RMS in standard deviation
st_HFOSettings.s_MinWind = 12;                     % Min window time for an HFO (ms)
st_HFOSettings.s_MinTime = 10;                     % Min Distance time Betwen two HFO candidates
st_HFOSettings.s_NumOscMin = 4;                    % Minimum oscillations per interval
st_HFOSettings.s_BPThresh = 2;                     % Threshold for finding peaks
st_HFOSettings.s_EpochTime = 300;                  % Cycle Time
fast_ripple_freq = 200;                            % low frequency for fast ripple band
%% Generate file paths
if length(varargin) < 1
all_edf_files = dir([EDF_folder_path '**/*.edf']);
all_edf_files(idx_file).folder = [all_edf_files(idx_file).folder '/']; 
elseif length(varargin)== 1
    all_edf_files = varargin{1};
    idx_file = 1;
end

semi_save_folder_path = erase(all_edf_files(idx_file).folder,EDF_folder_path);

if st_HFOSettings.s_FreqIni >= fast_ripple_freq
save_folder_path = [save_folder_path ...
    semi_save_folder_path '/fr/'];
else
    save_folder_path = [save_folder_path ...
    semi_save_folder_path '/'];
end

if ~exist(save_folder_path,'dir')
    mkdir(save_folder_path);
end
save_file_path  = [ save_folder_path all_edf_files(idx_file).name(1:end-3) 'rhfe'];

%% read the needed information from file
st_readfile.path = all_edf_files(idx_file).folder;
st_readfile.name = all_edf_files(idx_file).name;
st_FileData      = f_GetHeader(st_readfile); % read Header
v_TimeLims = [0 st_FileData.s_Time];
if isempty(chan2Analyze)
    v_ChIdx = 1:length(st_FileData.v_Labels);
else
    v_ChIdx =  chan2Analyze;
end
st_Dat	= f_GetData(st_FileData,v_TimeLims,v_ChIdx); % read Data
disp(size(st_Dat.m_Data))
save(save_file_path, 'st_FileData');
%% call the HFO detection method
for s_CurrChIdx = 1:length(v_ChIdx)% use a foorloop when code is stable
    ChIdx_2bsaved = v_ChIdx(s_CurrChIdx);
    st_HFOAnalysis.m_EvtLims = f_findHFOxSTE_cluster(...
                                                     st_Dat.m_Data,...
                                                     s_CurrChIdx,...
                                                     st_HFOSettings,...
                                                     st_Dat.s_Sampling);
    % populate output structure
    st_HFOAnalysis.s_Sampling = st_Dat.s_Sampling;
    st_HFOAnalysis.s_ChIdx    = ChIdx_2bsaved;
    
    if isempty(st_HFOAnalysis.m_EvtLims)
        st_HFOData.v_ChHFOInfo{s_CurrChIdx}  = st_HFOAnalysis;
        st_HFOAnalysis                  = struct;
        disp(['no HFOs detected on ' st_FileData.v_Labels{ChIdx_2bsaved}]);
        continue
    end
    
    st_HFOAnalysis.m_IntervLims = zeros(size(st_HFOAnalysis.m_EvtLims));
    st_HFOAnalysis.m_Rel2IntLims = zeros(size(st_HFOAnalysis.m_EvtLims));
    
    s_IntWidth      = 10;    % Save 10 seconds from signal Interval
    s_IntWidth      = s_IntWidth .* st_HFOAnalysis.s_Sampling;
    s_IntMean       = round(s_IntWidth / 2);
    
    for kk = 1:size(st_HFOAnalysis.m_EvtLims,1)
        
        s_EvtMean   = round(mean(st_HFOAnalysis.m_EvtLims(kk,:)));
        
        s_PosIni    = s_EvtMean - s_IntMean;
        s_PosEnd    = s_EvtMean + s_IntMean;
        
        if s_PosIni < 1
            s_PosIni    = 1;
            s_PosEnd    = s_IntWidth;
        elseif s_PosEnd > numel(st_Dat.v_Time)
            s_PosIni    = numel(st_Dat.v_Time) - s_IntWidth;
            s_PosEnd    = numel(st_Dat.v_Time);
        end
        
        st_HFOAnalysis.m_IntervLims(kk,:)   = [s_PosIni,s_PosEnd];
        st_HFOAnalysis.m_Rel2IntLims(kk,:)  = st_HFOAnalysis.m_EvtLims(kk,:)...
            - s_PosIni + 1;
    end
    st_HFOAnalysis.v_EvType =  ones(size(st_HFOAnalysis.m_EvtLims,1),1);
    st_HFOAnalysis.str_ChLabel = st_FileData.v_Labels{ChIdx_2bsaved};
    st_HFOAnalysis.str_DetMethod = 'Short Time Energy';
    st_HFOData.v_ChHFOInfo{st_HFOAnalysis.s_ChIdx} = st_HFOAnalysis;
    
    v_Intervals   = f_GetHFOIntervals_cluster(st_Dat.m_Data,...
        s_CurrChIdx,...
        st_HFOAnalysis.m_IntervLims );
    
    str_Channel = st_FileData.v_Labels{ChIdx_2bsaved};
    str_Channel = strrep(str_Channel,'-','_');
    str_Channel = strrep(str_Channel,' ','_');
    st_save     = struct;
    
    if ~isnan(str2double(str_Channel))
        str_Channel = strcat('Ch',str_Channel);
    end
    
    st_save.st_FileData = st_FileData;
    st_Ch.st_HFOSetting = st_HFOSettings;
    st_Ch.v_Intervals = v_Intervals;
    st_Ch.st_HFOInfo = st_HFOAnalysis;
    
    st_save     = setfield(st_save,str_Channel,st_Ch);
    save(save_file_path, '-struct', 'st_save','-append')
    disp(['finished ch_' st_FileData.v_Labels{ChIdx_2bsaved}]);
end