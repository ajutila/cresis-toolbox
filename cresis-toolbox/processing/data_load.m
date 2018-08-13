function [hdr,data] = data_load(param,records,wfs,states)
% [hdr,data] = data_load(param,records,wfs,states)

%% Preallocate data
% ===================================================================
total_rec = param.load.recs(end)-param.load.recs(1)+1;
Nx = floor(total_rec/param.load.presums);
data = cell(size(param.load.imgs));
hdr = [];
hdr.bad_rec = cell(size(param.load.imgs));
for img = 1:length(param.load.imgs)
  wf = abs(param.load.imgs{img}(1,1));
  Nt = wfs(wf).Nt_raw;
  Nc = size(param.load.imgs{img},1);
  data{img} = complex(zeros(Nt,Nx,Nc,'single'));
  hdr.bad_rec{img} = zeros(Nx,Nc,'uint8');
  hdr.nyquist_zone{img} = zeros(Nx,'uint8');
  hdr.DDC_mode{img} = zeros(Nx,'double');
  hdr.DDC_freq{img} = zeros(Nx,'double');
  hdr.Nt{img} = zeros(Nx,'double');
  hdr.t0{img} = zeros(Nx,'double');
  hdr.t_ref{img} = zeros(Nx,'double');
end
nyquist_zone = zeros(1,param.load.presums);
DDC_mode = zeros(1,param.load.presums);
DDC_freq = zeros(1,param.load.presums);
Nt = zeros(1,param.load.presums);
t0 = zeros(1,param.load.presums);
t_ref = zeros(1,param.load.presums);

%% Endian mode
% ===================================================================
if any(param.records.file_version==[9 411 412])
  file_mode = 'ieee-le';
else
  file_mode = 'ieee-be';
end

%% Load data
% ===================================================================
for state_idx = 1:length(states)
  state = states(state_idx);
  file_data_last_file = [];
  board = state.board;
  board_idx = state.board_idx;
  fid = 0;
  out_rec = 0;
  num_accum = 0;
  num_presum_records = 0;
  
  file_idxs = relative_rec_num_to_file_idx_vector( ...
    param.load.recs,records.relative_rec_num{board_idx});
  
  rec = 1;
  while rec <= total_rec
    
    %% Load in a file
    if records.offset(board_idx,rec) ~= -2^31
      % Determine which file has the current record
      file_idx = file_idxs(rec);
      if ~isempty(file_data_last_file)
        % Part of current record has been loaded from previous file
      elseif records.offset(board_idx,rec) < 0 && records.offset(board_idx,rec) ~= -2^31
        % Record offset is negative, but not -2^31: this means the record
        % started in the previous file.
        file_idx = file_idx - 1;
      end
      
      % Get the file's name
      adc = state.adc(1);
      fn_name = records.relative_filename{board_idx}{file_idx};
      [fn_dir] = get_segment_file_list(param,adc);
      fn = fullfile(fn_dir,fn_name);

      % Open the file
      fprintf('  Open %s (%s)\n', fn, datestr(now));
      [fid,msg] = fopen(fn, 'r',file_mode);
      if fid <= 0
        error('File open failed (%s)\n%s',fn, msg);
      end

      % Seek to the current record's position in the file
      if ~isempty(file_data_last_file)
        file_data_offset = records.offset(board_idx,rec);
      elseif records.offset(board_idx,rec) < 0
        if num_bytes==inf
          finfo = dir(fn)
        end
        file_data_offset = finfo.bytes + records.offset(board_idx,rec);
        fseek(fid,file_data_offset,-1);
      else
        file_data_offset = records.offset(board_idx,rec);
        fseek(fid,file_data_offset,-1);
      end
      
      % Load the rest of the file into memory
      file_data = [file_data_last_file(:); fread(fid,inf,'uint8=>uint8')];
    end

    %% Pull out records from this file
    while rec <= total_rec
      if records.offset(board_idx,rec) ~= -2^31
        if records.offset(board_idx,rec) < 0
          if isempty(file_data_last_file)
            % Record offset is negative and so represents a record that
            % bridges into the next file
            file_data_last_file = file_data(end+records.offset(board_idx,rec)+1:end);
            break
          else
            file_data_last_file = [];
          end
        end
        if file_idxs(rec) > file_idx
          break;
        end
        
        % Extract next record (determine its relative position in the
        % file_data memory block
        rec_offset = records.offset(board_idx,rec) - file_data_offset;
        
        % Process all adc-wf pairs in this record
        for accum_idx = 1:length(state.wf)
          adc = state.adc(accum_idx);
          wf = state.wf(accum_idx);
          
          % Read in headers for this waveform
          % ---------------------------------------------------------------
          
          if wfs(wf).quantization_to_V_dynamic
            if param.records.file_version == 407
              bit_shifts = -typecast(file_data(rec_offset + wfs(wf).offset - 4),'int8');
              % Apply dynamic bit shifts
              quantization_to_V_adjustment = 2^(bit_shifts - wfs(wf).bit_shifts);
            end
          else
            quantization_to_V_adjustment = 1;
          end

          % Read in headers for this record
          if any(param.records.file_version == [3 5 7 8])
            % Number of fast-time samples Nt, and start time t0
            start_idx = double(typecast(file_data(rec_offset+37:rec_offset+38), 'uint16')) + wfs(wf).time_raw_trim(1);
            stop_idx = double(typecast(file_data(rec_offset+39:rec_offset+40), 'uint16')) - wfs(wf).time_raw_trim(2);
            if param.records.file_version == 8
              Nt(num_accum+1) = stop_idx - start_idx;
              wfs(wf).Nt_raw = Nt(num_accum+1);
            else
              % NCO frequency
              DDC_freq(num_accum+1) = double(-typecast(file_data(rec_offset+43:rec_offset+44),'uint16'));
              if param.records.file_version == 3
                DDC_freq(num_accum+1) = DDC_freq(num_accum+1) / 2^15 * wfs(wf).fs_raw * 2 - 62.5e6;
              elseif any(param.records.file_version == [5 7])
                DDC_freq(num_accum+1) = DDC_freq(num_accum+1) / 2^15 * wfs(wf).fs_raw * 2;
              end
              
              DDC_mode(num_accum+1) = double(file_data(rec_offset+46));
              raw_or_DDC = file_data(rec_offset + wfs(wf).offset +48);
              if raw_or_DDC
                Nt(num_accum+1) = (stop_idx - start_idx);
              else
                Nt(num_accum+1) = floor((stop_idx - start_idx) / 2^(1+DDC_mode(num_accum+1)));
              end
              wfs(wf).Nt_raw = Nt(num_accum+1);
            end
            t0(num_accum+1) = start_idx/wfs(wf).fs_raw;
            if size(data{state.img(accum_idx)},1) < wfs(wf).Nt_raw
              % Force data output to grow to the current record size
              data{state.img(accum_idx)}(wfs(wf).Nt_raw,1,1) = 0;
            end
            
            % Reference deramp time delay, t_ref
            t_ref(num_accum+1) = wfs(wf).t_ref;
            
            % Bit shifts
            if wfs(wf).quantization_to_V_dynamic
              bit_shifts = double(-typecast(file_data(rec_offset+36),'int8'));
              quantization_to_V_adjustment = 2^(bit_shifts - wfs(wf).bit_shifts);
            end
            
            % Nyquist zone
            if param.records.file_version == 8
              nyquist_zone(num_accum+1) = file_data(rec_offset+34);
            elseif any(param.records.file_version == [3 5 7])
              nyquist_zone(num_accum+1) = file_data(rec_offset+45);
            end
          end
          

          % Extract waveform for this wf-adc pair
          switch wfs(wf).record_mode
            case 0
              % Read in standard fixed record
              %  - Supports interleaved IQ samples
              %  - Supports arbitrary sample types
              %  - Supports interleaved data channels ("adcs")
              start_bin = rec_offset + wfs(wf).offset + wfs(wf).time_raw_trim(1)*wfs(wf).adc_per_board*wfs(wf).sample_size;
              stop_bin = start_bin + wfs(wf).Nt_raw*wfs(wf).adc_per_board*wfs(wf).sample_size-1;
              tmp = single(typecast(file_data(start_bin : stop_bin), wfs(wf).sample_type));
              if wfs(wf).complex
                if wfs(wf).conjugate
                  tmp = tmp(1:2:end) - 1i*tmp(2:2:end);
                else
                  tmp = tmp(1:2:end) + 1i*tmp(2:2:end);
                end
              end
              adc_offset = mod(adc-1,wfs(wf).adc_per_board);
              tmp = tmp(1+adc_offset : wfs(wf).adc_per_board : end);
              if param.records.file_version ~= 408
                tmp_data{adc,wf} = tmp;
              else
                % 8 sample interleave for file_version 408
                tmp_data{adc,wf}(1:8:length(tmp)) = tmp(1:8:end);
                tmp_data{adc,wf}(5:8:length(tmp)) = tmp(5:8:end);
                tmp_data{adc,wf}(2:8:length(tmp)) = tmp(2:8:end);
                tmp_data{adc,wf}(6:8:length(tmp)) = tmp(6:8:end);
                tmp_data{adc,wf}(3:8:length(tmp)) = tmp(3:8:end);
                tmp_data{adc,wf}(7:8:length(tmp)) = tmp(7:8:end);
                tmp_data{adc,wf}(4:8:length(tmp)) = tmp(4:8:end);
                tmp_data{adc,wf}(8:8:length(tmp)) = tmp(8:8:end);
              end
              
            case 1
              % Read in RSS dynamic record
              
          end
          
          if quantization_to_V_adjustment ~= 1 && ~param.load.raw_data
            % Convert from quantization to voltage at the receiver input for the
            % maximum gain case:
            %  1. fast time gains less than the maximum for this record will be
            %     compensated for in the next step
            %  2. antenna effects not considered at this step
            tmp_data{adc,wf} = tmp_data{adc,wf} * quantization_to_V_adjustment;
            
          end
          
          % Accumulate (presum)
          if num_accum == 0
            state.data{accum_idx} = tmp_data{adc,wf};
          else
            state.data{accum_idx} = state.data{accum_idx} + tmp_data{adc,wf};
          end
        end
        num_accum = num_accum + 1;
      end
      
      % Store to output if number of presums is met
      num_presum_records = num_presum_records + 1;
      if num_presum_records >= param.load.presums
        out_rec = out_rec + 1;
        for accum_idx = 1:length(state.wf)
          % Sum up wf-adc sum pairs until done
          switch state.wf_adc_sum_cmd(accum_idx)
            case 0
              state.data{accum_idx} = state.wf_adc_sum(accum_idx)*state.data{accum_idx};
              continue;
            case 1
              state.data{accum_idx} = state.data{accum_idx} ...
                + state.wf_adc_sum(accum_idx)*state.data{accum_idx};
              continue;
            case 2
              state.data{accum_idx} = state.data{accum_idx} ...
                + state.wf_adc_sum(accum_idx)*state.data{accum_idx};
            case 3
              state.data{accum_idx} = state.wf_adc_sum(accum_idx)*state.data{accum_idx};
          end

          % Store to output
          if num_accum < num_presum_records*wfs(wf).presum_threshold ...
              || any(param.records.file_version == [3 5 7]) ...
              && (any(nyquist_zone ~= nyquist_zone(1)) ...
              || any(DDC_mode ~= DDC_mode(1)) ...
              || any(DDC_freq ~= DDC_freq(1)) ...
              || any(Nt ~= Nt(1)) ...
              || any(t0 ~= t0(1)) ...
              || any(t_ref ~= t_ref(1)))
            % Too few presums, mark as bad record
            % Or a parameter changed within the presum block
            data{state.img}(:,out_rec,state.wf_adc_idx(accum_idx)) = 0;
            hdr.bad_rec{state.img}(out_rec,state.wf_adc_idx(accum_idx)) = 1;
          else
            data{state.img(accum_idx)}(:,out_rec,state.wf_adc_idx(accum_idx)) = state.data{accum_idx};
          
            hdr.nyquist_zone{img}(out_rec) = nyquist_zone(1);
            hdr.DDC_mode{img}(out_rec) = DDC_mode(1);
            hdr.DDC_freq{img}(out_rec) = DDC_freq(1);
            hdr.Nt{img}(out_rec) = Nt(1);
            hdr.t0{img}(out_rec) = t0(1);
            hdr.t_ref{img}(out_rec) = t_ref(1);
            
            if any(isfinite(wfs(wf).blank))
              % Blank data
              %  - Blank is larger of two numbers passed in through radar worksheet blank parameter:
              %   Number 1 is added to surface time delay and is usually equal to pulse duration
              %   Number 2 is unmodified and is usually equal to hardware blank setting
              %   Set either number to -inf to disable
              blank_time = max(records.surface(rec) + wfs(wf).blank(1),wfs(wf).blank(2));
              data{state.img(accum_idx)}(wfs(wf).time_raw-param.radar.wfs(wf).Tsys(adc) <= blank_time,out_rec,state.wf_adc_idx(accum_idx)) = 0;
            end
          end
        end
        
        % Reset counters and increment record counter
        num_presum_records = 0;
        num_accum = 0;
        rec = rec + 1;
      end
    end
  end
  
end

for img = 1:length(param.load.imgs)
  for wf_adc_idx = 1:size(data{img},3)
    wf = param.load.imgs{img}(wf_adc_idx,1);
    adc = param.load.imgs{img}(wf_adc_idx,2);
    
    % Apply channel compensation, presum normalization, and constant
    % receiver gain compensation
    chan_equal = 10.^(param.radar.wfs(wf).chan_equal_dB(param.radar.wfs(wf).rx_paths(adc))/20) ...
      .* exp(1i*param.radar.wfs(wf).chan_equal_deg(param.radar.wfs(wf).rx_paths(adc))/180*pi);
    mult_factor = single(wfs(wf).quantization_to_V(adc)/param.load.presums/wfs(wf).adc_gains(adc)/chan_equal);
    data{img}(:,:,wf_adc_idx) = mult_factor * data{img}(:,:,wf_adc_idx);
    
    % Compensate for receiver gain applied before ADC quantized the signal
    %  - For time varying receiver gain, the convention is to compensate
    %    to the maximum receiver gain and use the wfs(wf).gain parameter
    %    to vary the gain relative to that.
    % Apply fast-time varying gain if defined
    if ~isempty(wfs(wf).gain)
      data{img}(:,:,wf_adc_idx) = bsxfun(@times,data{img}(:,:,wf_adc_idx),interp1(wfs(wf).gain.Time, wfs(wf).gain.Gain, wfs(wf).time_raw(1:wfs(wf).Nt_raw)));
    end
    
    % Apply time varying channel compensation
    if ~isempty(wfs(wf).chan_equal)
      cdf_fn_dir = fileparts(ct_filename_out(param,wfs(wf).chan_equal, ''));
      cdf_fn = fullfile(cdf_fn_dir,sprintf('chan_equal_%s_wf_%d_adc_%d.nc', param.day_seg, wf, adc));
      
      finfo = ncinfo(cdf_fn);
      % Determine number of records and set recs(1) to this
      Nt = finfo.Variables(find(strcmp('chan_equal',{finfo.Variables.Name}))).Size(2);
      
      chan_equal = [];
      chan_equal.gps_time = ncread(cdf_fn,'gps_time');
      recs = find(chan_equal.gps_time > records.gps_time(1) - 100 & chan_equal.gps_time < records.gps_time(end) + 100);
      chan_equal.gps_time = chan_equal.gps_time(recs);
      
      chan_equal.chan_equal = ncread(cdf_fn,'chan_equalI',[recs(1) 1],[recs(end)-recs(1)+1 Nt]) ...
        + 1i*ncread(cdf_fn,'chan_equalQ',[recs(1) 1],[recs(end)-recs(1)+1 Nt]);
      
      data{img}(1:wfs(wf).Nt_raw,:,wf_adc_idx) = data{img}(1:wfs(wf).Nt_raw,:,wf_adc_idx) ...
        .*interp1(reshape(chan_equal.gps_time,[numel(chan_equal.gps_time) 1]),chan_equal.chan_equal,records.gps_time,'linear','extrap').';
    end
  end
end

%% Add record information
% =========================================================================
hdr.gps_time = fir_dec(records.gps_time,param.load.presums);
hdr.surface = fir_dec(records.surface,param.load.presums);
hdr.gps_source = records.gps_source;
orig_records = records;
  
for img = 1:length(param.load.imgs)
  
  for wf_adc_idx = 1:size(data{img},3)
    wf = param.load.imgs{img}(wf_adc_idx,1);
    adc = param.load.imgs{img}(wf_adc_idx,2);
    
    if isempty(param.load_data.lever_arm_fh)
      records = orig_records;
      hdr.records{img}.lat(1,:,wf_adc_idx) = fir_dec(records.lat,param.load.presums);
      hdr.records{img}.lon(1,:,wf_adc_idx) = fir_dec(records.lon,param.load.presums);
      hdr.records{img}.elev(1,:,wf_adc_idx) = fir_dec(records.elev,param.load.presums);
      hdr.records{img}.roll(1,:,wf_adc_idx) = fir_dec(records.roll,param.load.presums);
      hdr.records{img}.pitch(1,:,wf_adc_idx) = fir_dec(records.pitch,param.load.presums);
      hdr.records{img}.heading(1,:,wf_adc_idx) = fir_dec(records.heading,param.load.presums);
    else
      % Create actual trajectory
      trajectory_param = struct('gps_source',orig_records.gps_source, ...
        'season_name',param.season_name,'radar_name',param.radar_name, ...
        'rx_path', wfs(wf).rx_paths(adc), ...
        'tx_weights', wfs(wf).tx_weights, 'lever_arm_fh', param.csarp.lever_arm_fh);
      records = trajectory_with_leverarm(orig_records,trajectory_param);
      hdr.records{img}.lat(1,:,wf_adc_idx) = fir_dec(records.lat,param.load.presums);
      hdr.records{img}.lon(1,:,wf_adc_idx) = fir_dec(records.lon,param.load.presums);
      hdr.records{img}.elev(1,:,wf_adc_idx) = fir_dec(records.elev,param.load.presums);
      hdr.records{img}.roll(1,:,wf_adc_idx) = fir_dec(records.roll,param.load.presums);
      hdr.records{img}.pitch(1,:,wf_adc_idx) = fir_dec(records.pitch,param.load.presums);
      hdr.records{img}.heading(1,:,wf_adc_idx) = fir_dec(records.heading,param.load.presums);
    end
  end
end

