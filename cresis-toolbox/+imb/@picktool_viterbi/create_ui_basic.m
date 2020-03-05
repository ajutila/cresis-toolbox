function create_ui_basic(obj,xpos,ypos)

% create_ui_basic(obj,xpos,ypos)
%
% Creates components for the HMM param window's UI when the Viterbi
% tool is selected. Plots the window at xpos,ypos.
%

set(obj.h_fig,'visible','off');

% set default position (changed when window accessed)
set(obj.h_fig,'Units','Pixels');
set(obj.h_fig,'Position',[xpos ypos obj.w obj.h]);
% show top panel 
% set(obj.top_panel.handle,'visible','on');
% set(obj.bottom_panel.handle,'visible','off');

if ~obj.first_time
  figure(obj.h_fig);
  clf;
  obj.table = [];
end

%==========================================================================
% top panel
obj.top_panel.handle = uipanel('Parent',obj.h_fig);
set(obj.top_panel.handle,'HighlightColor',[0.8 0.8 0.8]);
set(obj.top_panel.handle,'ShadowColor',[0.6 0.6 0.6]);
%set(obj.top_panel.handle,'visible','off');

%--------------------------------------
% table
obj.table.ui=obj.h_fig;

obj.table.handles{1,1}        = obj.top_panel.handle;
obj.table.width(1,1)          = inf;
obj.table.height(1,1)         = inf;
obj.table.width_margin(1,1)   = 0;
obj.table.height_margin(1,1)  = 0;

table_draw(obj.table);

%============================================================================================
% top panel table contents

%----Mode dropdown
tooltip = 'Switch Viterbi functionality';
obj.top_panel.tool_PM = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.tool_PM,'Style','popupmenu');
set(obj.top_panel.tool_PM,'String',{'basic'});
set(obj.top_panel.tool_PM,'Value',1)
set(obj.top_panel.tool_PM,'Callback',@obj.toolPM_callback);
set(obj.top_panel.tool_PM,'TooltipString', tooltip);
%-----mode label
obj.top_panel.mode_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mode_label,'Style','text');
set(obj.top_panel.mode_label,'String','Mode');
set(obj.top_panel.mode_label,'TooltipString', tooltip);

%----insert range
tooltip = 'Viterbi will search +/- this many bins for the peak intensity on insert';
obj.top_panel.insert_range_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.insert_range_label,'Style','text');
set(obj.top_panel.insert_range_label,'String','Max point range:');
set(obj.top_panel.insert_range_label,'TooltipString', tooltip);
%----insert pt search range box
obj.top_panel.insert_range_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.insert_range_TE,'Style','edit');
set(obj.top_panel.insert_range_TE,'String',obj.in_rng_sv);
set(obj.top_panel.insert_range_TE,'TooltipString', tooltip);

%----column restriction label
tooltip = 'Crop echogram input to values between extreme ground truth points';
obj.top_panel.column_restriction_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.column_restriction_label,'Style','text');
set(obj.top_panel.column_restriction_label,'String','Column tracking restriction:');
set(obj.top_panel.column_restriction_label,'TooltipString', tooltip);
%----column restriction cbox
obj.top_panel.column_restriction_cbox = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.column_restriction_cbox,'Style','checkbox');
set(obj.top_panel.column_restriction_cbox,'Value', 1);
set(obj.top_panel.column_restriction_cbox,'TooltipString', tooltip);

%----top suppression label
tooltip = 'Prevent Viterbi from tracking the surface layer';
obj.top_panel.top_sup_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.top_sup_label,'Style','text');
set(obj.top_panel.top_sup_label,'String',sprintf('Top\nsuppression:'));
set(obj.top_panel.top_sup_label,'TooltipString', tooltip);
%----top suppression cbox
obj.top_panel.top_sup_cbox = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.top_sup_cbox,'Style','checkbox');
set(obj.top_panel.top_sup_cbox,'Value', 1);
set(obj.top_panel.top_sup_cbox,'TooltipString', tooltip);

%----multiple suppression label
tooltip = 'Prevent Viterbi from tracking surface multiples';
obj.top_panel.mult_sup_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_sup_label,'Style','text');
set(obj.top_panel.mult_sup_label,'String','Multiple suppression:');
set(obj.top_panel.mult_sup_label,'TooltipString', tooltip);
%----multiple suppression cbox
obj.top_panel.mult_sup_cbox = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_sup_cbox,'Style','checkbox');
set(obj.top_panel.mult_sup_cbox,'Value', 1);
set(obj.top_panel.mult_sup_cbox,'TooltipString', tooltip);

%----surface weight label
tooltip = 'Amount by which to repel surface if suppression enabled';
obj.top_panel.surf_weight_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.surf_weight_label,'Style','text');
set(obj.top_panel.surf_weight_label,'String','Surface Weight:');
set(obj.top_panel.surf_weight_label,'TooltipString', tooltip);
%----surface weight box
obj.top_panel.surf_weight_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.surf_weight_TE,'Style','edit');
set(obj.top_panel.surf_weight_TE,'String', obj.surf_weight);
set(obj.top_panel.surf_weight_TE,'TooltipString', tooltip);

%----multiple weight label
tooltip = 'Amount by which to repel surface multiples if suppression enabled';
obj.top_panel.mult_weight_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_label,'Style','text');
set(obj.top_panel.mult_weight_label,'String','Multiple Weight:');
set(obj.top_panel.mult_weight_label,'TooltipString', tooltip);
%----multiple weight box
obj.top_panel.mult_weight_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_TE,'Style','edit');
set(obj.top_panel.mult_weight_TE,'String', obj.mult_weight);
set(obj.top_panel.mult_weight_TE,'TooltipString', tooltip);

%----multiple weight decay label
tooltip = 'Multiply weight of each subsequent multiple by this amount to reduce suppression of faded multiples';
obj.top_panel.mult_weight_decay_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_decay_label,'Style','text');
set(obj.top_panel.mult_weight_decay_label,'String','Multiple Weight Decay:');
set(obj.top_panel.mult_weight_decay_label,'TooltipString', tooltip);
%----multiple weight decay box
obj.top_panel.mult_weight_decay_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_decay_TE,'Style','edit');
set(obj.top_panel.mult_weight_decay_TE,'String', obj.mult_weight_decay);
set(obj.top_panel.mult_weight_decay_TE,'TooltipString', tooltip);

%----multiple weight local decay label
tooltip = 'Multiply the multiple suppression weight by this amount for every subsequent bin past the multiple';
obj.top_panel.mult_weight_local_decay_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_local_decay_label,'Style','text');
set(obj.top_panel.mult_weight_local_decay_label,'String','Multiple Weight Local Decay:');
set(obj.top_panel.mult_weight_local_decay_label,'TooltipString', tooltip);
%----multiple weight local decay box
obj.top_panel.mult_weight_local_decay_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.mult_weight_local_decay_TE,'Style','edit');
set(obj.top_panel.mult_weight_local_decay_TE,'String', obj.mult_weight_local_decay);
set(obj.top_panel.mult_weight_local_decay_TE,'TooltipString', tooltip);

%----surface slope label
tooltip = 'Use the slope of the surface layer as the expected slope of the target layer';
obj.top_panel.surf_slope_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.surf_slope_label,'Style','text');
set(obj.top_panel.surf_slope_label,'String',sprintf('Calc slope from surf:'));
set(obj.top_panel.surf_slope_label,'TooltipString', tooltip);
%----surface slope cbox
obj.top_panel.surf_slope_cbox = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.surf_slope_cbox,'Style','checkbox');
set(obj.top_panel.surf_slope_cbox,'Value', 1);
set(obj.top_panel.surf_slope_cbox,'TooltipString', tooltip);

%----transition slope label
tooltip = 'The slope of the target layer if surface slope is disabled. Slope generally occurs due to the plane changing altitude. 0 for no constant slope.';
obj.top_panel.transition_slope_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.transition_slope_label,'Style','text');
set(obj.top_panel.transition_slope_label,'String','Transition Slope:');
set(obj.top_panel.transition_slope_label,'TooltipString', tooltip);
%----transition slope box
obj.top_panel.transition_slope_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.transition_slope_TE,'Style','edit');
set(obj.top_panel.transition_slope_TE,'String', obj.transition_slope);
set(obj.top_panel.transition_slope_TE,'TooltipString', tooltip);

%----max slope label
tooltip = 'The maximum allowed slope of the target layer. -1 for no max.';
obj.top_panel.max_slope_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.max_slope_label,'Style','text');
set(obj.top_panel.max_slope_label,'String','Max Slope:');
set(obj.top_panel.max_slope_label,'TooltipString', tooltip);
%----max slope box
obj.top_panel.max_slope_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.max_slope_TE,'Style','edit');
set(obj.top_panel.max_slope_TE,'String', obj.max_slope);
set(obj.top_panel.max_slope_TE,'TooltipString', tooltip);

%----transition weight label
tooltip = 'The weight by which to multiply the binary cost. Greater weight = prefer less slope';
obj.top_panel.transition_weight_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.transition_weight_label,'Style','text');
set(obj.top_panel.transition_weight_label,'String','Transition weight:');
set(obj.top_panel.transition_weight_label,'TooltipString', tooltip);
%----transition weight box
obj.top_panel.transition_weight_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.transition_weight_TE,'Style','edit');
set(obj.top_panel.transition_weight_TE,'String', obj.transition_weight);
set(obj.top_panel.transition_weight_TE,'TooltipString', tooltip);

%----image magnitude weight label
tooltip = 'The weight by which to multiply the image magnitude cost. Greater weight = prefer greater image magnitude';
obj.top_panel.image_mag_weight_label = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.image_mag_weight_label,'Style','text');
set(obj.top_panel.image_mag_weight_label,'String','Image Magnitude Weight:');
set(obj.top_panel.image_mag_weight_label,'TooltipString', tooltip);
%----image magnitude weight box
obj.top_panel.image_mag_weight_TE = uicontrol('Parent',obj.top_panel.handle);
set(obj.top_panel.image_mag_weight_TE,'Style','edit');
set(obj.top_panel.image_mag_weight_TE,'String', obj.image_mag_weight);
set(obj.top_panel.image_mag_weight_TE,'TooltipString', tooltip);
%%
%---------------------------------------------------------------------------------------------
rows = 14;  % Update with number of rows and columns
cols = 2;
% set up top panel table
default_dimensions = NaN*zeros(rows,cols);
obj.top_panel.table.ui=obj.top_panel.handle;
obj.top_panel.table.width_margin = default_dimensions;
obj.top_panel.table.height_margin = default_dimensions;
obj.top_panel.table.false_width = default_dimensions;
obj.top_panel.table.false_height = default_dimensions;
obj.top_panel.table.offset = [0 0];

obj.top_panel.table.width = ones(rows, cols) * inf;
obj.top_panel.table.height = ones(rows, cols) * inf;
obj.top_panel.table.width_margin = ones(rows, cols) * 1.5;
obj.top_panel.table.height_margin = ones(rows, cols) * 1.5;

%% Mode
obj.top_panel.table.handles{1,1}   = obj.top_panel.mode_label;
obj.top_panel.table.handles{1,2}   = obj.top_panel.tool_PM;
%% Insert Range
obj.top_panel.table.handles{2,1}   = obj.top_panel.insert_range_label;
obj.top_panel.table.handles{2,2}   = obj.top_panel.insert_range_TE;
%% Column restriction
obj.top_panel.table.handles{3,1}   = obj.top_panel.column_restriction_label;
obj.top_panel.table.handles{3,2}   = obj.top_panel.column_restriction_cbox;
%% Top suppression
obj.top_panel.table.handles{4,1}   = obj.top_panel.top_sup_label;
obj.top_panel.table.handles{4,2}   = obj.top_panel.top_sup_cbox;
%% Multiple suppression
obj.top_panel.table.handles{5,1}   = obj.top_panel.mult_sup_label;
obj.top_panel.table.handles{5,2}   = obj.top_panel.mult_sup_cbox;
%% Surface Weight
obj.top_panel.table.handles{6,1}   = obj.top_panel.surf_weight_label;
obj.top_panel.table.handles{6,2}   = obj.top_panel.surf_weight_TE;
%% Multiple Weight
obj.top_panel.table.handles{7,1}   = obj.top_panel.mult_weight_label;
obj.top_panel.table.handles{7,2}   = obj.top_panel.mult_weight_TE;
%% Multiple Weight Decay
obj.top_panel.table.handles{8,1}   = obj.top_panel.mult_weight_decay_label;
obj.top_panel.table.handles{8,2}   = obj.top_panel.mult_weight_decay_TE;
%% Multiple Weight Local Decay 
obj.top_panel.table.handles{9,1}   = obj.top_panel.mult_weight_local_decay_label;
obj.top_panel.table.handles{9,2}   = obj.top_panel.mult_weight_local_decay_TE;
%% Transition Slope from Surface
obj.top_panel.table.handles{10,1}   = obj.top_panel.surf_slope_label;
obj.top_panel.table.handles{10,2}   = obj.top_panel.surf_slope_cbox;
%% Transition Slope 
obj.top_panel.table.handles{11,1}  = obj.top_panel.transition_slope_label;
obj.top_panel.table.handles{11,2}  = obj.top_panel.transition_slope_TE;
%% Max Slope 
obj.top_panel.table.handles{12,1}  = obj.top_panel.max_slope_label;
obj.top_panel.table.handles{12,2}  = obj.top_panel.max_slope_TE;
%% Transition Weight
obj.top_panel.table.handles{13,1}  = obj.top_panel.transition_weight_label;
obj.top_panel.table.handles{13,2}  = obj.top_panel.transition_weight_TE;
%% Image magnitude weight
obj.top_panel.table.handles{14,1}  = obj.top_panel.image_mag_weight_label;
obj.top_panel.table.handles{14,2}  = obj.top_panel.image_mag_weight_TE;
clear rows cols

% Draw table
table_draw(obj.top_panel.table);

if obj.first_time
  obj.first_time = false;
else
  set(obj.h_fig,'visible','on');
end

return;