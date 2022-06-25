% this function import .rhfe files, calculate dominant frewquency and power
function rhfe2mat()
%% Build GUI
% Figure Background Color
v_FigColor      = [212 208 200]/255;
% letter size
st_Letter       = f_GetLetterSize();

% main Figure
st_hFigure = figure(...
    'MenuBar','None', ...
    'ToolBar','None', ...
    'NumberTitle','off', ...
    'Name','rhfe 2 matlab conversion tool', ...
    'Color',v_FigColor,...
    'Units','normalized',...
    'Position',[.3 .4 .4 .15],...
    'Visible','on',...
    'Renderer','OpenGL');

% labels
filepath_text = uicontrol(st_hFigure,...
    'Style','edit',...
    'BackgroundColor',v_FigColor+43/255,...
    'ForegroundColor','k',...
    'HorizontalAlignment','left',...
    'FontSize',1*st_Letter.toollabel,...
    'String',' Select File Path',...
    'Units','normalized',...
    'Interruptible','on',...
    'Position',[.1 .6 .6 .16]);
% buttons
     uicontrol(st_hFigure,...
    'Style','pushbutton',...
    'BackgroundColor',v_FigColor,...
    'Units','normalized',...
    'String','Browse',...
    'Position',[.72 .6 .1 .16],...
    'CallBack',@f_SelectFile);
    uicontrol(st_hFigure,...
    'Style','pushbutton',...
    'BackgroundColor',v_FigColor,...
    'Units','normalized',...
    'String','Convert',...
    'Position',[.35 .3 .1 .16],...
    'Interruptible','on',...
    'CallBack',@f_Convert);
    uicontrol(st_hFigure,...
    'Style','pushbutton',...
    'BackgroundColor',v_FigColor,...
    'Units','normalized',...
    'String','Cancel',...
    'Position',[.5 .3 .1 .16],...
    'CallBack',@f_Cancel);

%% define variables
st_Load = [];
st_Save = [];
%% functions
    function f_SelectFile(~,~)
        
        str_PathName = '.\Analysis\';
        if exist(str_PathName,'dir')
            [str_FileName,str_PathName]   = uigetfile('*.rhfe',...
                'Select the HFO analysis file',...
                str_PathName);
            set(filepath_text,'String',fullfile(str_PathName,str_FileName));
        else
            [str_FileName,str_PathName]   = uigetfile('*.rhfe',...
                'Select the HFO analysis file');
            set(filepath_text,'String',fullfile(str_PathName,str_FileName));
        end
        st_LoadInfo.str_FullPath = fullfile(str_PathName,str_FileName);
        st_Load         = load(st_LoadInfo.str_FullPath,'-mat');
        st_Load         = rmfield(st_Load,{'st_FileData'});
        
    end

    function f_Cancel(~,~)
        close(st_hFigure)
    end

    function f_Convert(~,~)
        event_type = {'None', 'Gamma', 'Ripple', 'Fast Ripple', 'Spike', 'Artifact', 'Other'};
        [s_file,s_path] = uiputfile('*.mat','save');
        if s_file~=0
            disp('Converting...');
            pvh  = waitbar(0,'Please wait...','CreateCancelBtn',@cancel_waitbar);
            setappdata(pvh, 'cancel_callback', 0);
            pause(1);
            % get electrodes names
            electrode_name = fieldnames(st_Load);
            % power calculation parameters
            s_FreqSeg       = 512;
            s_StDevCycles   = 3;
            s_Magnitudes    = 1;
            s_SquaredMag    = 0;
            s_MakeBandAve   = 0;
            
            for i =1:length(electrode_name)
                
                s_data =   st_Load.(electrode_name{i});
                s_MinFreqHz     = s_data.st_HFOSetting.s_FreqIni;
                s_MaxFreqHz     = s_data.st_HFOSetting.s_FreqEnd;
                pause(1);                
                if getappdata(pvh, 'cancel_callback') == 1
                    errordlg('Stopped by user');    
                    break
                end
                % update waitbar
                waitbar(i/length(electrode_name),pvh ,['Analysing electrode ' num2str(i)]);
                
                for j =1:size(s_data.v_Intervals,1)
                    disp(['calculating spectrum for interval ' num2str(j) ...
                        ' out of ' num2str(size(s_data.v_Intervals,1))]);
                    % stop if cancelled
                    pause(0.1)
                    if getappdata(pvh, 'cancel_callback') == 1
                        errordlg('Stopped by user');    
                        break
                    end
                    % calculate power spectrum for each event
                    v_SigInterv = s_data.v_Intervals{j};
                    [m_GaborWT, ~, v_FreqAxis] = ...
                        f_GaborTransformWait(...
                        v_SigInterv,...
                        s_data.st_HFOInfo.s_Sampling,...
                        s_MinFreqHz, ...
                        s_MaxFreqHz, ...
                        s_FreqSeg, ...
                        s_StDevCycles, ...
                        s_Magnitudes, ...
                        s_SquaredMag, ...
                        s_MakeBandAve);
                    
                    % reduce caluclation to event inside the interval
                    s_spectrum = mean(m_GaborWT(:,s_data.st_HFOInfo.m_Rel2IntLims(j,1)...
                        :s_data.st_HFOInfo.m_Rel2IntLims(j,2))');
                    
                    s_spectrum    = f_Matrix2Norm(s_spectrum);
                    
                    % detect peaks in power
                    [pks, locs] = findpeaks(s_spectrum,fliplr(v_FreqAxis),'MinPeakProminence',0.05);
                    % sort the detected peaks
                    [pks,indx] = sort(pks,'descend');
                    locs = locs(indx);
                    % populate the save matrix
                    st_Save.(electrode_name{i})(j).strt_time = s_data.st_HFOInfo.m_EvtLims(j,1)...
                        /s_data.st_HFOInfo.s_Sampling;
                    st_Save.(electrode_name{i})(j).end_time = s_data.st_HFOInfo.m_EvtLims(j,2)...
                        /s_data.st_HFOInfo.s_Sampling;
                    st_Save.(electrode_name{i})(j).Event_Type = event_type{st_Load.(electrode_name{i}).st_HFOInfo.v_EvType(j)};
                    if ~isempty(pks)
                        st_Save.(electrode_name{i})(j).peak_power = pks(1);
                        st_Save.(electrode_name{i})(j).peak_freq = locs(1);
                        if length(pks)> 1
                            st_Save.(electrode_name{i})(j).second_peak_power = pks(2);
                            st_Save.(electrode_name{i})(j).second_peak_freq = locs(2);
                            if length(pks)> 2
                                st_Save.(electrode_name{i})(j).third_peak_power = pks(3);
                                st_Save.(electrode_name{i})(j).third_peak_freq = locs(3);
                            else
                                st_Save.(electrode_name{i})(j).third_peak_power = NaN;
                                st_Save.(electrode_name{i})(j).third_peak_freq = NaN;
                            end
                        else
                            st_Save.(electrode_name{i})(j).second_peak_power = NaN;
                            st_Save.(electrode_name{i})(j).second_peak_freq = NaN;
                            st_Save.(electrode_name{i})(j).third_peak_power = NaN;
                            st_Save.(electrode_name{i})(j).third_peak_freq = NaN;
                        end
                    else
                        st_Save.(electrode_name{i})(j).peak_power = NaN;
                        st_Save.(electrode_name{i})(j).peak_freq = NaN;
                        st_Save.(electrode_name{i})(j).second_peak_power = NaN;
                        st_Save.(electrode_name{i})(j).second_peak_freq = NaN;
                        st_Save.(electrode_name{i})(j).third_peak_power = NaN;
                        st_Save.(electrode_name{i})(j).third_peak_freq = NaN;
                    end
                end
                
                A = {'start time','end time', 'Event Type','highest peak power', 'freq (Hz)',...
                    '2nd peak power', 'freq (Hz)','3rd peak power', 'freq (Hz)'};
                B = struct2cell( st_Save.(electrode_name{i})');
                C = [A',B]';
                sheet = electrode_name{i};
                if getappdata(pvh, 'cancel_callback') == 0
                xlswrite(fullfile(s_path,s_file(1:end-4)),C,sheet);
                end                
            end
            if getappdata(pvh, 'cancel_callback') == 0
            % save the matrix in corresponding file
            save(fullfile(s_path,s_file),'st_Save');
            end
            delete(pvh)
        else
            return
        end
    end
    function cancel_waitbar(hObject, ~)
        disp('yes');
        phv = ancestor(hObject, 'figure');
        setappdata(phv, 'cancel_callback', 1);
    end
end