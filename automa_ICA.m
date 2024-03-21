%% This script can be used to only run ICA without the other preprocessing steps

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
subs = [];
%%
for sub = 1:length(subjects) 
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
    %% if previous step was completed, load the file
    cd(savedata);
    if isfile(sprintf('2a_cleanDataChannels_%s.set',uidname)) && ~exist('amica', 'dir')
        % to keep track of the progress
        subs = [subs, s];
        save(fullfile(basepath,'subs2'),'subs')
        
        % load data for ICA
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
        
    end
end





