function data = echo_detrend(mdata, param)
% data = echo_detrend(mdata, param)
%
% The trend of the data is estimated using various methods and this trend
% is removed from the data.
%
% INPUTS:
%
% data = 2D input data matrix (log power)
%
% param: struct controlling how the detrending is done
%  .units: units of the data, string containing 'l' (linear power) or 'd' (dB
%  log power)
%
%  .method: string indicating the method. The methods each have their own
%  parameters
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
%   'polynomial': polynomial fit to data between two layers, outside of the
%   region between the two layers uses nearest neighborhood interpolation
%     .layer_bottom: bottom layer
%     .layer_top: top layer
%     .order: nonnegative integer scalar indicating polynomial order
%
%   'tonemap': uses Matlab's tonemap command
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
% Author: John Paden

if isstruct(mdata)
  data = mdata.Data;
else
  data = mdata;
end

if ~exist('param','var') || isempty(param)
  param = [];
end

if ~isfield(param,'method') || isempty(param.method)
  param.method = 'mean';
end

switch param.method
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
    if ~isfield(param,'order') || isempty(param.order)
      param.order = 2;
    end
    if all(isnan(param.layer_bottom))
      param.layer_bottom(:) = Nt;
    elseif any(param.layer_bottom<1)
      % layer is two way travel time
      if isstruct(mdata)
        param.layer_bottom = round(interp_finite(interp1(mdata.Time,1:length(mdata.Time),param.layer_bottom,'linear','extrap'),Nt));
      end
    end
    if all(isnan(param.layer_top))
      param.layer_top(:) = 1;
    elseif any(param.layer_top<1)
      % layer is two way travel time
      if isstruct(mdata)
        param.layer_top = round(interp_finite(interp1(mdata.Time,1:length(mdata.Time),param.layer_top,'linear','extrap'),1));
      end
    end
    
    mask = false(size(data));
    x_axis = nan(size(data));
    for rline = 1:Nx
      bins = max(1,min(Nt,param.layer_top(rline))):max(1,min(Nt,param.layer_bottom(rline)));
      mask(bins,rline) = true;
      if param.layer_bottom(rline) - param.layer_top(rline) > 0
        x_axis(bins,rline) = (bins - param.layer_top(rline)) / (param.layer_bottom(rline) - param.layer_top(rline));
      else
        x_axis(bins,rline) = 0;
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
      bins = max(1,min(Nt,param.layer_top(rline))):max(1,min(Nt,param.layer_bottom(rline)));
      trend(bins) = polyval(detrend_poly,x_axis(bins,rline));
      
      % Section 1: Constant
      trend(1:bins(1)-1) = trend(bins(1));
      
      % Section 3: Constant
      trend(bins(end):end) = trend(bins(end));
      
      if 0
        %% Debug plots
        figure(1); clf;
        plot(data(:,rline));
        hold on;
        plot(trend);
      end
      data(:,rline) = data(:,rline) - trend;
    end
    
  case 'tonemap'
    tmp = [];
    tmp(:,:,1) = abs(data);
    tmp(:,:,2) = abs(data);
    tmp(:,:,3) = abs(data);
    % for generating synthetic HDR images
    data = tonemap(tmp, 'AdjustLightness', [0.1 1], 'AdjustSaturation', 1.5);
    data = single(data(:,:,2));
   
  otherwise
    error('Invalid param.method %s.', param.method);
end
