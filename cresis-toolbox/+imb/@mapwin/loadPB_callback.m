function loadPB_callback(obj,hObj,event)
% mapwin.loadPB_callback(obj,hObj,event)
%
% "load" pushbutton callback which loads new echo windows, called when user
% presses load button or double clicks a frame. Loads the "obj.map.sel"
% frame.

%% Setup

% Check to make sure a frame has been selected before we load
if isempty(obj.map.sel.frm_str)
  uiwait(msgbox('No frame selected, select frames with ctrl+left-click or using search','Error loading','modal'));
  return;
end

if strcmpi(obj.cur_map_pref_settings.layer_source,'ops')
  % Check to make sure the standard:surface layer is selected before we load
  found_surface = false;
  for idx=1:length(obj.cur_map_pref_settings.layers.lyr_name)
    if strcmp(obj.cur_map_pref_settings.layers.lyr_name{idx},'surface') ...
        && strcmp(obj.cur_map_pref_settings.layers.lyr_group_name{idx},'standard')
      found_surface = true;
    end
  end
  if ~found_surface
    uiwait(msgbox('standard:surface layer must be selected in mapwin prefs','Error loading','modal'));
    return;
  end
end

% Change the pointer to a watch
set(obj.h_fig,'Pointer','watch');
drawnow;

%% Get the echowin that the current frame will be loaded into
idx = get(obj.top_panel.picker_windowPM,'Value');
if idx > 1
  %% Loading into a pre-existing window
  echo_idx = idx-1;
  exists_flag = true;
  cancel_operation = obj.echowin_list(echo_idx).undo_stack_modified_check();
  if cancel_operation
    set(obj.h_fig,'Pointer','Arrow');
    return;
  end
  obj.echowin_list(echo_idx).cmds_set_undo_stack([]);
else
  %% Loading into a new window, Create a new echowin class
  % Get the index for this new echowin
  echo_idx = length(obj.echowin_list) + 1;
  exists_flag = false;
  new_echowin = imb.echowin([],obj.default_params.echowin);
  
  % Add the new class instance to the echowin_list
  obj.echowin_list(echo_idx) = new_echowin;
  
  % Add a new entry in the picker window popup menu and set the active
  % entry to this new entry
  menu_string = get(obj.top_panel.picker_windowPM,'String');
  if strcmpi(class(obj.echowin_list(echo_idx).h_fig),'double')
    menu_string{end+1} = sprintf('%d: Echo',obj.echowin_list(echo_idx).h_fig);
  else
    menu_string{end+1} = sprintf('%d: Echo',obj.echowin_list(echo_idx).h_fig.Number);
  end
  set(obj.top_panel.picker_windowPM,'String',menu_string);
  set(obj.top_panel.picker_windowPM,'Value',echo_idx+1);
  
  % Set up the listeners
  addlistener(obj.echowin_list(echo_idx),'close_window',@obj.close_echowin);
  addlistener(obj.echowin_list(echo_idx),'update_echowin_flightline',@obj.update_echowin_flightlines);
  addlistener(obj.echowin_list(echo_idx),'update_cursors',@obj.update_echowin_cursors);
  addlistener(obj.echowin_list(echo_idx),'update_map_selection',@obj.update_map_selection_echowin);
  addlistener(obj.echowin_list(echo_idx),'open_crossover_event',@obj.open_crossover_echowin);
  
  % Create a selection plot that identifies the echowin on the map
  obj.echowin_maps(echo_idx).h_cursor = plot(obj.map_panel.h_axes, [NaN],[NaN],'kx','LineWidth',2,'MarkerSize',10);
  obj.echowin_maps(echo_idx).h_line = plot(obj.map_panel.h_axes, [NaN],[NaN],'g.');
  obj.echowin_maps(echo_idx).h_text = text(0, 0, '', 'parent', obj.map_panel.h_axes);
end

%  Draw the echo class in the selected echowin
param.sources = obj.cur_map_pref_settings.sources;
param.layers = obj.cur_map_pref_settings.layers;
param.cur_sel = obj.map.sel;
param.cur_sel.frm = str2num(param.cur_sel.frm_str(13:end));
param.cur_sel.location = obj.cur_map_pref_settings.map_zone;
param.cur_sel.day_seg = param.cur_sel.frm_str(1:11);
if strcmp(obj.cur_map_pref_settings.system,'layerdata')
  param.segment_id = obj.map.sel.seg_id;
  param.system = param.cur_sel.radar_name;
  param.cur_sel.radar_name = param.cur_sel.radar_name;
  param.cur_sel.season_name = param.cur_sel.season_name;
  % Layerdata includes system and season because segment IDs are only
  % unique for a particular system_season pair
  system_name_full = [param.system '_' param.cur_sel.season_name];
else
  param.system = obj.cur_map_pref_settings.system;
  param.cur_sel.radar_name = obj.cur_map_pref_settings.system;
  % OPS includes only the system because segment IDs are unique for each
  % system
  system_name_full = obj.cur_map_pref_settings.system;
end
param.layer_source = obj.cur_map_pref_settings.layer_source;
param.layer_data_source = obj.cur_map_pref_settings.layer_data_source;

%-------------------------------------------------------------------------
%% Create link between the echowin and undo_stack list

% Look through the unique identifiers in the undo stack document list to
% see if an undo stack already exists for this echowin's system-segment
% combination
match_idx = [];
for stack_idx = 1:length(obj.undo_stack_list)
  if strcmpi(obj.undo_stack_list(stack_idx).unique_id{1},system_name_full) ...
      && obj.undo_stack_list(stack_idx).unique_id{2} == obj.map.sel.seg_id
    % An undo stack already exists for this system-segment pair
    match_idx = stack_idx;
    break;
  end
end

%% LayerData: Load layerdata into undostack
layer_info = [];
param.frame = [];
param.gps_time = [];
param.twtt = [];
param.frame_idxes = [];
param.filename = [];
param.map = obj.map;
if strcmpi(param.layer_source,'layerdata')
  % Find this season in the list of seasons
  season_idx = find(strcmp(system_name_full,obj.cur_map_pref_settings.seasons));
  % Create a mask that identifies the frames for the selected segment in this season
  frm_idxs = find(param.cur_sel.seg_id == floor(obj.layerdata.frm_info(season_idx).frm_id/1000));
  num_frm = length(frm_idxs);

  layer_names = {};
  for frm = 1:num_frm
    layer_fn=fullfile(ct_filename_out(param.cur_sel,param.layer_data_source,''),sprintf('Data_%s_%03d.mat',param.cur_sel.day_seg,frm));
    lay = load(layer_fn);
    for lay_idx = 1:length(lay.layerData)
      if ~isfield(lay.layerData{lay_idx},'name')
        if lay_idx == 1
          lay.layerData{lay_idx}.name = 'surface';
        elseif lay_idx == 2
          lay.layerData{lay_idx}.name = 'bottom';
        else
          error('layerData files with unnamed layers for layers 3 and greater are not supported. Layer %d does not have a .name field.', lay_idx);
        end
      end
      if ~any(strcmp(lay.layerData{lay_idx}.name,layer_names))
        layer_names{end+1} = lay.layerData{lay_idx}.name;
      end
    end
    param.filename{frm} = layer_fn; % stores the filename for all frames in the segment
    layer_info = cat(2, layer_info,lay); % stores the layer information for all frames in the segment
    param.gps_time = cat(2,param.gps_time,lay.GPS_time); % stores the GPS time for all the frames in the segment
    param.frame = cat(2, param.frame, frm*ones(size(lay.GPS_time))); % stores the frame number for each point path id in each frame
    param.frame_idxes = cat(2,param.frame_idxes,1:length(lay.GPS_time));  % contains the point number for each individual point in each frame
  end
  
  % Populate layers
  param.layers.lyr_id = 1:length(layer_names);
  param.layers.lyr_name = layer_names;
  param.layers.lyr_group_name = cell(size(param.layers.lyr_name));
  param.layers.surf_id = 1;
  
  % Force all layerData files to use the same layer sequence: this ensures
  % that all layerData files have the same layers and these layers are in
  % the same order.
  for frm = 1:num_frm
    % Does frame conform to lyr_name list?
    conforms = true;
    for lay_idx = 1:length(param.layers.lyr_name)
      if lay_idx > length(layer_info(frm).layerData) ...
          || ~strcmpi(param.layers.lyr_name{lay_idx},layer_info(frm).layerData{lay_idx}.name)
        conforms = false;
      end
    end
    if ~conforms
      new_layerData = cell(1,length(param.layers.lyr_name));
      file_layer_names = cellfun(@(x) getfield(x,'name'),layer_info(frm).layerData,'UniformOutput',false);
      for lay_idx = 1:length(param.layers.lyr_name)
        layer_name = param.layers.lyr_name{lay_idx};
        new_layerData{lay_idx}.name = layer_name;
        match_idx = find(strcmp(layer_name,file_layer_names),1);
        if isempty(match_idx)
          new_layerData{lay_idx}.value{1}.data = NaN(size(layer_info(frm).GPS_time));
          new_layerData{lay_idx}.value{2}.data = NaN(size(layer_info(frm).GPS_time));
          new_layerData{lay_idx}.quality = ones(size(layer_info(frm).GPS_time));
        else
          new_layerData{lay_idx}.value{1}.data = layer_info(frm).layerData{match_idx}.value{1}.data;
          new_layerData{lay_idx}.value{2}.data = layer_info(frm).layerData{match_idx}.value{2}.data;
          new_layerData{lay_idx}.quality = layer_info(frm).layerData{match_idx}.quality;
        end
      end
      layer_info(frm).layerData = new_layerData;
    end
  end
  
  param.start_gps_time = obj.layerdata.frm_info(season_idx).start_gps_time(frm_idxs);
  param.stop_gps_time = obj.layerdata.frm_info(season_idx).stop_gps_time(frm_idxs);
end

if isempty(match_idx)
  % An undo stack does not exist for this system-segment pair, so create a
  % new undo stack
  param.id = {system_name_full obj.map.sel.seg_id};
  obj.undo_stack_list(end+1) = imb.undo_stack(param);
  match_idx = length(obj.undo_stack_list);
end

% Attach echowin to the undo stack
obj.echowin_list(echo_idx).cmds_set_undo_stack(obj.undo_stack_list(match_idx));
obj.undo_stack_list(match_idx).user_data.layer_info=layer_info; % contains the layer information
obj.undo_stack_list(match_idx).user_data.frame = param.frame; % contains the frame number for each point path id
obj.undo_stack_list(match_idx).user_data.layer_source = param.layer_source; % contains the layer source
obj.undo_stack_list(match_idx).user_data.layer_data_source = param.layer_data_source; % contains the layerData source
obj.undo_stack_list(match_idx).user_data.gps_time=param.gps_time; % contains the GPS time
obj.undo_stack_list(match_idx).user_data.frame_idxs = param.frame_idxes; % contains the point number for each individual point in each frame
obj.undo_stack_list(match_idx).user_data.filename = param.filename; % contains the filenames

%%
try
  obj.echowin_list(echo_idx).draw(param);
catch ME
  % Draw failed... close echo window and report error
  obj.close_echowin(obj.echowin_list(echo_idx));
  set(obj.h_fig,'Pointer','Arrow');
  rethrow(ME);
end

%% Cleanup
set(obj.h_fig,'Pointer','Arrow');
