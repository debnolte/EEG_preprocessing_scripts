%% Automatic cleaning and preprocessing - plot each individual step

% The original script was developed by Vincent Schmidt.
% Small adjustements, saving the cleaned data and a 90Hz line noise filter
% was added by Debora Nolte.  

%%
clear all;
% load EEGlab
addpath('/Volumes/DebbieSan/wd_ride_village/Matlab-resources/eeglab2020_0');
addpath('/Volumes/DebbieSan/wd_ride_village/Matlab-resources/preprocessing_helpers');
addpath('/Volumes/DebbieSan/wd_ride_village/Matlab-resources/NoiseTools');
addpath('/Volumes/DebbieSan/wd_ride_village/Matlab-resources');
eeglab;

savepath='/Volumes/DebbieSan/wd_ride_village/processedData/village/';
cd('/Volumes/DebbieSan/wd_ride_village/repos/wd-pilot-pipeline');
rec_vill = readtable('recordings_village.csv');
% Then go to the folder where the preprocessed data is stored
basepath='/Volumes/DebbieSan/automated_preproc/';
cd(basepath);

sub = 1;

cd('/Volumes/DebbieSan/wd_ride_village/recordedData/wd_village/');
uidname = rec_vill{sub,1};
uidname = uidname{1,1};

savedata = [basepath, uidname, '/'];    
% add this new folder to the savedata path, so where the intermediate steps
% will be saved
savedata = [savedata, 'automated_preproc/'];

% get the corresponding file name
if sub > 39
    cntfile = dir(string(sub)+'_v1_'+'*'+'.xdf');
else
    cntfile = dir('0'+string(sub)+'_v_'+'*'+'.xdf');
end
cntpath = fullfile(basepath,cntfile.name);
[filepath,filename,ext] = fileparts(cntpath); % define variables
filepath = [filepath filesep];
filename = [filename ext];

%% Plot the raw data
excludeMrkrStrms={'HitPositionOnObjects','ValidationError','StaticAgentRotation',...
    'HitPositionOnObjects','HitObjectPositions','HeadTracking','openvibeMarkers',...
    'EyeTrackingWorld','AgentPosition','AgentRotation','PlayerPosition',...
    'ButtonPresses','HitObjectNames','EyeTrackingLocal','StaticAgentPosition'};
%EEG = eeg_load_xdf(filename, 'streamname','openvibeSignal', 'exclude_markerstreams', excludeMrkrStrms);
EEG_raw = EEG;
eegplot(EEG_raw.data,'srate',EEG_raw.srate)

%% Plot data after adding channel names and reject empty channels
EEG = pop_loadset(sprintf('0a_rawChanNames_%s.set',uidname),fullfile(basepath));

eegplot(EEG.data,'srate',EEG.srate,'eloc_file',EEG.chanlocs)

%% Plot trigger files
trgname = sprintf('TriggerFile_newTSdd_%s.csv',uidname);
trgpath = '/Volumes/DebbieSan/wd_ride_village/repos/wd-pilot-pipeline/data/village/processed/Trigger_MAD_newfile';
EEG = pop_importevent(EEG,'event',fullfile(trgpath,trgname),'fields', {'latency','type'}, 'skipline', 1);

eegplot(EEG.data,'srate',EEG.srate,'eloc_file',EEG.chanlocs,'events',EEG.event)

%% Plot high-pass filtered data
high_pass = .1;
EEG = pop_loadset(sprintf('highpass_%s.set',uidname),fullfile(basepath));
eegplot(EEG.data,'srate',EEG.srate,'eloc_file',EEG.chanlocs,'events',EEG.event)

%% Plot low-pass filtered data
low_pass = 128; 
EEG = pop_loadset(sprintf('lowpass_%s.set',uidname),fullfile(basepath));
eegplot(EEG.data,'srate',EEG.srate,'eloc_file',EEG.chanlocs,'events',EEG.event)

%% Show plot before zapline 

% takes long so we will not run this code
% pop_spectopo(EEG)

%% Show plot after zapline

% takes long so we will not run this code
% pop_spectopo(EEG)

%% Channel removal, data cleaning
% used clean_artifacts to clean the data
EEG_clean = pop_loadset(sprintf('2a_cleanDataChannels_%s.set',uidname),fullfile(basepath));
vis_artifacts(EEG_clean,EEG);

EEG = EEG_clean;
clear EEG_clean
%% Plot ICs
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/eeglab2020_0/plugins/Amica')
outDir = fullfile(basepath, 'amica');
cd(outDir)

mod = loadmodout15(outDir);
% apply ICA weights to data
EEG.icasphere = mod.S;
EEG.icaweights = mod.W;
EEG = eeg_checkset(EEG);

% use iclabel to determine which ICs to reject
EEG = iclabel(EEG);
pop_viewprops(EEG, 0)

%% Plot finished data - TODO!!
EEG = pop_loadset(sprintf('4a_interpolation_%s.set',uidname),fullfile(basepath));
eegplot(EEG.data,'srate',EEG.srate,'eloc_file',EEG.chanlocs,'events',EEG.event)


EEG = pop_epoch(EEG, {}, [-0.2 0.5]);

