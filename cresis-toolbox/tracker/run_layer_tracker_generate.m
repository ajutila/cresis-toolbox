% script run_layer_tracker_tune
% Runs layer_tracker.m for tuning layer tracking hyperparameters.
%
% Authors: Anjali Pare, John Paden
%
% See also: layer_tracker.m, layer_tracker_combine_task.m,
% layer_tracker_task.m, layer_tracker_profile.m, run_layer_tracker.m,
% run_layer_tracker_tune.m

%% User Settings
% ----------------------------------------------------------------------
param_override = [];

% params = read_param_xls(ct_filename_param('rds_param_2011_Greenland_P3.xls'));
%params = read_param_xls(ct_filename_param('rds_param_2014_Greenland_P3.xls'));
% params = read_param_xls(ct_filename_param('rds_param_2018_Greenland_P3.xls'));
params_all = [];
idx_segment = 1;
params = read_param_xls(ct_filename_param('rds_param_2014_Greenland_P3.xls'),'20140415_05|20140421_01|20140516_01');%'20140313_09|20140415_05|20140421_01|20140514_01');
params(idx_segment).cmd.generic = 1;
params(idx_segment).cmd.frms = [];
idx_segment = idx_segment + 1;
params(idx_segment).cmd.generic = 1;
params(idx_segment).cmd.frms = [];
idx_segment = idx_segment + 1;
params(idx_segment).cmd.generic = 1;
params(idx_segment).cmd.frms = [];

% params = ct_set_params(params,'cmd.generic',0);
% params = ct_set_params(params,'cmd.generic',1,'day_seg','20140313_09|20140516_01');%20140415_05|20140421_01|');%'20140415_05|20140421_01|20140514_01|20140313_09');
% params = ct_set_params(params,'cmd.frms',[]); % Specify specific frames (or leave empty/undefined to do all frames)
% params = ct_set_params(params,'cmd.generic',1,'day_seg','20110331_02');
% params = ct_set_params(params,'cmd.frms',19); % Specify specific frames (or leave empty/undefined to do all frames)


% layer_params: layerparams structure of where to store the output using
% opsCopyLayers.m
param_override.layer_tracker.layer_params = [];
% Uncomment to enable layerdata storage
param_override.layer_tracker.layer_params.layerdata_source = 'layer_tune_vit_seg4_C';
param_override.tmp_name = 'layer_tune_lsm_4seg_t001';
% Uncomment to enable OPS storage
% param_override.layer_tracker.layer_params.source = 'ops';

tracker_method = 'lsm'; % Choose the tracking method
% block_size_frms: Number of frames to be loaded at a time
param_override.layer_tracker.block_size_frms = 1;

% track_per_task: Number of tracks per task
param_override.layer_tracker.track_per_task = 1;

%% param.layer_tracker.track options
options = [];
options.segment_vs_frame.plot = true; % absolute error vs frames (for each segment)
options.segment_vs_frame.fig_format = true;
options.season_vs_gps.plot = true; % absolute error vs gps time (for entire season)
options.season_vs_gps.fig_format = true;
options.season_vs_gps.multiple_figs = true; % choose this option if you separate plots generated for each layer. If set to false, 6 subplots will be plotted in one figure.
options.absolute_error.plot = true; % mean absolute error plots
options.absolute_error.fig_format = true;
options.absolute_error.multiple_plots = true;
options.percentage_correct.plot = true; % plot of percentage correct vs frames (for each segment)
options.percentage_correct.fig_format = true;
options.percentage_correct.multiple_plots = true;
options.hist_generation.plot = true; % histograms of data points vs absolute error
options.hist_generation.fig_format = true;
options.hist_generation.multiple_plots = true;
param_override.options = options;

seg_idx = 0;
filename = [];
 %filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140313_09_20210311_013103_t056_lsm.mat');
 filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140415_05_20210311_013232_t056_lsm.mat');
 filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140421_01_20210311_014435_t056_lsm.mat');
 filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140516_01_20200909_032808_t056_lsm.mat');
 %filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140313_08_20210408_205951_t006_lsm.mat');%20140313_08_20210407_100556_t005_viterbi.mat');
 %filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140313_09_20210408_210034_t006_lsm.mat');%20140313_09_20210401_230350_t005_viterbi.mat');

 
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140313_09_20210401_230350_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140415_05_20210401_231542_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140421_01_20210402_000547_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140516_01_20210402_003509_t005_viterbi.mat');
%  

% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140313_09_20210331_232507_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140415_05_20210331_233855_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140421_01_20210401_004304_t005_viterbi.mat');
% filename{end+1} = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/layer_tracker/rds/2014_Greenland_P3/20140516_01_20210401_012014_t005_viterbi.mat');
% 

%param_override.filename = filename;
% param_override.layer_tracker.surf_layer = struct('name','surface','source','layerdata','layerdata_source','layer');

% param_override.layer_tracker.crossover_layer = struct('name','bottom','source','ops');

% If surface and bottom
% foo{idx} = [];
% gt_layer_params(idx).name = 'surface';
% idx = idx + 1;
% foo{idx} = [];
% gt_layer_params(idx).name = 'bottom'; % specify layer names

% dbstop if error;
param_override.cluster.type = 'torque';
% param_override.cluster.type = 'matlab';
% param_override.cluster.type = 'debug';
% param_override.cluster.type = 'slurm';
% param_override.cluster.rerun_only = true;
% param_override.cluster.desired_time_per_job  = 240*60;
param_override.cluster.cpu_time_mult  = 30;
param_override.cluster.mem_mult  = 15;

idx = 1;
gt_layer_params = [];
gt_layer_params(idx).name = 'surface';
idx = idx + 1;
gt_layer_params(idx).name = 'bottom'; % specify layer names
param_override.gt_layer_params = gt_layer_params;
layer_idx = length(gt_layer_params);


%% Automated Section
% ----------------------------------------------------------------------

% Input checking
global gRadar;
if exist('param_override','var')
  param_override = merge_structs(gRadar,param_override);
else
  param_override = gRadar;
end

ctrl_chain = {};
img_fn_dir = {};
all_params = {};
% Process each of the segments
for param_idx = 1:length(params)
  param = params(param_idx);
  if isfield(param.cmd,'generic') && ~iscell(param.cmd.generic) && ~ischar(param.cmd.generic) && param.cmd.generic
    param = merge_structs(param, param_override);
    frames = frames_load(param);
    param.cmd.frms = frames_param_cmd_frms(param,frames);
    seg_idx = seg_idx + 1;
    param.filename = filename{seg_idx};
    all_params{end+1} = param.day_seg;
    fprintf('=====================================================================\n');
    fprintf('%s: %s (%s)\n', mfilename, param.day_seg, datestr(now));
    fprintf('=====================================================================\n');

%% Set up Cluster
% ===================================================================

    ctrl = cluster_new_batch(param);
%cluster_compile({'layer_tracker_task'},ctrl.cluster.hidden_depend_funs,ctrl.cluster.force_compile,ctrl);
    cluster_compile({'layer_tracker_generate_task','layer_tracker_generate_combine_task'},ctrl.cluster.hidden_depend_funs,ctrl.cluster.force_compile,ctrl);

%% layer_tracker
% =========================================================================
% =========================================================================

% Cluster setup
% -------------------------------------------------------------------------
dparam = [];
sparam.argsin{1} = param;
sparam.task_function = 'layer_tracker_generate_task';
sparam.argsin{1}.num_args_out = 1;
sparam.num_args_out = 1;
sparam.cpu_time = 100;
sparam.mem = 1000e6;
sparam.notes = '';
sparam.file_success = {};

% end

%% layer_tracker: Loop to create tasks
% -------------------------------------------------------------------------
img_dir = '/cresis/snfs1/scratch/anjali/cluster_tuning/';
img_dir_combine = sprintf('%s%s/',img_dir,param.tmp_name);
img_dir = sprintf('%s%s',img_dir_combine,param.day_seg);
if ~exist(img_dir,'dir')
  mkdir(img_dir);
end
img_fn_dir{end+1} = img_dir;
dparam.argsin{1}.fname = img_dir;
dparam.argsin{1}.img_dir_combine = img_dir_combine;
dparam.argsin{1}.param_idx = param_idx;
dparam.argsin{1}.season_idx = 1;
dparam.num_args_out = 1;
sparam.file_success{end+1} = img_dir;
mem_combine = 0;
cputime_combine = 0;
frm_idx = 1;
idx = 1;
    
    % CPU time and memory
    % ---------------------------------------------------------------------
%     dparam.cpu_time = sum(cpu_time_mult(tracks_in_task)) * Nx * Nt;
%     dparam.mem = 800e6 + max(mem_mult(tracks_in_task)) * Nx * Nt;
%     if strcmp(track.init.method,'dem')
%       % Add extra time and memory for DEM
%       dparam.cpu_time = dparam.cpu_time + 120;
%       dparam.mem = dparam.mem + 2e9;
%     end
%     mem_combine = mem_combine + 256*Nx*length(tracks_in_task);
%     cputime_combine = cputime_combine + 1e-2*Nx*length(tracks_in_task);
    
    % Notes
    % ---------------------------------------------------------------------
    
    % Create task
    % ---------------------------------------------------------------------
    ctrl = cluster_new_task(ctrl,sparam,dparam,'dparam_save',0);
    ctrl = cluster_save_dparam(ctrl);
    ctrl_chain{end+1} = {ctrl};
    fprintf('Done %s\n',datestr(now));
    % ctrl_chain = {{ctrl}};
  end
end
cluster_print_chain(ctrl_chain);
[chain_fn,chain_id] = cluster_save_chain(ctrl_chain);

ctrl_chain = {};
%cluster_compile({'layer_tracker_generate_combine_task'},ctrl.cluster.hidden_depend_funs,ctrl.cluster.force_compile,ctrl);

% ctrl = cluster_save_dparam(ctrl);
% ctrl_chain{end+1} = ctrl;
% fprintf('Done %s\n',datestr(now));
% ctrl_chain = {{ctrl}};
ctrl = cluster_new_batch(param);

sparam = [];
sparam.argsin{1} = param;
sparam.task_function = 'layer_tracker_generate_combine_task';
sparam.num_args_out = 1;
sparam.file_success = {};

sparam.file_success{end+1} = img_dir;

sparam.cpu_time = 500;
sparam.mem = 500e6;
sparam.notes = '';

out_fn_dir = ct_filename_out(param,'',param.layer_tracker.layer_params.layerdata_source); %/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_layer_tune_vit_seg4_NC/20140313_09
%save_name = [];
save_names = {};
save_names{1,1} = '/cresis/snfs1/scratch/anjali/cluster_tuning/layer_tune_lsm_4seg_t001/20140313_09/result.mat';
save_names{2,1} = '/cresis/snfs1/scratch/anjali/cluster_tuning/layer_tune_lsm_4seg_t001/20140313_09/result.mat';

for i = 2:4
  for layer_idx = 1:length(gt_layer_params)
    %save_name.(sprintf('layer_%03d_%s',layer_idx,all_params{i})) = sprintf('%s/result_layer_%03d.mat',img_fn_dir{i},layer_idx);
    save_names{layer_idx,i} = sprintf('%s/result.mat',img_fn_dir{i-1});
  end
end
%sparam.argsin{1}.save_name = save_name;
sparam.argsin{1}.save_names = save_names;


ctrl = cluster_new_task(ctrl,sparam,[]);
ctrl_chain{end+1} = {ctrl};
fprintf('Done %s\n',datestr(now));


cluster_print_chain(ctrl_chain);
[chain_fn,chain_id] = cluster_save_chain(ctrl_chain);

% %% layer_tracker_combine
% % =========================================================================
% % =========================================================================
% ctrl = cluster_new_batch(param);
% 
% sparam = [];
% sparam.argsin{1} = param;
% sparam.task_function = 'layer_tracker_combine_task';
% sparam.num_args_out = 1;
% 
% records_fn = ct_filename_support(param,'','records');
% file_info = dir(records_fn);
% sparam.cpu_time = 30 + cputime_combine;
% sparam.mem = 500e6 + 1.5*mem_combine + 1.5*file_info.bytes;
% sparam.notes = '';
% 
% if strcmp(param.layer_tracker.layer_params.source,'ops')
%   sparam.file_success = {};
% else
%   sparam.file_success = {};
%   out_fn_dir = ct_filename_out(param,'',param.layer_tracker.layer_params.layerdata_source); %/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_layer_tune_vit_seg4_NC/20140313_09
%   for frm = param.cmd.frms
%     out_fn = fullfile(out_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm)); %/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_layer_tune_vit_seg4_NC/20140313_09/Data_20140313_09_001.mat
%     sparam.file_success{end+1} = out_fn;
%   end
% end
% 
% ctrl = cluster_new_task(ctrl,sparam,[]);
% ctrl_chain{end+1} = ctrl;
% fprintf('Done %s\n',datestr(now));