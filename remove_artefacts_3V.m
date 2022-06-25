function  fname = remove_artefacts_3V(folder_path,edf_file_idx,save_folder,varargin)
%REMOVE_ARTEFACTS      Cleans rats EEG from artefacts

% This function can be used to automatically clean rats EEG from artefacts

% Input:   folder_path     a string specifying the folder in which the data
%                          is located. it reads only EDF files.
%
%          edf_file_idx    an int corresponding to the index of the file
%                          to be processed. It should be set to 1 in case
%                          the folder contains only one EDF file.
%
%          save_folder     a string specifying the folder in which the
%                          result would be saved. The result would be saved
%                          in an EDF file format. Any annotations to the
%                          file wll be lost.
%
%          confg           a structure that contains the algorithm
%          parameters fields. It is optional, as the function will use
%          default values if they were not specified by the user:
%
%            confg.seg                  float, used to specify the window
%                                       length, in seconds, that the data
%                                       will be divided into before being
%                                       analyzed.
%
%            confg.harshness            float, it affects the threshold
%                                       above which high amplitude signals
%                                       will be considered artefacts.
%
%
%            config.padding             float, samples to include as
%                                       atefact around any detected event.
%
%            confg.freq_band            [low_freq  high_freq] array that
%                                       specify the freuency band of the
%                                       fast artefact activity.
%
%            confg.window_zero_cross    int, minimum number of times the
%                                       normalized power signal crosses zero
%                                       below which it is considered artefact
%
%            confg.minC                 int, minimum number of channels for
%                                       an artefact apread
%
%
%            confg.channels             array of integers containing the
%                                       indexes of channels to be processed.
%                                       if not specified all channels
%                                       will be processed.
%
%            confg.interval             2 integer vector that specify the
%                                       interval start_time and end_time
%                                       (in minutes) to be processed. if not
%                                       specified all file will be processed
%                                       by default. (min value 0).
%
%            confg.SaveFig              is equal to 1 if user wnt to save
%                                       figures otherwise it is set to 0.
%                                       default value is 1



% check number of variables
if length(varargin) < 1
    confg.seg                 = 0.25;
    confg.harshness           = 2;
    confg.window_zero_cross   = 20;
    confg.padding             = 0.2;
    confg.freq_band           = [200 600];
    confg.minC                = 3;
    confg.channels            = 'all';
    confg.interval            = 'all';
    confg.SaveFig             = 0;
else
    confg = varargin{1};
    if ~(isfield(confg,'seg'))
        confg.seg  = 0.25;
    end
    if ~(isfield(confg,'harshness'))
        confg.harshness = 2;
    end
    if ~(isfield(confg,'window_zero_cross'))
        confg.window_zero_cross  = 20;
    end
    if ~(isfield(confg,'padding'))
        confg.padding = 0.2;
    end
    if ~(isfield(confg,'freq_band'))
        confg.freq_band = [200 600];
    end
    if ~(isfield(confg,'minC'))
        confg.minC = 3;
    end
    if ~(isfield(confg,'channels'))
        confg.channels = 'all';
    end
    if ~(isfield(confg,'interval'))
        confg.interval = 'inf';
    end
    if ~(isfield(confg,'SaveFig'))
        confg.SaveFig = 0;
    end
end

% Initiate variables
seg = confg.seg;
harshness = confg.harshness*10;
window_zero_cross = confg.window_zero_cross;
padding = confg.padding;
freq_band = confg.freq_band;
minC = confg.minC;
interval = confg.interval;
SaveFig = confg.SaveFig;
zci = @(v) find(v(:).*circshift(v(:), [-1 0]) <= 0);

%% read data
disp('Start Reading Data')
tic
strPath_struct = dir([folder_path '/**']);
files2keep = ~cellfun(@isempty,regexpi({strPath_struct.name},'.*(edf|EDF)'));
strPath_struct = strPath_struct(files2keep);
fname = strPath_struct(edf_file_idx).name;
file2read = fullfile(strPath_struct(edf_file_idx).folder,strPath_struct(edf_file_idx).name);
Header = ft_read_header(file2read); % read header

% choose channels to analyze
if ~ischar(confg.channels)
    index_2_keep = confg.channels;
else
    index_2_keep = 1:Header.nChans;
end

if ischar(interval)
    data = ft_read_data(file2read); % read data
else
    begsample = interval(1)*60*Fs+1;
    endsample = interval(2)*60*Fs;
    data = ft_read_data(file2read,'header',Header, 'begsample',begsample ,'endsample',endsample);
end
disp('Finish Reading Data')
toc

%% remove the mean
mean_sig = repmat(mean(data(index_2_keep,:),2),1,size(data,2));
data = data(index_2_keep,:)- mean_sig;
mean_sig = [];
Fs = Header.Fs;
%% remove last second
data = data(:,1:end-Fs);

% notch filter powerline
  w0 = 60/(Fs/2);
  bw = w0/35;
  [b,a] = iirnotch(w0,bw);
  data = filtfilt(b,a,data')';

    
%% loop over channels
for  channel = 1:size(data,1)
    sig1 = data(channel,:);
    last_seg = mod(length(sig1),Fs*seg);
    chunks = reshape(sig1(1:end-last_seg),Fs*seg,[]);
    for j = 1:size(chunks,2)
        power_200_500(j) = bandpower(chunks(:,j),Fs,freq_band);
    end
    if last_seg>0
    last_seg_power = bandpower(sig1(end-last_seg+1:end),Fs,freq_band);
    else
        last_seg_power =[];
    end
    power_200_500 = [power_200_500 last_seg_power];
    chunks = [];
    
    % normalize by dividing by subtracr min and dividng max-min
    dist_sum = (power_200_500-min(power_200_500))./(max(power_200_500)-min(power_200_500));
    power_200_500 = [];
    
    % remove mean of most common values
    [idx,max_v] = hist(dist_sum,100);
    idx_max = find(idx==max(idx),1);
    low = max_v(idx_max);
    dist_sum_norm = dist_sum-low;
    
    % parameters for artefacts threshold
    std_all(channel) = std(dist_sum);
    perc_above_mean(channel) = sum(dist_sum>mean(dist_sum))/length(dist_sum)*100;
    harsh = (perc_above_mean(channel))/harshness;
    thresh = min(dist_sum)+harsh*std_all(channel);
    
    % detect threshold artefacts
    arr_artefact_std = zeros(length(dist_sum_norm),1);
    arr_artefact_std(dist_sum_norm>thresh) = 1;
    
    % a>0dd padding
    arr_artefact_std = add_padding(arr_artefact_std, padding, 1);
    arr_artefact_std = add_padding(arr_artefact_std, padding, -1);
    
    % all channels artefacts
    arr_artefact_std_all(channel,:) = arr_artefact_std;
    arr_artefact_std =[];   
    
    % detect zero crossing artefacts
    count = 0;
    arr_artefact_zc = [];
    
    dist_sum_zc = dist_sum_norm;
    for i = 1:window_zero_cross:length(dist_sum_norm)-window_zero_cross
        count = count+1;
        sig  = dist_sum_zc(i:i+window_zero_cross)';
        aci_cum(count) = sum(zci(sig));
        if (aci_cum(count)<=15 && mean(sig)>0)
            arr_artefact_zc(i:i+window_zero_cross)=1;
        else
            arr_artefact_zc(i:i+window_zero_cross)=0;
        end
    end
    arr_artefact_zc(end:end+mod(length(dist_sum_norm)-window_zero_cross-1,window_zero_cross)) = 0;
    
    % add padding
    arr_artefact_zc = add_padding(arr_artefact_zc, padding, 1);
    arr_artefact_zc = add_padding(arr_artefact_zc, padding, -1);
    
    % all channels artefacts
    arr_artefact_zc_all(channel,:) = arr_artefact_zc;
    
end

% determine whether artefacts are on more than minC electrodes contacts
sum_std = sum(arr_artefact_std_all) ;
sum_zc = sum(arr_artefact_zc_all) ;
arr_artefact_std_all(:,sum_std<minC) = 0;
arr_artefact_zc_all(:,sum_zc<minC) = 0;

% compare different channels
groups = round(std_all.*100);
for i = 1:length(groups)
    groups2compare{i} = find(abs(groups-groups(i)) <= 1);
end
charArr = cellfun(@num2str, groups2compare, 'Un', 0 );
unique_groups = cellfun(@str2num,unique(charArr),'Un', 0 );
for uni_groupsID = 1:length(unique_groups)
    if length(unique_groups{uni_groupsID}) >1
        strong_decision_std(uni_groupsID,:) = any(arr_artefact_std_all(unique_groups{uni_groupsID},:),1);
        strong_decision_zc(uni_groupsID,:) = any(arr_artefact_zc_all(unique_groups{uni_groupsID},:),1);
    else
        strong_decision_std(uni_groupsID,:) = arr_artefact_std_all(unique_groups{uni_groupsID},:);
        strong_decision_zc(uni_groupsID,:) = arr_artefact_zc_all(unique_groups{uni_groupsID},:);
    end
    
    sure_artefacts(uni_groupsID,:) = any([strong_decision_std(uni_groupsID,:);strong_decision_zc(uni_groupsID,:)],1);
end

%% convert dist to signal artefacts
artefact_vector = convert_dist2sig(data,unique_groups,sure_artefacts,Fs,seg);


%% fill gaps
matrix2save  = fillgaps(artefact_vector,index_2_keep,data,Fs);

%% final check before saving
arr_artefact_std_all =[];
data = matrix2save;
for  channel = 1:size(data,1)
    sig1 = data(channel,:);
    last_seg = mod(length(sig1),Fs*seg);
    chunks = reshape(sig1(1:end-last_seg),Fs*seg,[]);
    for j = 1:size(chunks,2)
        power_200_500(j) = bandpower(chunks(:,j),Fs,freq_band);
    end
    if last_seg > 0
    last_seg_power = bandpower(sig1(end-last_seg+1:end),Fs,freq_band);
    else
        last_seg_power =[];
    end
    power_200_500 = [power_200_500 last_seg_power];
    %chunks = [];
    
    % normalize by dividing by subtracr min and dividng max-min
    dist_sum = (power_200_500-min(power_200_500))./(max(power_200_500)-min(power_200_500));
    power_200_500 = [];
    
    % remove mean of most common values
    [idx,max_v] = hist(dist_sum,100);
    idx_max = find(idx==max(idx),1);
    low = max_v(idx_max);
    dist_sum_norm = dist_sum-low;
    
    % parameters for artefacts threshold
    std_all(channel) = std(dist_sum);
    perc_above_mean(channel) = sum(dist_sum>mean(dist_sum))/length(dist_sum)*100;
    harsh = (perc_above_mean(channel))/harshness;
    thresh = min(dist_sum)+harsh*std_all(channel);
    
    % detect threshold artefacts
    arr_artefact_std = zeros(length(dist_sum_norm),1);
    arr_artefact_std(dist_sum_norm>thresh) = 1;
    
    % add padding
    arr_artefact_std = add_padding(arr_artefact_std, padding, 1);
    arr_artefact_std = add_padding(arr_artefact_std, padding, -1);
        
    % all channels artefacts
    arr_artefact_std_all(channel,:) = arr_artefact_std;
end

% determine whether artefacts are on more than minC electrodes contacts
sum_std = sum(arr_artefact_std_all) ;
arr_artefact_std_all(:,sum_std<minC) = 0;
artefact_vector = convert_dist2sig(data,unique_groups,arr_artefact_std_all,Fs,seg);
matrix2save  = fillgaps(artefact_vector,index_2_keep,data,Fs);


%% save to EDF files
% modify header
new_header = Header;
new_header.Fs = Fs;
new_header.nChans = length(index_2_keep);
new_header.label = Header.label(index_2_keep);
new_header.nSamples = size(matrix2save,2);
new_header.nSamplesPre = 0;
new_header.nTrials = 1;
new_header.chantype = Header.chantype(index_2_keep);
new_header.chanunit = Header.chanunit(index_2_keep);
new_header.orig.NRec = 1;

% check if save directory is not present create it
if ~exist(save_folder,'dir')
    mkdir(save_folder);
end

% save to edf file
disp('Saving Edf file');
ft_write_data([save_folder strPath_struct(edf_file_idx).name(1:end-4) '_clean.edf'],int16(matrix2save),'header', new_header);
disp('Successfully saved Edf file');

%% save Figures
if SaveFig == 1
    disp('Saving Figures');
    t = (0:size(data,2)-1)./Fs/60; % in minutes
    for i = 1:length(index_2_keep)
        h = figure;
        plot(t,data(i,:),'b');
        hold on
        a  = data(i,:);
        a(artefact_vector>0) = NaN;
        plot(t,a,'r');
        xlabel(gca,'time (min)');
        ylabel(gca,'Amplitude (\muV)');
        title(gca,['Channel ' int2str(index_2_keep(i))]);
        saveas(h,[save_folder  strPath_struct(edf_file_idx).name(1:end-4) '_channel '...
            int2str(index_2_keep(i)) '.fig']);
    end
    disp('Successfully saved matlab figures');
end
end

%% function add_padding
function arr_artefact = add_padding(arr_artefact, padding, direction)

if direction>0
    % count number of consecutive artefacts
    out_art = double(diff([~arr_artefact(1);arr_artefact(:)]) == 1);
    v = accumarray(cumsum(out_art).*arr_artefact(:)+1,1);
    out_art(out_art == 1) = v(2:end);
    out_art = floor(out_art .*(1+padding));
    
    idx_ones_all = find(out_art>0);
    for  idx_ones = 1:length(idx_ones_all)
        end_idx = min(length(arr_artefact),idx_ones_all(idx_ones) + out_art(idx_ones_all(idx_ones)));
        arr_artefact(idx_ones_all(idx_ones):end_idx)=1;
    end
else
    % count number of consecutive artefacts
    out_art_neg = double(diff([~arr_artefact(1);arr_artefact(:)]) == 1);
    v = accumarray(cumsum(out_art_neg).*arr_artefact(:)+1,1);
    out_art(out_art_neg == 1) = v(2:end);
    out_art_neg = floor(out_art_neg .*(1+padding));
    
    idx_ones_all = find(out_art_neg>0);
    for  idx_ones = 1:length(idx_ones_all)
        strt_idx = max(1,idx_ones_all(idx_ones)-out_art_neg(idx_ones_all(idx_ones)));
        arr_artefact(strt_idx:idx_ones_all(idx_ones))=1;
    end
    
end
end

%% function fillgaps
function matrix2save  = fillgaps(artefact_vector,index_2_keep,data,Fs)
% assign false detected artefacts as good data
not_segments_nomean_reshape = ~artefact_vector;
out = double(diff([~not_segments_nomean_reshape(1);not_segments_nomean_reshape(:)]) == 1);
v = accumarray(cumsum(out).*not_segments_nomean_reshape(:)+1,1);
out(out ==1) = v(2:end);
idx_artefacts = find(out>0);

% for loop on all channels
for all_ch = 1:length(index_2_keep)
    Sig1 = []; segments_nomean_NoArtefacts = {};end_previous_gap = 0;
    Sig1(all_ch,:) = data(all_ch,:);
    for i = 1:length(idx_artefacts)
        segments_nomean_NoArtefacts{i} = Sig1(all_ch,end_previous_gap+1:idx_artefacts(i)-1);
        end_previous_gap = idx_artefacts(i) + out(idx_artefacts(i));
    end
    segments_nomean_NoArtefacts{i+1} = Sig1(all_ch,end_previous_gap+1:end);
    
    % calculate drift
    for i= 3:size(segments_nomean_NoArtefacts,2)
        if ~isempty(segments_nomean_NoArtefacts{i})
            if ~isempty(segments_nomean_NoArtefacts{i-1})
                segments_nomean_NoArtefacts{i}(:) = segments_nomean_NoArtefacts{i}(:) + ...
                    (-segments_nomean_NoArtefacts{i}(1) + segments_nomean_NoArtefacts{i-1}(end));
            elseif ~isempty(segments_nomean_NoArtefacts{i-2})
                segments_nomean_NoArtefacts{i}(:) = segments_nomean_NoArtefacts{i}(:) + ...
                    (-segments_nomean_NoArtefacts{i}(1) + segments_nomean_NoArtefacts{i-2}(end));
            end
        end
    end
    
    clean_signal = cell2mat(segments_nomean_NoArtefacts);
    % detrend signal
    time_axis_noArtefacts = (0:length(clean_signal)-1)./Fs./60;
    deterend_sig = movmean(clean_signal,[0.2*Fs 0.2*Fs]);
    clean_signal = clean_signal - deterend_sig;
    clean_signal_cell{1,all_ch} = clean_signal;
end

% matrix to save without annotations
matrix2save = cell2mat(clean_signal_cell');
end

%% convert_dist2sig
function artefact_vector = convert_dist2sig(data,unique_groups,sure_artefacts,Fs,seg)

data_art = zeros(size(data));
for groups = 1:length(unique_groups)
    for j=1:length(unique_groups{groups})
        for art_idx = 0:size(sure_artefacts,2)-1
            end_sample = min(length(data_art),(art_idx+1)*floor(seg*Fs));
            if sure_artefacts(groups,art_idx+1)==1
                data_art(unique_groups{groups}(j),art_idx*floor(seg*Fs)+1:end_sample) = 1;
            else
                data_art(unique_groups{groups}(j),art_idx*floor(seg*Fs)+1:end_sample) = 0;
            end
        end
    end
end

artefact_vector = ~(sum(data_art,1)>0);

end