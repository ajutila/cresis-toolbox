function [success] = analysis_task(param)
% [success] = analysis_task(param)
%
% https://ops.cresis.ku.edu/wiki/index.php/Analysis
%
% Author: John Paden

%% General Setup
% Load c=speed of light constant
physical_constants;

%% Load records file
% =========================================================================
records_fn = ct_filename_support(param,'','records');

% Adjust the load records to account for filtering and decimation. Care is
% taken to ensure that when blocks and frames are concatenated together,
% they are seamless (i.e. no discontinuities in the filtering and
% decimation at block and frame boundaries). Also, records before and after
% the desired output records are loaded when available to ensure filter inputs
% have full support when creating outputs. Since this is not possible
% at the the beginning and end of the segment, the filter coefficients are
% renormalized to account for the shorted support so that there is no roll
% off in signal power.

task_recs = param.load.recs; % Store this for later when creating output fn

% Translate the records to load into presummed record counts
%  *_ps: presummed record counts as opposed to raw record counts
load_recs_ps(1) = floor((param.load.recs(1)-1)/param.analysis.presums)+1;
load_recs_ps(2) = floor(param.load.recs(2)/param.analysis.presums);

records = read_records_aux_files(records_fn,param.load.recs);

% Store the parameters that were used to create the records file
param_records = records.param_records;

% Store the current GPS source
param_records.gps_source = records.gps_source;

% Get output directory, radar type, and base radar name
[output_dir,radar_type,radar_name] = ct_output_dir(param.radar_name);

%% Collect waveform information into one structure
% =========================================================================
[wfs,states] = data_load_wfs(param,records);
param.radar.wfs = merge_structs(param.radar.wfs,wfs);

%% Load and process each image separately
% =====================================================================
store_param = param;
for img = 1:length(param.load.imgs)
  
  %% Load data
  % =========================================================================
  param.load.raw_data = false;
  param.load.presums = param.analysis.presums;
  param.load.imgs = store_param.load.imgs(img);
  [hdr,raw_data] = data_load(param,records,wfs,states);
  
  for cmd_idx = 1:length(param.analysis.cmd)
    cmd = param.analysis.cmd{cmd_idx};
    if ~cmd.en
      continue;
    end
    
    if strcmpi(cmd.method,{'saturation'})
      %% Saturation
      % ===================================================================
      % ===================================================================
      
      max_val_gps_time = 1;
      if ~any(strcmpi(radar_name,{'kuband','kuband2','kuband3','kaband3','snow','snow2','snow3','snow5','snow8'}))
        if( ~isfield(cmd,'layer') && ~isfield(cmd,'Nt'))
          [~,Nt,~] = size(data);
          layer = 1;
        end
        [vals,~,dim] = size(data);
        max_waveform = zeros(vals,dim);
        max_val_gps_time = zeros(1,dim);
        for i=1:1:dim
          
          if(layer+Nt > length(data) )
            [~,Nt,~] = size(data);
          end
          max_vals = max(data(:,(layer:Nt),i), [], 1);
          [~,max_rline] = max(max_vals);
          
          max_waveform(:,i) = data(:,max_rline,i);
          gps_time = records.gps_time;
          max_val_gps_time_adc(1,i) = gps_time(:,max_rline);
        end
        
      else
        if( ~isfield(cmd,'layer') && ~isfield(cmd,'Nt') )
          [~,Nt] = size(data);
          layer = 1;  %start bin to start search
        end
        
        if(layer+Nt > length(data) )
          [~,Nt] = size(data);
        end
        
        max_vals = max(data(:,(layer:Nt)), [], 1);
        [~,max_rline] = max(max_vals);
        
        max_waveform = [data(:,max_rline)];  %return max_val_waveform -> the waveform with the maximum value
        gps_time = records.gps_time;
        max_val_gps_time = gps_time(:,max_rline);
      end
      out_fn = fullfile(ct_filename_out(param, param.analysis.out_path), ...
        sprintf('saturation_img_%02d_%d_%d.mat',img,task_recs));
      [out_fn_dir] = fileparts(out_fn);
      if ~exist(out_fn_dir,'dir')
        mkdir(out_fn_dir);
      end
      param_analysis = param;
      param_analysis.gps_source = records.gps_source;
      fprintf('  Saving outputs %s\n', out_fn);
      save(out_fn,'-v7.3', 'max_rline', 'max_waveform', 'gps_time',...
        'max_val_gps_time', 'max_val_gps_time_adc');
      
      
    elseif strcmpi(cmd.method,{'specular'})
      %% Specular
      % ===================================================================
      % ===================================================================
      
      tmp_param = param;
      tmp_param.load.pulse_comp = true;
      tmp_param.load.motion_comp = true;
      tmp_hdr = hdr;
      tmp_wfs = wfs;
      
      for wf_adc = cmd.wf_adcs{img}(:).'
        wf = param.analysis.imgs{1}(wf_adc,1);
        adc = param.analysis.imgs{1}(wf_adc,2);
        
        coh_ave_samples = [];
        coh_ave = [];
        nyquist_zone = [];
        gps_time = [];
        surface = [];
        lat = [];
        lon = [];
        elev = [];
        roll = [];
        pitch = [];
        heading = [];
        
        % Pulse compression
        tmp_param.load.imgs = {tmp_param.load.imgs{1}(wf_adc,:)};
        tmp_hdr.records = {tmp_hdr.records{1,wf_adc}};
        tmp_wfs(wf).deconv.en = false;
        
        [tmp_hdr,data] = data_pulse_compress(tmp_param,tmp_hdr,tmp_wfs,{raw_data{1}(:,:,wf_adc)});
        
        [tmp_hdr,data] = data_merge_combine(tmp_param,tmp_hdr,data);
        
        data = data{1};
      
      
        % Correct all the data to a constant elevation (no zero padding is
        % applied so wrap around could be an issue for DDC data)
        for rline = 1:size(data,2)
          elev_dt = (tmp_hdr.records{1,wf_adc}.elev(rline) - tmp_hdr.records{1,wf_adc}.elev(1)) / (c/2);
          data(:,rline,wf_adc) = ifft(fft(data(:,rline,wf_adc)) .* exp(1i*2*pi*tmp_hdr.freq{1,wf_adc}*elev_dt));
        end
        
        %% Specular: Coherence (STFT) Estimation
        
        % Grab the peak values
        if ~isfield(cmd,'min_bin') || isempty(cmd.min_bin)
          if strcmpi(radar_type,'deramp')
            cmd.min_bin = 0;
          else
            cmd.min_bin = wfs(wf).Tpd;
          end
        end
        min_bin_idxs = find(tmp_hdr.time{1,wf_adc} >= cmd.min_bin,1);
        [max_value,max_idx_unfilt] = max(data(min_bin_idxs:end,:,wf_adc));
        max_idx_unfilt = max_idx_unfilt + min_bin_idxs(1) - 1;
        
        % Perform STFT (short time Fourier transform) (i.e. overlapping short FFTs in slow-time)
        H = spectrogram(double(max_value),hanning(cmd.rlines),cmd.rlines/2,cmd.rlines);
        
        % Since there may be a little slope in the ice, we sum the powers from
        % the lower frequency doppler bins rather than just taking DC. It seems to help
        % a lot to normalize by the sum of the middle/high-frequency Doppler bins.   A coherent/specular
        % surface will have high power in the low bins and low power in the high bins
        % so this ratio makes sense.
        peakiness = lp(max(abs(H(cmd.signal_doppler_bins,:)).^2) ./ mean(abs(H(cmd.noise_doppler_bins,:)).^2));
        
        if 0
          figure(1); clf;
          imagesc(lp(data(:,:,wf_adc)))
          figure(2); clf;
          plot(peakiness)
          keyboard
        end
        
        % Threshold to find high peakiness range lines. (Note these are not
        % actual range line numbers, but rather indices into the STFT groups
        % of range lines.)
        good_rlines = find(peakiness > cmd.threshold);
        
        % Force there to be two good STFT groups in a row before storing
        % it to the specular file for deconvolution.
        good_rlines_idxs = diff(good_rlines) == 1;
        final_good_rlines = good_rlines(good_rlines_idxs);
        
        if ~isempty(cmd.max_rlines)
          [~,sort_idxs] = sort( peakiness(final_good_rlines)+peakiness(final_good_rlines+1) , 'descend');
          final_good_rlines = final_good_rlines(sort_idxs);
          final_good_rlines = final_good_rlines(1 : min(end,cmd.max_rlines));
        end
        
        % Prepare outputs for file
        peakiness_rlines = round((1:length(peakiness)+0.5)*cmd.rlines/2);
        gps_time = tmp_hdr.gps_time(peakiness_rlines);
        lat = tmp_hdr.records{1,wf_adc}.lat(peakiness_rlines);
        lon = tmp_hdr.records{1,wf_adc}.lon(peakiness_rlines);
        elev = tmp_hdr.records{1,wf_adc}.elev(peakiness_rlines);
        roll = tmp_hdr.records{1,wf_adc}.roll(peakiness_rlines);
        pitch = tmp_hdr.records{1,wf_adc}.pitch(peakiness_rlines);
        heading = tmp_hdr.records{1,wf_adc}.heading(peakiness_rlines);
        surface = tmp_hdr.surface(peakiness_rlines);
        
        %% Specular: Forced GPS Check
        deconv_forced = zeros(size(final_good_rlines));
        if isfield(cmd,'gps_times') && ~isempty(cmd.gps_times)
          for idx = 1:length(cmd.gps_times)
            force_gps_time = cmd.gps_times(idx);
            if records.gps_time(1) <= force_gps_time && records.gps_time(end) >= force_gps_time
              % This forced GPS time is in the block, find the peakiness block
              % closest to this time and force it to be included in final_good_rlines
              % if it is not already.
              [~,force_final_good_rline] = min(abs(gps_time - force_gps_time));
              match_idx = find(final_good_rlines == force_final_good_rline);
              if isempty(match_idx)
                final_good_rlines = [final_good_rlines force_final_good_rline];
                [final_good_rlines,new_idxs] = sort(final_good_rlines);
                deconv_forced(new_idxs(end)) = 1;
              else
                deconv_forced(match_idx) = 1;
              end
            end
          end
        end
        
        %% Specular: Extract specular waveforms
        deconv_gps_time = [];
        deconv_mean = {};
        deconv_std = {};
        deconv_sample = {};
        deconv_twtt = [];
        for good_rline_idx = 1:length(final_good_rlines)
          % Get the specific STFT group we will be extracting an answer from
          final_good_rline = final_good_rlines(good_rline_idx);
          
          % Determine the center range line that this STFT group corresponds to
          center_rline = (final_good_rline+0.5)*cmd.rlines/2;
          
          fprintf('    SPECULAR %d %s (%s)!\n', center_rline, ...
            datestr(epoch_to_datenum(tmp_hdr.gps_time(center_rline)),'YYYYmmDD HH:MM:SS.FFF'), ...
            datestr(now));
          
          % Find the max values and correponding indices for all the range lines
          % in this group. Since we over-interpolate by Mt and the memory
          % requirements may be prohibitive, we do this in a loop
          % Enforce the same DDC filter in this group. Skip groups that have DDC filter swiches.
          STFT_rlines = -cmd.rlines/4 : cmd.rlines/4-1;
%           if any(strcmpi(radar_name,{'kuband','kuband2','kuband3','kaband3','snow','snow2','snow3','snow5','snow8'}))
%             if any(diff(img_Mt(center_rline + STFT_rlines)))
%               fprintf('    Including different DDC filters, skipped.\n');
%               continue
%             end
%           end
          Mt = 100;
          max_value = zeros(size(STFT_rlines));
          max_idx_unfilt = zeros(size(STFT_rlines));
          for offset_idx = 1:length(STFT_rlines)
            offset = STFT_rlines(offset_idx);
            oversampled_rline = interpft(data(:,center_rline+offset),size(data,1)*Mt);
            [max_value(offset_idx),max_idx_unfilt(offset_idx)] ...
              = max(oversampled_rline(min_bin_idxs(1)*Mt:end));
            max_idx_unfilt(offset_idx) = max_idx_unfilt(offset_idx) + min_bin_idxs(1)*Mt - 1;
          end
          
          % Filter the max and phase vectors
          max_idx = sgolayfilt(max_idx_unfilt/100,3,51);
          phase_corr = sgolayfilt(double(unwrap(angle(max_value))),3,51);
          
          % Compensate range lines for amplitude, phase, and delay variance
          % in the peak value
          
          % Apply true time delay shift to flatten surface
          dt = diff(tmp_hdr.time{1,wf_adc}(1:2));
          Nt = tmp_hdr.Nt{1,wf_adc}(rline);
          comp_data = ifft(fft(data(:,center_rline+STFT_rlines,wf_adc)) .* exp(1i*2*pi*tmp_hdr.freq{1,wf_adc}*max_idx*dt) );
          % Apply amplitude correction
          comp_data = max(abs(max_value)) * comp_data .* repmat(1./abs(max_value), [Nt 1]);
          % Apply phase correction (compensating for phase from time delay shift)
          comp_data = comp_data .* repmat(exp(-1i*(phase_corr + 2*pi*tmp_hdr.freq{1,wf_adc}(1)*max_idx*dt)), [Nt 1]);
          
          deconv_gps_time(end+1) = tmp_hdr.gps_time(center_rline);
          deconv_mean{end+1} = mean(comp_data,2);
          deconv_std{end+1} = std(comp_data,[],2);
          deconv_sample{end+1} = data(:,center_rline+1+cmd.rlines/4,wf_adc);
          deconv_twtt(:,end+1) = tmp_hdr.time{1,wf_adc}(round(mean(max_idx)));
        end
        
        deconv_fc = tmp_hdr.freq{1,wf_adc}(1) * ones(size(deconv_gps_time));
        deconv_t0 = tmp_hdr.time{1,wf_adc}(1) * ones(size(deconv_gps_time));
        dt = tmp_hdr.time{1,wf_adc}(2)-tmp_hdr.time{1,wf_adc}(1);
        
        %% Specular: Save Results
        out_fn = fullfile(ct_filename_out(param, param.analysis.out_path), ...
          sprintf('specular_wf_%d_adc_%d_%d_%d.mat',wf,adc,task_recs));
        [out_fn_dir] = fileparts(out_fn);
        if ~exist(out_fn_dir,'dir')
          mkdir(out_fn_dir);
        end
        param_analysis = param;
        fprintf('  Saving outputs %s\n', out_fn);
        save(out_fn,'-v7.3', 'deconv_gps_time', 'deconv_mean', 'deconv_std','deconv_sample','deconv_twtt',...
          'deconv_forced','peakiness', 'deconv_fc', 'deconv_t0', 'dt', 'gps_time', 'lat', ...
          'lon', 'elev', 'roll', 'pitch', 'heading', 'surface', 'param_analysis', 'param_records');
      end
      
      
    elseif strcmpi(cmd.method,{'coh_noise'})
      %% Coh Noise
      % ===================================================================
      % ===================================================================
      
      tmp_param = param;
      tmp_param.load.pulse_comp = true;
      tmp_param.load.motion_comp = false;
      tmp_hdr = hdr;
      tmp_wfs = wfs;
      
      for wf_adc = cmd.wf_adcs{img}(:).'
        wf = tmp_param.analysis.imgs{1}(wf_adc,1);
        adc = tmp_param.analysis.imgs{1}(wf_adc,2);
        
        coh_ave_samples = single([]);
        coh_ave = single([]);
        nyquist_zone = [];
        gps_time = [];
        surface = [];
        lat = [];
        lon = [];
        elev = [];
        roll = [];
        pitch = [];
        heading = [];
        
        % Pulse compression
        tmp_wfs(wf).coh_noise_method = '';
        tmp_wfs(wf).deconv.en = false;
        tmp_param.load.imgs = {tmp_param.load.imgs{1}(wf_adc,:)};
        tmp_hdr.records = {tmp_hdr.records{1,wf_adc}};
        
        [tmp_hdr,data] = data_pulse_compress(tmp_param,tmp_hdr,tmp_wfs,{raw_data{1}(:,:,wf_adc)});
        
        [tmp_hdr,data] = data_merge_combine(tmp_param,tmp_hdr,data);
        data = data{1};
        
        %% Coh Noise: Doppler and Data-Statistics
        % Implement memory efficient fft and statistics operations by doing
        % one bin at a time
        doppler = zeros(1,size(data,2),'single');
        mu = zeros(size(data,1),1);
        sigma = zeros(size(data,1),1);
        num_bins = 0;
        for rbin=1:size(data,1)
          tmp = abs(fft(data(rbin,:))).^2;
          if all(~isnan(tmp))
            doppler = doppler + tmp;
            num_bins = num_bins + 1;
          end
          mu(rbin) = nanmean(data(rbin,:));
          sigma(rbin) = nanstd(data(rbin,:));
        end
        doppler = doppler/num_bins;
        mu(abs(mu)*10<sigma) = 0; % Throw out high variance means

        %% Coh Noise: Block Analysis

        % Do averaging
        rline0_list = 1:cmd.block_ave:size(data,2);
        for rline0_idx = 1:length(rline0_list)
          rline0 = rline0_list(rline0_idx);
          rlines = rline0 + (0:min(cmd.block_ave-1,size(data,2)-rline0));
          
          % Regular method for collecting good_samples
          % ===============================================================
          good_samples = lp(bsxfun(@minus,data(:,rlines),mu)) < cmd.power_threshold;
          
          %% Coh Noise: Debug coh_ave.power_threshold
          if 0
            figure(1); clf;
            imagesc(lp(data(:,rlines)));
            a1 = gca;
            figure(2); clf;
            imagesc(good_samples);
            colormap(gray);
            caxis([0 1]);
            title('Good sample mask (black is thresholded)');
            a2 = gca;
            figure(3); clf;
            imagesc( lp(bsxfun(@minus,data(:,rlines),mu)) );
            a3 = gca;
            linkaxes([a1 a2 a3], 'xy');
            keyboard
          end
          
          %% Coh Noise: Concatenate Info
          coh_ave_samples(:,rline0_idx) = sum(good_samples,2);
          coh_ave(:,rline0_idx) = sum(data(:,rlines) .* good_samples,2) ./ coh_ave_samples(:,rline0_idx);
          
          if strcmpi(radar_type,'deramp')
            % Nyquist_zone: bit mask for which nyquist zones are used in this
            % segment. For example, if nyquist zones 0 and 2 are used, then
            % nyquist zone will be 5 which is 0101 in binary and positions 0
            % and 2 are set to 1. If nyquist zones 0 and 1 are used, then
            % nyquist zone will be 3 which is 0011 in binary and positions 0
            % and 1 are set to 1.
            nz_mask = char('0'*ones(1,32));
            nz_mask(32-unique(hdr.nyquist_zone{img,wf_adc}(rlines))) = '1';
            nyquist_zone(1,rline0_idx) = bin2dec(nz_mask);
          else
            nyquist_zone(1,rline0_idx) = 1;
          end
          
          gps_time(rline0_idx) = mean(hdr.gps_time(rlines));
          surface(rline0_idx) = mean(hdr.surface(rlines));
          lat(rline0_idx) = mean(hdr.records{img,wf_adc}.lat(rlines));
          lon(rline0_idx) = mean(hdr.records{img,wf_adc}.lon(rlines));
          elev(rline0_idx) = mean(hdr.records{img,wf_adc}.elev(rlines));
          roll(rline0_idx) = mean(hdr.records{img,wf_adc}.roll(rlines));
          pitch(rline0_idx) = mean(hdr.records{img,wf_adc}.pitch(rlines));
          heading(rline0_idx) = mean(hdr.records{img,wf_adc}.heading(rlines));
        end
        
        %% Coh Noise: Save results
        Nt = length(tmp_hdr.time{1});
        fc = tmp_hdr.freq{1}(1);
        t0 = tmp_hdr.time{1}(1);
        dt = tmp_hdr.time{1}(2)-tmp_hdr.time{1}(1);
        
        out_fn = fullfile(ct_filename_out(tmp_param, cmd.out_path), ...
          sprintf('coh_noise_wf_%d_adc_%d_%d_%d.mat',wf,adc,task_recs));
        [out_fn_dir] = fileparts(out_fn);
        if ~exist(out_fn_dir,'dir')
          mkdir(out_fn_dir);
        end
        param_analysis = tmp_param;
        fprintf('  Saving outputs %s\n', out_fn);
        save(out_fn,'-v7.3', 'coh_ave', 'coh_ave_samples', 'doppler', 'Nt', 'fc', 't0', 'dt', 'gps_time', 'surface', 'lat', ...
          'lon', 'elev', 'roll', 'pitch', 'heading', 'param_analysis', 'param_records','nyquist_zone');
      end
      
    elseif strcmpi(cmd.method,{'waveform'})
      %% Waveform
      % ===================================================================
      % ===================================================================
      
      %% Waveform: Load layer
      layers = opsLoadLayers(param,param.analysis.surf.layer_params);
      
      %% Waveform: Extract surface values according to bin_rng
      layers(1).twtt = interp1(layers(1).gps_time, layers(1).twtt, gps_time(1,:));
      layers(1).twtt = interp_finite(layers(1).twtt,0);
      zero_bin = round(interp1(wfs(wf).time, 1:length(wfs(wf).time), layers(1).twtt,'linear','extrap'));
      start_bin = zero_bin;
      stop_bin = param.analysis.surf.Nt-1 + zero_bin;
      surf_vals = zeros(param.analysis.surf.Nt, size(data,2), size(data,3));
      for rline = 1:size(data,2)
        start_bin0 = max(1,start_bin(rline));
        stop_bin0 = min(size(data,1),stop_bin(rline));
        out_bin0 = 1 + start_bin0-start_bin(rline);
        out_bin1 = size(surf_vals,1) - (stop_bin(rline)-stop_bin0);
        surf_vals(out_bin0:out_bin1,rline,:) = data(start_bin0:stop_bin0,rline,:);
        surf_bins(1:2,rline) = [start_bin0, stop_bin0];
      end
      
      %% Waveform: Save
      out_fn = fullfile(ct_filename_out(param, param.analysis.out_path), ...
        sprintf('surf_img_%02d_%d_%d.mat',img,task_recs));
      [out_fn_dir] = fileparts(out_fn);
      if ~exist(out_fn_dir,'dir')
        mkdir(out_fn_dir);
      end
      param_analysis = param;
      param_analysis.gps_source = records.gps_source;
      fprintf('  Saving outputs %s\n', out_fn);
      save(out_fn,'-v7.3', 'surf_vals','surf_bins', 'wfs', 'gps_time', 'lat', ...
        'lon', 'elev', 'roll', 'pitch', 'heading', 'param_analysis', 'param_records');
      
      
    elseif strcmpi(cmd.method,{'statistics'})
      %% Statistics
      % ===================================================================
      % ===================================================================
      
      %% Statistics: Load layers (there should be two)
      layers = opsLoadLayers(param,param.analysis.power.layer_params);
      
      %% Statistics: Run function handles on the layers
      layers(1).twtt = interp1(layers(1).gps_time, layers(1).twtt, gps_time(1,:));
      layers(1).twtt = interp_finite(layers(1).twtt,0);
      start_bin = round(interp1(wfs(wf).time, 1:length(wfs(wf).time), layers(1).twtt,'linear','extrap'));
      start_bin = min(max(1,start_bin),size(data,1));
      layers(2).twtt = interp1(layers(2).gps_time, layers(2).twtt, gps_time(1,:));
      layers(2).twtt = interp_finite(layers(2).twtt,0);
      stop_bin = round(interp1(wfs(wf).time, 1:length(wfs(wf).time), layers(2).twtt,'linear','extrap'));
      stop_bin = min(max(1,stop_bin),size(data,1));
      for rline = 1:size(data,2)
        vals = data(start_bin(rline):stop_bin(rline),rline,:);
        power_bins(1:2,rline) = [start_bin(rline); stop_bin(rline)];
        for fh_idx = 1:length(param.analysis.power.fh)
          power_vals(fh_idx,rline,:) = param.analysis.power.fh{fh_idx}(vals);
        end
      end
      
      %% Statistics: Save
      out_fn = fullfile(ct_filename_out(param, param.analysis.out_path), ...
        sprintf('power_img_%02d_%d_%d.mat',img,task_recs));
      [out_fn_dir] = fileparts(out_fn);
      if ~exist(out_fn_dir,'dir')
        mkdir(out_fn_dir);
      end
      param_analysis = param;
      param_analysis.gps_source = records.gps_source;
      fprintf('  Saving outputs %s\n', out_fn);
      save(out_fn,'-v7.3', 'power_vals','power_bins', 'wfs', 'gps_time', 'lat', ...
        'lon', 'elev', 'roll', 'pitch', 'heading', 'param_analysis', 'param_records');
      
%       %% 1. Load layer
%       layers = opsLoadLayers(param,param.analysis.psd.layer_params);
%       
%       %% 2. Extract psd values according to bin_rng
%       layers(1).twtt = interp1(layers(1).gps_time, layers(1).twtt, gps_time(1,:));
%       layers(1).twtt = interp_finite(layers(1).twtt,0);
%       zero_bin = round(interp1(wfs(wf).time, 1:length(wfs(wf).time), layers(1).twtt,'linear','extrap'));
%       start_bin = zero_bin;
%       stop_bin = param.analysis.psd.Nt-1 + zero_bin;
%       psd_vals = zeros(param.analysis.psd.Nt, size(data,2), size(data,3));
%       psd_mean = zeros(1, size(data,2), size(data,3));
%       psd_Rnn = zeros(size(data,3), size(data,2), size(data,3));
%       for rline = 1:size(data,2)
%         start_bin0 = max(1,start_bin(rline));
%         stop_bin0 = min(size(data,1),stop_bin(rline));
%         out_bin0 = 1 + start_bin0-start_bin(rline);
%         out_bin1 = size(psd_vals,1) - (stop_bin(rline)-stop_bin0);
%         psd_vals(out_bin0:out_bin1,rline,:) = data(start_bin0:stop_bin0,rline,:);
%         psd_bins(1:2,rline) = [start_bin0, stop_bin0];
%         psd_mean(1,rline,:) = mean(abs(data(start_bin0:stop_bin0,rline,:)).^2);
%         snapshots = squeeze(data(start_bin0:stop_bin0,rline,:)).';
%         psd_Rnn(:,rline,:) = 1/(stop_bin0-start_bin0+1) * snapshots * snapshots';
%       end
%       psd_vals = mean(abs(fft(psd_vals)).^2,2);
%       
%       %% 3. Save
%       
%       param_analysis = param;
%       param_analysis.gps_source = records.gps_source;
%       fprintf('  Saving outputs %s\n', out_fn);
%       save(out_fn,'-v7.3', 'psd_vals','psd_bins', 'psd_mean', 'psd_Rnn', 'wfs', 'gps_time', 'lat', ...
%         'lon', 'elev', 'roll', 'pitch', 'heading', 'param_analysis', 'param_records');
    end
    
  end
end

fprintf('%s done %s\n', mfilename, datestr(now));

success = true;

return;

