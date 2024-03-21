%% Automatic cleaning and preprocessing
% This script was developed by Vincent Schmidt.
% Small adjustements, saving the cleaned data and a 90Hz line noise filter
% were added by Debora Nolte.  

%%
clear all;
% load EEGlab
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/eeglab2020_0');
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/preprocessing_helpers');
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/NoiseTools');
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources');
eeglab;

%% First, open the table with all the uid names
savepath='/net/store/nbp/projects/wd_ride_village/processedData/village/';
cd('/net/store/nbp/projects/wd_ride_village/repos/wd-pilot-pipeline');
rec_vill = readtable('recordings_village.csv');
% Then go to the folder where the preprocessed data is stored
basepath='/net/store/nbp/projects/wd_ride_village/processedData/village/preprocessed/';
cd(basepath);
%%
subjects = [1,2,4,5,7,8,10,11,12,15,16,17,18,19,20,21,22,24,26,27,29,30,31,32,33,...
    34,36,37,38,41,42,43,44,45,46,47,48,49,50,51,53,54,55,56,57,58,59,60];
%%
for sub = 1:length(subjects)
sub = 32; % if not manual, the subject can be adjusted
s = subjects(sub); 

cd('/net/store/nbp/projects/wd_ride_village/recordedData/wd_village/');
uidname = rec_vill{sub,1};
uidname = uidname{1,1};
    
savedata = [basepath, uidname, '/'];


% create a folder to save all automated preprocessing files
mkdir(fullfile(savedata,'automated_preproc/'))
permission_cleanup(savedata);
% add this new folder to the savedata path, so where the intermediate steps
% will be saved
savedata = [savedata, 'automated_preproc/'];

% get the corresponding file name
if s > 39
    cntfile = dir(string(s)+'_v1_'+'*'+'.xdf');
elseif s < 10
    cntfile = dir('0'+string(s)+'_v_'+'*'+'.xdf');
else
    cntfile = dir(string(s)+'_v_'+'*'+'.xdf');
end
cntpath = fullfile(basepath,cntfile.name);
[filepath,filename,ext] = fileparts(cntpath); % define variables
filepath = [filepath filesep];
filename = [filename ext];


%% load the .xdf file
excludeMrkrStrms={'HitPositionOnObjects','ValidationError','StaticAgentRotation',...
    'HitPositionOnObjects','HitObjectPositions','HeadTracking','openvibeMarkers',...
    'EyeTrackingWorld','AgentPosition','AgentRotation','PlayerPosition',...
    'ButtonPresses','HitObjectNames','EyeTrackingLocal','StaticAgentPosition'};
EEG = eeg_load_xdf(filename, 'streamname','openvibeSignal', 'exclude_markerstreams', excludeMrkrStrms);
%% Electrode renaming and rejection of empty channels
newchanlabels = importdata(fullfile(savepath,'EEG-channel-names.txt'));
for n = 1:length(newchanlabels)
    EEG.chanlocs(n).labels = newchanlabels{n};
end

% Adjusting the channel locations for the specific setup we used for the recording:
EEG=pop_chanedit(EEG, 'lookup','/net/store/nbp/projects/EEG_Training/Analysis/eeglab14_1_1b/plugins/dipfit2.3/standard_BESA/standard-10-5-cap385.elp');

% Cleaning: which channels do not contain EEG data by default?
alldel = {'BIP1' 'BIP2' 'BIP3' 'BIP4' 'BIP5' 'BIP6' 'BIP7' 'BIP8' 'AUX1' 'AUX2' 'AUX3' 'AUX4' 'AUX5' 'AUX6' 'AUX7' 'Reference' 'AUX69' 'AUX70' 'AUX71' 'AUX72' 'INPUT' 'BIP65' 'BIP66' 'BIP67' 'BIP68'};
EEG = pop_select(EEG, 'nochannel', alldel);

% save the data: always add an 'a' behind the number of automated
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('0a_rawChanNames_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('0a_rawChanNames_%s',uidname),'filepath',fullfile(savedata));

%% Import the trigger file, filtering 
EEG = pop_loadset(sprintf('0a_rawChanNames_%s.set',uidname),fullfile(savedata));

% import the trigger file
trgname = sprintf('TriggerFile_newTSdd_%s.csv',uidname);
trgpath = '/net/store/nbp/projects/wd_ride_village/repos/wd-pilot-pipeline/data/village/processed/Trigger_MAD_newfile';
EEG = pop_importevent(EEG,'event',fullfile(trgpath,trgname),'fields', {'latency','type','saccade_amp'}, 'skipline', 1,'append','no');

% filter the data
% parameters adapted from Czeszumski, 2023 (Hyperscanning Maastricht)
low_pass = 128; 
high_pass = .1;
EEG = pop_eegfiltnew(EEG, high_pass, []); % 0.1 is the lower edge
EEG = pop_eegfiltnew(EEG, [], low_pass); % 100 is the upper edge

% remove line noise with zapline
zaplineConfig=[];
zaplineConfig.noisefreqs='line'; %49.97:.01:50.03; %Alternative: 'line'
EEG = clean_data_with_zapline_plus_eeglab_wrapper(EEG, zaplineConfig); EEG.etc.zapline

% remove noise of refresh rate of the glasses (at 90 Hz)
zaplineConfig=[];
zaplineConfig.noisefreqs=89.97:.01:90.03; 
EEG = clean_data_with_zapline_plus_eeglab_wrapper(EEG, zaplineConfig); EEG.etc.zapline

% save the data: always add an 'a' behind the number of automated
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('1a_triggersFiltering_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('1a_triggersFiltering_%s',uidname),'filepath',fullfile(savedata));

%% Channel removal, data cleaning
EEG = pop_loadset(sprintf('1a_triggersFiltering_%s.set',uidname),fullfile(savedata));

full_chanlocs = EEG.chanlocs; % used for data cleaning and interpolation

% From documentation: Use vis_artifacts to compare the cleaned data to the original.
[EEG,HP,BUR] = clean_artifacts(EEG);

Zr=find(EEG.etc.clean_sample_mask == 0); % find all rejected elements
if ~isempty(Zr)
    starts = Zr(1);
    ends = [];
    for z = 2:length(Zr)
        if Zr(z-1) + 1 ~= Zr(z)
            starts = [starts, Zr(z)];
            ends = [ends, Zr(z-1)];
        end
    end
    ends = [ends, Zr(z)];
    tmprej = [starts;ends]'; % save the noisy segments (beginning & end)
    % save the removed intervals
    save(fullfile(savedata,sprintf('removed_intervals_%s.mat',uidname)),'tmprej');
end
% save removed channels
removed_channels = ~ismember({full_chanlocs.labels},{EEG.chanlocs.labels});
EEG.removed_channels = {full_chanlocs(removed_channels).labels};

% save the removed channels
save(fullfile(savedata,sprintf('removed_channels_%s.mat',uidname)),'removed_channels');

% save the data: always add an 'a' behind the number of automated
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('2a_cleanDataChannels_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('2a_cleanDataChannels_%s',uidname),'filepath',fullfile(savedata));

BUR = pop_editset(BUR, 'setname', sprintf('2a_cleanDataChannels_woRejection_%s',uidname)); 
BUR = pop_saveset(BUR, 'filename',sprintf('2a_cleanDataChannels_woRejection_%s',uidname),'filepath',fullfile(savedata));
%% ICA
EEG = pop_loadset(sprintf('2a_cleanDataChannels_%s.set',uidname),fullfile(savedata));

addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/eeglab2020_0/plugins/Amica')

% create a folder to save the ICA outputs
mkdir(fullfile(savedata,'amica'))
addpath(fullfile(savedata,'amica'))
permission_cleanup(savedata);
outDir = fullfile(savedata, 'amica');
cd(outDir)
% highpass-filter the data at 2 Hz to not include slow drifts in the ICA
eeg_tmp = pop_eegfiltnew(EEG, 2, []);   
dataRank = rank(double(eeg_tmp.data'));

runamica15(eeg_tmp.data, 'num_chans', eeg_tmp.nbchan,'outdir', outDir,... 
    'numprocs', 1,...
    'max_threads', 8,... 
    'pcakeep', dataRank, 'num_models', 1);
 
%% load ICA results
EEG = pop_loadset(sprintf('2a_cleanDataChannels_%s.set',uidname),fullfile(savedata));
outDir = fullfile(savedata, 'amica');

mod = loadmodout15(outDir);
% apply ICA weights to data
EEG.icasphere = mod.S;
EEG.icaweights = mod.W;
EEG = eeg_checkset(EEG);

% use iclabel to determine which ICs to reject
EEG = iclabel(EEG);
%pop_viewprops(EEG, 0)

% list components that should be rejected
components_to_remove = [];
        
for component = 1:length(EEG.chanlocs)
    % muscle
    if EEG.etc.ic_classification.ICLabel.classifications(component,2) > .80
        components_to_remove = [components_to_remove component];
    end
    % eye
    if EEG.etc.ic_classification.ICLabel.classifications(component,3) > .9
        components_to_remove = [components_to_remove component];
    end
    % heart
    if EEG.etc.ic_classification.ICLabel.classifications(component,4) > .9
        components_to_remove = [components_to_remove component];
    end
    % line noise
    if EEG.etc.ic_classification.ICLabel.classifications(component,5) > .9
        components_to_remove = [components_to_remove component];
    end
    % channel noise
    if EEG.etc.ic_classification.ICLabel.classifications(component,6) > .9
        components_to_remove = [components_to_remove component];
    end
end      
% remove components
EEG = pop_subcomp(EEG, components_to_remove, 0);
% save removed components in struct
EEG.removed_components = components_to_remove;

% save the data
save(fullfile(savedata,sprintf('removed_components_%s.mat',uidname)),'components_to_remove');

EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('3a_ICA_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('3a_ICA_%s',uidname),'filepath',fullfile(savedata));

%% Interpolating missing channels
% get all channels that need to be interpolated
EEG_chan = pop_loadset(sprintf('1a_triggersFiltering_%s.set',uidname),fullfile(savedata));
full_chanlocs = EEG_chan.chanlocs; % used for data cleaning and interpolation
clear EEG_chan

EEG = pop_loadset(sprintf('3a_ICA_%s.set',uidname),fullfile(savedata));

EEG = pop_interp(EEG,full_chanlocs,'spherical');

EEG = eeg_checkset(EEG);
 % check if duplicate channel label
if isfield(EEG.chanlocs, 'labels')
    if length( { EEG.chanlocs.labels } ) > length( unique({ EEG.chanlocs.labels } ) )
        disp('Warning: some channels have the same label');
    end
end

% save the results
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('4a_interpolation_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('4a_interpolation_%s',uidname),'filepath',fullfile(savedata));

end
%%




