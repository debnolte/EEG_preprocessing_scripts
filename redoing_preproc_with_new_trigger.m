%% Redo the preprocessing steps for replacing trigger files:
% 1. load the data without the removed artifacts after running clean_artifacts
% 2. redo the trigger file & save the data
% 3. reject the noisy periods & save the data
% 4. reject noisy ICs & save data
% 5. Interopate & save data
%%
clear variables
close all;
clc;
%%
addpath('/net/store/nbp/projects/wd_ride_village/Matlab-resources/eeglab2020_0');
% load EEGlab
eeglab;
basepath='/net/store/nbp/projects/wd_ride_village/processedData/village/preprocessed/';
cd(basepath);
cd('/net/store/nbp/projects/wd_ride_village/repos/wd-pilot-pipeline');
rec_vill = readtable('recordings_village.csv');
%%
subjects = [1,2,4,5,7,8,10,11,12,15,16,17,18,19,20,21,22,24,26,27,29,30,31,32,33,...
    34,36,37,38,41,42,43,44,45,46,47,48,49,50,51,53,54,55,56,57,58,59,60];

currElec = 'Oz';
%%
sub = 40; % subject to run (can be replaced by for loop for all subjects)
s = subjects(sub); 

cd('/net/store/nbp/projects/wd_ride_village/recordedData/wd_village/');
uidname = rec_vill{sub,1};
uidname = uidname{1,1};

savedata = [basepath, uidname, '/'];

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

%% load the data without the removed artifacts after running clean_artifacts
EEG = pop_loadset(sprintf('2a_cleanDataChannels_woRejection_%s.set',uidname),fullfile(savedata));

%% redo the trigger file
trgname = sprintf('TriggerFile_newTSdd_%s.csv',uidname);
trgpath = '/net/store/nbp/projects/wd_ride_village/repos/wd-pilot-pipeline/data/village/processed/Trigger_MAD_newfile';
EEG = pop_importevent(EEG,'event',fullfile(trgpath,trgname),'fields', {'latency','type','saccade_amp'}, 'skipline', 1,'append','no');

% save the data: always add an 'a' behind the number of automated
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('2a_cleanDataChannels_woRejection_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('2a_cleanDataChannels_woRejection_%s',uidname),'filepath',fullfile(savedata));
%% reject the noisy periods
if isfile(fullfile(savedata,sprintf('removed_intervals_%s.mat',uidname)))
    load(fullfile(savedata,sprintf('removed_intervals_%s.mat',uidname)));
    EEG = eeg_eegrej(EEG,tmprej);
end
% save the data: always add an 'a' behind the number of automated
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('2a_cleanDataChannels_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('2a_cleanDataChannels_%s',uidname),'filepath',fullfile(savedata));
%% reject noisy ICs
load(fullfile(savedata,sprintf('removed_components_%s.mat',uidname)));

outDir = fullfile(savedata, 'amica');
mod = loadmodout15(outDir);

EEG.icaweights  = mod.W;
EEG.icasphere   = mod.S;
EEG.icawinv     = [];
EEG.icaact      = [];
EEG.icachansind = [];
EEG             = eeg_checkset(EEG);
% get the bad components out of the saved ICA file and re-reject them 
EEG             = pop_subcomp(EEG,components_to_remove);

% save the results
EEG = eeg_checkset(EEG);
EEG = pop_editset(EEG, 'setname', sprintf('3a_ICA_%s',uidname)); 
EEG = pop_saveset(EEG, 'filename',sprintf('3a_ICA_%s',uidname),'filepath',fullfile(savedata));

%% Interpolating missing channels
% get all channels that need to be interpolated
EEG_chan = pop_loadset(sprintf('1a_triggersFiltering_%s.set',uidname),fullfile(savedata));
full_chanlocs = EEG_chan.chanlocs; % used for data cleaning and interpolation
clear EEG_chan

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


