function data = echo_detrend(mdata, param)
% data = echo_detrend(mdata, param)
%
% The trend of the data is estimated using various methods and this trend
% is removed from the data.
%
% INPUTS:
%
% mdata: 2D input data matrix (log power) or echogram structure with "Data"
%   field. "Time" and "Roll" may also be used depending on param settings.
%
% param: struct controlling how the detrending is done
%  .units: units of the data, string containing 'l' (linear power) or 'd' (dB
%  log power)
%
%  .method: string indicating the method. The methods each have their own
%  parameters
%
%   'file': NOT SUPPORTED
%
%   'local': takes a local mean to determine the trend
%     .filt_len: 2 element vector of positive integers indicating the size of
%     the trend estimation filter where the first element is the boxcar
%     filter length in fast-time (row) and the second element is the boxcar
%     filter length in slow-time (columns). Elements must be odd since
%     fir_dec used. Elements can be greater than the corresponding
%     dimensions Nt or Nx in which case an ordinary mean is used in that
%     dimension.
%
%   'mean': takes the mean in the along-track and averages this in the
%   cross-track. This is the default method.
%
%   'polynomial': polynomial fit to mean power of data between two layers,
%   outside of the region between the two layers, the trend is found using
%   nearest neighborhood interpolation to this polynomial clipped to the
%   two layers.
%
%     .layer_bottom: 1 by Nx vector of bottom layer twtt or range bins (see
%     "units" field)
%
%     .layer_top: 1 by Nx vector of top layer twtt or range bins (see
%     "units" field)
%
%     .order: nonnegative integer scalar indicating polynomial order.
%     Default is 7
%     .units: scalar char, either "s" for seconds or "b" for bins. If
%     any(layer_bottom < 1) then "s" is default, otherwise "b". The same
%     check is done for layer_top.
%
%   'tonemap': uses Matlab's tonemap command
%
%  .roll_comp_en: logical scalar, enables
%
%  .roll_comp_data: structure loaded from roll compensation file generated
%  by FILLTHISIN.m. Should have two fields:
%
%    .all_roll: roll axis vector

%    .all_pwr: power axis vector correspondign to all_roll vector
%
% OUTPUTS:
%
% data: detrended input (log power)
%
% Examples:
%
% fn = '/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_standard/20140512_01/Data_20140512_01_018.mat';
% mdata = load(fn); mdata.Data = 10*log10(mdata.Data);
%
% imagesc(echo_detrend(mdata));
%
% [surface,bottom] = layerdata.load_layers(mdata,'','surface','bottom');
% imagesc(echo_detrend(mdata, struct('method','polynomial','layer_top',surface,'layer_bottom',bottom)));
%
% imagesc(echo_detrend(mdata, struct('method','tonemap')));
%
% imagesc(echo_detrend(mdata, struct('method','local','filt_len',[51 101])));
%
% param = struct('method','polynomial','roll_comp_en',true);
% param.roll_comp_data = load('/cresis/snfs1/scratch/ibikunle/ct_user_tmp/roll_compensation.mat');
% [param.layer_top,param.layer_bottom] = layerdata.load_layers(mdata,'','surface','bottom');
% imagesc(echo_detrend(mdata, param));
%
% Author: John Paden
%
% See also: echo_detrend, echo_filt, echo_mult_suppress, echo_noise,
% echo_norm, echo_param, echo_stats, echo_stats_layer, echo_xcorr,
% echo_xcorr_profile

if ~exist('param','var') || isempty(param)
  param = [];
end

if ~isfield(param,'method') || isempty(param.method)
  param.method = 'mean';
end

if ~isfield(param,'roll_comp_en') || isempty(param.roll_comp_en)
  param.roll_comp_en = false;
end

if ~isfield(param,'detrend_offset') || isempty(param.detrend_offset)
  param.detrend_offset = 0;
end

if isstruct(mdata)
  data = mdata.Data;
  if param.roll_comp_en && isfield(mdata,'Roll')
    roll = mdata.Roll;
  end
else
  data = mdata;
  if param.roll_comp_en
    roll = zeros(1,size(data,2));
  end
end

switch param.method
  case 'eval'
    time = mdata.Time; % Variable to be available to param.eval_cmd
    for rline = 1:size(data,2)
      surf = mdata.Surface(rline); % Variable to be available to param.eval_cmd
      data(:,rline) = data(:,rline) + eval(param.eval_cmd);
    end
    
  case 'file'
    error('Not supported yet...');
    % Load detrend file generated by run_echo_stats
    % e.g. ct_tmp/echogram_stats/snow/2011_Greenland_P3/stats_20110329_02.mat
    if isempty(track.detrend)
      track.detrend = [ct_filename_ct_tmp(param,'','echogram_stats','stats') '.mat'];
    end
    detrend = load(track.detrend,'dt','bins','min_means');
    detrend.time = detrend.dt*detrend.bins;
    
    track.detrend_struct = detrend;
    detrend_curve = interp_finite(interp1(detrend.time,interp_finite(detrend.min_means),mdata.Time),NaN);
    if all(isnan(detrend_curve))
      error('Detrend curve is all NaN.');
    end
    if 0
      % Debug
      rline = 200;
      figure(1); clf;
      plot(data(:,rline))
      hold on
      mean_power = nanmean(data,2);
      plot(mean_power)
      plot(detrend_curve);
      keyboard
    end
    data = bsxfun(@minus,data,detrend_curve);
    if track.data_noise_en
      data_noise = bsxfun(@minus,data_noise,detrend_curve);
    end
    
  case 'local'
    if ~isfield(param,'filt_len') || isempty(param.filt_len)
      param.filt_len = [21 51];
    end
    Nt = size(data,1);
    Nx = size(data,2);
    data = 10.^(data/10);
    if param.filt_len(1) < Nt
      trend = nan_fir_dec(data.',ones(1,param.filt_len(1))/param.filt_len(1),1).';
    else
      trend = repmat(nan_mean(data,1), [Nt 1]);
    end
    if param.filt_len(2) < Nx
      trend = nan_fir_dec(trend,ones(1,param.filt_len(2))/param.filt_len(2),1);
    else
      trend = repmat(nan_mean(trend,2), [Nx 1]);
    end
    data = 10*log10(data ./ trend);
    
  case 'mean'
    data = 10.^(data/10);
    data = 10*log10(bsxfun(@times,data,1./mean(data,2)));
    
  case 'polynomial'
    Nt = size(data,1);
    Nx = size(data,2);
    
    if param.roll_comp_en
      % Roll compensation data interpolated to specific roll values for
      % this echogram
      roll_comp = interp1(param.roll_comp_data.all_roll,param.roll_comp_data.all_pwr,roll);
    end
    
    if ~isfield(param,'order') || isempty(param.order)
      param.order = 7;
    end
    if all(isnan(param.layer_bottom))
      param.layer_bottom(:) = Nt;
    elseif any(param.layer_bottom < 1)
      % layer is two way travel time
      if isstruct(mdata)
        param.layer_bottom = round(interp_finite(interp1(mdata.Time,1:length(mdata.Time),param.layer_bottom,'linear','extrap'),Nt));
      else
        error('mdata should be an echogram struct with a "Time" field since layer_bottom is specific in two way travel time and needs to be converted to range bins.');
      end
    end
    if all(isnan(param.layer_top))
      param.layer_top(:) = 1;
    elseif any(param.layer_top < 1)
      % layer is two way travel time
      if isstruct(mdata)
        param.layer_top = round(interp_finite(interp1(mdata.Time,1:length(mdata.Time),param.layer_top,'linear','extrap'),1));
      else
        error('mdata should be an echogram struct with a "Time" field since layer_top is specific in two way travel time and needs to be converted to range bins.');
      end
    end
    
    mask = false(size(data));
    x_axis = nan(size(data));
    for rline = 1:Nx
      top_bin = param.layer_top(rline);
      bottom_bin = param.layer_bottom(rline);
      if top_bin < 1 && bottom_bin >= 1
        top_bin = 1;
      end
      if top_bin <= Nt && bottom_bin > Nt
        bottom_bin = Nt;
      end
      if top_bin > Nt || bottom_bin < 1
        continue;
      end
      bins = top_bin:bottom_bin;
      
      if length(bins) >= 2
        mask(bins,rline) = isfinite(data(bins,rline));
        x_axis(bins,rline) = (bins - param.layer_top(rline)) / (param.layer_bottom(rline) - param.layer_top(rline));
      end
    end
    
    % Find the polynomial coefficients
    detrend_poly = polyfit(x_axis(mask),data(mask), param.order);
    if sum(mask(:))-Nx < 3*param.order
      % Insufficient data to estimate polynomial
      return;
    end
    
    trend = zeros(Nt,1);
    for rline = 1:Nx
      % Section 2: Evaluate the polynomial
      top_bin = param.layer_top(rline);
      bottom_bin = param.layer_bottom(rline);
      if top_bin < 1 && bottom_bin >= 1
        top_bin = 1;
      end
      if top_bin <= Nt && bottom_bin > Nt
        bottom_bin = Nt;
      end
      
      if top_bin > Nt
        trend(:) = polyval(detrend_poly,0);
        [min_val,~] = min(trend);
        if param.roll_comp_en
          trend = trend - roll_comp(rline) ;
        end
        
      elseif bottom_bin < 1
        trend(:) = polyval(detrend_poly,1);
        [min_val,~] = min(trend);
        if param.roll_comp_en
          trend = trend - roll_comp(rline) ;
        end
        
      elseif top_bin >= bottom_bin
        trend(1:top_bin) = polyval(detrend_poly,0);
        trend(top_bin+1:end) = polyval(detrend_poly,1);
        [min_val,~] = min(trend (top_bin+1:end) );
        
        if param.roll_comp_en
          trend(top_bin+1:end) = trend(top_bin+1:end) - roll_comp(rline) ;
        end
        
      else
        bins = top_bin:bottom_bin;
        
        % Section 1: Polynomial fit
        trend(bins) = polyval(detrend_poly,x_axis(bins,rline));
        
        % Section 2: Constant above surface
        trend(1:bins(1)-1) = trend(bins(1));
        
        % Section 3: Constant below bottom
        [min_val,min_loc] = min(trend(bins));
        min_loc = min_loc + top_bin;
        
        trend(min_loc:end) = min(trend(bins));
        
        if param.roll_comp_en
          % Apply roll compensation
          trend(top_bin:min_loc) = trend(top_bin:min_loc) - roll_comp(rline);
        end
        
      end
      
      trend = trend - param.detrend_offset;
      trend(trend < min_val) = min_val;
      
      if 0
        %% Debug plots
        figure(1); clf;
        plot(data(:,rline));
        if param.roll_comp_en
          title(sprintf('Rangeline %d block %d, Roll= %.3f',rline,param.block,roll(rline) ),'Interpreter','none');
        else
          title(sprintf('Rangeline %d block %d',rline,param.block),'Interpreter','none');
        end
        hold on;
        plot(trend);
        hold on;  plot(data(:,rline) - trend);
        grid on; grid minor
        pause(0.5)
      end
      
      data(:,rline) = data(:,rline) - trend;
    end
    
  case 'tonemap'
    tmp = [];
    min_data = min(data(isfinite(data)));
    if isempty(min_data)
      % No finite data, so set min_data to 0
      min_data = 0;
    end
    tmp(:,:,1) = data - min_data;
    tmp(:,:,2) = data - min_data;
    tmp(:,:,3) = data - min_data;
    % for generating synthetic HDR images
    data = tonemap(tmp, 'AdjustLightness', [0.1 1], 'AdjustSaturation', 1.5);
    data = single(data(:,:,2));
    
  otherwise
    error('Invalid param.method %s.', param.method);
end
