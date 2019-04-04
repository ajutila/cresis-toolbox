% function [hdr,data] = basic_load_cresis(fn,fparam)

tic;
hdr = [];
data = [];

fn = 'mcords3_0_20190328_161057_00_0081.bin';
fparam.file_version = 403;
fparam.clk = 1e9/9;
fparam.recs = [0 inf];
fparam.first_byte = 0;

%% Input checks
% =========================================================================
if ~exist('param','var') || isempty(param)
  param = [];
end
% .clk: scalar in Hz and is used to interpret seconds counter fields in the
% file, default is 1 which is not correct for any radar system meaning that
% counts will all be interpretted incorrectly but at least the file can be
% loaded. Usually clk is equal to the ADC sampling clock or the clock
% divided by an integer.
if ~isfield(param,'clk') || isempty(param.clk)
  param.clk = 1;
end
% .expected_rec_sizes: vector of positive integers representing allowed
% record sizes in bytes. Only used for file formats 3, 5, 6, 7.
if ~isfield(param,'expected_rec_sizes') || isempty(param.expected_rec_sizes)
  param.expected_rec_sizes = [];
end
% .file_version: scalar positive integer indicating the raw file version
if ~isfield(param,'file_version') || isempty(param.file_version)
  param.file_version = 7;
end
% .fs: scalar sampling frequency in Hz. Often equal to param.clk (which is
% the default setting), but sometimes a multiple of param.clk. Used to
% determine the time axis.
if ~isfield(param,'fs') || isempty(param.fs)
  param.fs = param.clk;
end
% .samples_per_index: scalar that determines how many ADC samples there are
% per index, used to interpret the start_index field, usually equal to 1
% (the default setting). Used to determine how many samples per index. This
% field is only used by file version 8 and 11.
if ~isfield(param,'samples_per_index') || isempty(param.samples_per_index)
  param.samples_per_index = 1;
end
% .last_record: default is empty, this is a vector of samples containing
% the last record (usually incomplete) from the previous file
if ~isfield(param,'last_record') || isempty(param.last_record)
  param.last_record = [];
end
% .recs: 2 element vector containing the start record to load
% (zero-indexed) and the number of records to load. Default is [0 inf].
if ~isfield(param,'recs') || isempty(param.recs)
  param.recs = [0 inf];
end
if numel(param.recs) == 1
  params.recs = param.recs([1 1]);
end
% .sync: 8 character hex string, overrides the default file sync field.
% Default is empty. Typical values are 'DEADBEEF', 'BADA55E5', and
% '1ACFFC1D'.
if ~isfield(param,'sync') || isempty(param.sync)
  param.sync = [];
end

if any(param.file_version == [1 401])
  fparam.file_version = param.file_version;
  fparam.data_type = 'uint16';
  fparam.fread_data_type = 'uint16=>uint16';
  fparam.fh_data_type = @uint16;
  fparam.endian = 'ieee-be';
  fparam.sync = 'DEADBEEF';
  fparam.last_samples = param.last_samples;
end

if any(param.file_version == [2 3 4 5 6 7 8 11 402 403 404 407 408])
  fparam.file_version = param.file_version;
  fparam.data_type = 'int16';
  fparam.fread_data_type = 'int16=>int16';
  fparam.fh_data_type = @int16;
  fparam.endian = 'ieee-be';
  if any(param.file_version == [7 11 407 408])
    fparam.sync = '1ACFFC1D';
  else
    fparam.sync = 'BADA55E5';
  end
  fparam.last_samples = param.last_samples;
end

if ~isempty(param.sync)
  fparam.sync = param.sync;
end
if ~isempty(fparam.sync)
  fparam.sync = '1ACFFC1D';
end

%% Header
% =========================================================================
hdr.finfo = dir(fn);
if any(fparam.file_version == [405 406 410])
  % 405 (acords v1), 406 (acords v2), 410 (mcrds)
  % File format does not use sync markers
else
  % File format uses 32 bit sync markers
  fparam.sync1 = typecast(uint16(hex2dec(fparam.sync([1:4]))), fparam.data_type);
  fparam.sync2 = typecast(uint16(hex2dec(fparam.sync([5:8]))), fparam.data_type);
end

syncs_check = get_first10_sync_mfile(fn,fparam.first_byte,struct('sync',fparam.sync)); % DEBUG

% Open file
[fid,msg] = fopen(fn,'rb',fparam.endian);
if fid < 1
  fprintf('Could not open file %s\n', fn);
  error(msg);
end

% Read entire file in (appending it to the last samples read from the last
% file if any)
raw_file_data = [fparam.last_record fread(fid,inf,fparam.fread_data_type)];

% Close file
fclose(fid);

toc; % DEBUG

% Find record syncs
hdr.offsets = 2*find(raw_file_data(1:2:end-mod(numel(data),2)) == fparam.sync1 ...
  & raw_file_data(2:2:end) == fparam.sync2) - 1;

if isempty(hdr.offsets)
  error('No records syncs (32 bit sequence equal to 0x%s) found. There should be a sync at the beginning of every record.', fparam.sync);
end

rec_sizes = diff(hdr.offsets);
if any(fparam.file_version == [3 5 6 7])
  % Variable record size
  hdr.finfo.rec_size = rec_sizes;
  rec_sizes = unique(rec_sizes);
  
  % User must supply the valid record sizes
  if isempty(param.expected_rec_sizes)
    fprintf('Record sizes found in this file:\n');
    for idx = 1:length(rec_sizes)
      num_rec_sizes = sum(hdr.finfo.rec_size==rec_sizes(idx));
      if num_rec_sizes < 10
        fprintf('  Record size %d only occurs %d times (do not recommend for param.expected_rec_sizes)', 2*rec_sizes(idx), num_rec_sizes);
      else
        fprintf('  Record size %d occurs %d times (recommend for param.expected_rec_sizes)', 2*rec_sizes(idx), num_rec_sizes);
      end
    end
    fprintf('\n');
    error('For file version 3, 5, 6, and 7, expected record sizes must be supplied in param.expected_rec_sizes. You can start by using the record sizes listed here, but there may be other valid record sizes and these record sizes could be invalid and the output of this function should be monitored.');
  end
  expected_rec_size = param.config.cresis.expected_rec_sizes/2;
  bad_recs_mask = all(bsxfun(@(x,y) x ~= y, hdr.finfo.rec_size, expected_rec_size(:)),1);
  if any(bad_recs_mask)
    fprintf('Record sizes in bytes found in this file:\n');
    for idx = 1:length(rec_sizes)
      num_rec_sizes = sum(hdr.finfo.rec_size==rec_sizes(idx));
      if num_rec_sizes < 10
        fprintf('  Record size %d only occurs %d times (do not recommend for param.expected_rec_sizes)', 2*rec_sizes(idx), num_rec_sizes);
      else
        fprintf('  Record size %d occurs %d times (recommend for param.expected_rec_sizes)', 2*rec_sizes(idx), num_rec_sizes);
      end
    end
    fprintf('\n');
    fprintf('Record sizes aleady listed in param.expected_rec_sizes:\n');
    fprintf('  %d', param.expected_rec_sizes);
    fprintf('\n');
    warning('For file version 3, 5, 6, and 7, expected record sizes must be supplied in param.expected_rec_sizes. %d records do not match the sizes specified and these will not be loaded. If some of these record sizes are correct, add them to param.expected_rec_size.', sum(bad_recs_mask));
    hdr.offset = hdr.offset(~bad_recs_mask);
  end
  
  hdr.finfo.rec_size = diff(hdr.offsets);
  
else
  % Fixed record size
  hdr.finfo.rec_size = median(rec_sizes);
  bad_recs_mask = rec_sizes ~= hdr.finfo.rec_size;
  if any(bad_recs_mask)
    warning('Found sync marks with variable spacing which indicates the record lengths vary. Record sizes for this file version (%d) must be constant. The most frequency record size is taken to be the correct record size (%d). However, %d records had record sizes different than this. These records will not be loaded.', fparam.file_version, hdr.finfo.rec_size, sum(bad_recs_mask));
    hdr.offset = hdr.offset(~bad_recs_mask);
  end
end
hdr.finfo.rec_size = 2*hdr.finfo.rec_size;

toc; % DEBUG

% Remove last_record from file since it is usually incomplete and should
% generally be loaded with the subsequently recorded file by passing
hdr.last_record = raw_file_data(hdr.offsets(end):end);
hdr.offsets = hdr.offsets(1:end-1);

% Read in standard headers
if any(fparam.file_version == [1])
  %% Read standard headers 1
  % =======================================================================
  hdr.epri = uint32(raw_file_data(hdr.offsets+2))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+3));
  hdr.seconds = uint32(raw_file_data(hdr.offsets+8))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+9));
  hdr.fraction = uint32(raw_file_data(hdr.offsets+10))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+11));
  
elseif any(fparam.file_version == [2, 3, 5, 6, 7, 8, 11, 402, 403])
  %% Read standard headers 2, 3, 5, 6, 7, 8, 11, 402, 403
  % =======================================================================
  hdr.epri = uint32(typecast(raw_file_data(hdr.offsets+2),'uint16'))*2^16 ...
    + uint32(typecast(raw_file_data(hdr.offsets+3),'uint16'));
  hdr.seconds = uint32(typecast(raw_file_data(hdr.offsets+4),'uint16'))*2^16 ...
    + uint32(typecast(raw_file_data(hdr.offsets+5),'uint16'));
  hdr.fraction = uint32(typecast(raw_file_data(hdr.offsets+6),'uint16'))*2^16 ...
    + uint32(typecast(raw_file_data(hdr.offsets+7),'uint16'));
  if fparam.file_version ~= 2
    hdr.seconds = BCD_to_seconds(hdr.seconds);
    hdr.counter = uint64(typecast(raw_file_data(hdr.offsets+8),'uint16'))*2^48 ...
      + uint64(typecast(raw_file_data(hdr.offsets+9),'uint16'))*2^32 ...
      + uint64(typecast(raw_file_data(hdr.offsets+10),'uint16'))*2^16 ...
      + uint64(typecast(raw_file_data(hdr.offsets+11),'uint16'));
  end
  
elseif any(fparam.file_version == [4])
  %% Read standard headers 4
  % =======================================================================
  hdr.epri = uint32(typecast(raw_file_data(hdr.offsets+2),'uint16'))*2^16 ...
    + uint32(typecast(raw_file_data(hdr.offsets+3),'uint16'));
  % Convert seconds from NMEA ASCII string
  %   64 bits: 00 HH MM SS
  %   ASCII zero is "48"
  hours = typecast(raw_file_data(hdr.offsets+5),'uint16');
  minutes = typecast(raw_file_data(hdr.offsets+6),'uint16');
  seconds = typecast(raw_file_data(hdr.offsets+7),'uint16');
  hdr.seconds = bitshift(hours,-8)*36000 + bitand(255,hours)*3600  ...
    + bitshift(minutes,-8)*600 + bitand(255,minutes)*60  ...
    + bitshift(seconds,-8)*10 + bitand(255,seconds);
  hdr.fraction = uint64(typecast(raw_file_data(hdr.offsets+8),'uint16'))*2^48 ...
    + uint64(typecast(raw_file_data(hdr.offsets+9),'uint16'))*2^32 ...
    + uint64(typecast(raw_file_data(hdr.offsets+10),'uint16'))*2^16 ...
    + uint64(typecast(raw_file_data(hdr.offsets+11),'uint16'));
  hdr.counter = uint64(typecast(raw_file_data(hdr.offsets+12),'uint16'))*2^48 ...
    + uint64(typecast(raw_file_data(hdr.offsets+13),'uint16'))*2^32 ...
    + uint64(typecast(raw_file_data(hdr.offsets+14),'uint16'))*2^16 ...
    + uint64(typecast(raw_file_data(hdr.offsets+15),'uint16'));

elseif any(fparam.file_version == [401])
  %% Read standard headers 401
  % =======================================================================
  hdr.epri = uint32(raw_file_data(hdr.offsets+8))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+9));
  hdr.seconds = uint32(raw_file_data(hdr.offsets+4))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+5));
  hdr.fraction = uint32(raw_file_data(hdr.offsets+6))*2^16 ...
    + uint32(raw_file_data(hdr.offsets+7));
  
elseif any(fparam.file_version == [404 407 408])
  %% Read standard headers 404, 407, 408
  % =======================================================================
  hdr.epri = uint32(typecast(raw_file_data(hdr.offsets+2),'uint16'))*2^16 ...
    + uint32(typecast(raw_file_data(hdr.offsets+3),'uint16'));
  if fparam.file_version == 408
    hdr.seconds = uint32(typecast(raw_file_data(hdr.offsets+16),'uint16'))*2^16 ...
      + uint32(typecast(raw_file_data(hdr.offsets+17),'uint16'));
    hdr.fraction = uint32(typecast(raw_file_data(hdr.offsets+18),'uint16'))*2^16 ...
      + uint32(typecast(raw_file_data(hdr.offsets+19),'uint16'));
    hdr.counter = uint64(typecast(raw_file_data(hdr.offsets+24),'uint16'))*2^48 ...
      + uint64(typecast(raw_file_data(hdr.offsets+25),'uint16'))*2^32 ...
      + uint64(typecast(raw_file_data(hdr.offsets+26),'uint16'))*2^16 ...
      + uint64(typecast(raw_file_data(hdr.offsets+27),'uint16'));
  else
    hdr.seconds = uint32(typecast(raw_file_data(hdr.offsets+8),'uint16'))*2^16 ...
      + uint32(typecast(raw_file_data(hdr.offsets+9),'uint16'));
    hdr.fraction = uint32(typecast(raw_file_data(hdr.offsets+10),'uint16'))*2^16 ...
      + uint32(typecast(raw_file_data(hdr.offsets+11),'uint16'));
    hdr.counter = uint64(typecast(raw_file_data(hdr.offsets+12),'uint16'))*2^48 ...
      + uint64(typecast(raw_file_data(hdr.offsets+13),'uint16'))*2^32 ...
      + uint64(typecast(raw_file_data(hdr.offsets+14),'uint16'))*2^16 ...
      + uint64(typecast(raw_file_data(hdr.offsets+15),'uint16'));
  end
  hdr.seconds = BCD_to_seconds(hdr.seconds);

elseif any(fparam.file_version == [405 406 410])
  %% Read standard headers 405, 406, 410
  % =======================================================================
  
end

if any(fparam.file_version == [1])
  %% Read waveforms 1
  % =======================================================================
  Nx = length(hdr.offsets);
  Nt = hdr.finfo.rec_size/2 - 16;

  wf = 1;
  hdr.wfs(wf).Nt = repmat(Nt,[1 Nx]);
  data{wf} = zeros(Nt,Nx,'single');
  for rec = 1:Nx
    data{wf}(:,rec) = raw_file_data(hdr.offsets(rec)+wf_offset + (0:Nt-1));
  end
  presums = 4;
  bit_shifts = 0;
  data{wf} = single(data{wf}) - 2^13*presums/2^bit_shifts;
  
elseif any(fparam.file_version == [2 3 4 5 6])
  %% Read waveforms 2 3 4 5 6
  % =======================================================================
  Nx = length(hdr.offsets);
  
  hdr.wfs.presums = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+17+wf_offset),'uint16'),-8));
  hdr.wfs.bit_shifts = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+17+wf_offset),'uint16')),'int8');
  hdr.wfs.bit_shifts = hdr.wfs.bit_shifts(1:2:end);
  hdr.wfs.start_idx = typecast(raw_file_data(hdr.offsets+18+wf_offset),'uint16');
  stop_idx = typecast(raw_file_data(hdr.offsets+19+wf_offset),'uint16');
  
  if any(fparam.file_version == [3 5 6])
    % Read in DDC fields
    hdr.wfs.DC_offset = typecast(raw_file_data(hdr.offsets+20),'uint16');
    hdr.wfs.DDC_freq = typecast(raw_file_data(hdr.offsets+21),'uint16');
    if file_version == 6
      hdr.wfs.switch = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+22+wf_offset),'uint16'),-8));
    else
      hdr.wfs.nyquist_zone = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+22+wf_offset),'uint16'),-8));
    end
    hdr.wfs.DDC_dec = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+22+wf_offset),'uint16')),'int8');
    hdr.wfs.DDC_dec = 2.^hdr.wfs.DDC_dec(1:2:end);
    hdr.wfs.complex = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+23+wf_offset),'uint16')),'int8');
    hdr.wfs.complex = ~hdr.wfs.complex(1:2:end);
    % Override decimation if not enabled
    hdr.wfs.DDC_dec(~hdr.wfs.complex) = 1;
    
    hdr.wfs.Nt = (stop_idx - hdr.wfs.start_idx);
    Nt = double(median(hdr.wfs.Nt));
    hdr.wfs.Nt = floor(Nt ./ hdr.wfs.DDC_dec);
    Nt = max(hdr.wfs.Nt);
    data{1} = zeros(Nt,Nx,'int16');
    for rec = 1:Nx
      if hdr.wfs.complex(rec)
        data{1}(1:hdr.wfs.Nt(rec),rec) = raw_file_data(hdr.offsets(rec)+24 + (0:2:2*Nt-1)) ...
          + 1i*raw_file_data(hdr.offsets(rec)+24+wf_offset + (1:2:2*Nt-1));
      else
        data{1}(:,rec) = reshape([raw_file_data(hdr.offsets(rec)+24 + (1:2:Nt-1)); ...
          raw_file_data(hdr.offsets(rec)+24+wf_offset + (0:2:Nt-1))], [Nt 1]);
      end
    end

  else % file_version == 2 4
    hdr.wfs.Nt = stop_idx - hdr.wfs.start_idx;
    Nt = double(median(hdr.wfs.Nt));
    data{1} = zeros(Nt,Nx,'int16');
    for rec = 1:Nx
      data{1}(:,rec,:) = raw_file_data(hdr.offsets(rec)+20 + (0:Nt-1));
    end
    hdr.wfs.Nt(:) = Nt;
  end
  data{1} = single(data{1});
  
elseif any(fparam.file_version == [7 8 11])
  %% Read waveforms 7, 8, 11
  % =======================================================================
  num_wfs = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+13),'uint16')),'int8');
  num_wfs = median(num_wfs(1:2:end));
  Nx = length(hdr.offsets);
  
  % Get the file version from the file
  file_version = typecast(raw_file_data(hdr.offsets+12),'uint16');
  file_version = median(file_version);
  if  all(file_version ~= [7 8 11])
    error('param.file_version must be set. It cannot be read from this file because the file''s file version field (%d) has an invalid value.', file_version);
  end
  fparam.file_version = file_version;
  hdr.file_version = file_version;

  wf_offset = 0;
  for wf = 1:num_wfs
    hdr.wfs(wf).presums = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+17+wf_offset),'uint16'),-8));
    hdr.wfs(wf).bit_shifts = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+17+wf_offset),'uint16')),'int8');
    hdr.wfs(wf).bit_shifts = hdr.wfs(wf).bit_shifts(1:2:end);
    hdr.wfs(wf).start_idx = typecast(raw_file_data(hdr.offsets+18+wf_offset),'uint16');
    stop_idx = typecast(raw_file_data(hdr.offsets+19+wf_offset),'uint16');
    if fparam.file_version == 7
      % Read in switch setting
      hdr.wfs(wf).switch = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+13+wf_offset),'uint16'),-8));
      % Read in DDC fields
      hdr.wfs(wf).DC_offset = typecast(raw_file_data(hdr.offsets+20),'uint16');
      hdr.wfs(wf).DDC_freq = typecast(raw_file_data(hdr.offsets+21),'uint16');
      hdr.wfs(wf).nyquist_zone = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+22+wf_offset),'uint16'),-8));
      hdr.wfs(wf).DDC_dec = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+22+wf_offset),'uint16')),'int8');
      hdr.wfs(wf).DDC_dec = 2.^hdr.wfs(wf).DDC_dec(1:2:end);
      hdr.wfs(wf).complex = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+23+wf_offset),'uint16')),'int8');
      hdr.wfs(wf).complex = ~hdr.wfs(wf).complex(1:2:end);
      % Override decimation if not enabled
      hdr.wfs(wf).DDC_dec(~hdr.wfs(wf).complex) = 1;
    else % file_version == 8 11
      % Read in multifield with number of channels and nyquist zone
      multifield = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+16+wf_offset),'uint16'),-8));
      multifield = multifield(1:2:end);
      Nc = bitand(3,bitshift(multifield,-2));
      Nc = median(Nc);
      hdr.wfs(wf).nyquist_zone = bitand(3,multifield);
      if fparam.file_version == 8
        % Read in waveform ID
        hdr.wfs(wf).waveform_ID = uint64(typecast(raw_file_data(hdr.offsets+20),'uint16'))*2^48 ...
          + uint64(typecast(raw_file_data(hdr.offsets+21),'uint16'))*2^32 ...
          + uint64(typecast(raw_file_data(hdr.offsets+22),'uint16'))*2^16 ...
          + uint64(typecast(raw_file_data(hdr.offsets+23),'uint16'));
      end
    end
    if fparam.file_version == 7
      hdr.wfs(wf).Nt = (stop_idx - hdr.wfs(wf).start_idx);
      Nt = double(median(hdr.wfs(wf).Nt));
      hdr.wfs(wf).Nt = floor(Nt ./ hdr.wfs(wf).DDC_dec));
      Nt = max(hdr.wfs(wf).Nt);
      data{wf} = zeros(Nt,Nx,'int16');
      if hdr.complex(rline_out)
        % Complex data
        for rec = 1:Nx
          data{wf}(1:hdr.wfs(wf).Nt,rec) = raw_file_data(hdr.offsets(rec)+24+wf_offset + (0:2:Nt-1)) ...
            + 1i*raw_file_data(hdr.offsets(rec)+24+wf_offset + (1:2:Nt-1));
        end
      else
        % Real data
        for rec = 1:Nx
          data{wf}(:,rec) = reshape([raw_file_data(hdr.offsets(rec)+24+wf_offset + (1:2:Nt-1)); ...
             raw_file_data(hdr.offsets(rec)+24+wf_offset + (0:2:Nt-1))], [Nt 1]);
        end
      end
      wf_offset = wf_offset + 24 + Nt;
      hdr.wfs(wf).Nt(:) = Nt;
      data{wf} = single(data{wf});
      
    else
      hdr.wfs(wf).Nt = stop_idx - hdr.wfs(wf).start_idx;
      Nt = double(median(hdr.wfs(wf).Nt));
      wf_offset = wf_offset + 24 + Nc*Nt;
      data{wf} = zeros(Nt,Nx,Nc,'int16');
      for rec = 1:Nx
        data{wf}(:,rec,:) = reshape(raw_file_data(hdr.offsets(rec)+24+wf_offset + (0:Nc*Nt-1)), [Nc Nt]).';
      end
      hdr.wfs(wf).Nt(:) = Nt;
      data{wf} = single(data{wf});
    end
  end
  
elseif any(fparam.file_version == [401])
  %% Read waveforms 401
  % =======================================================================
  num_wfs = bitand(uint16(255),raw_file_data(hdr.offsets+10));
  num_wfs = median(num_wfs);
  Nx = length(hdr.offsets);

  % Read in header for each waveform
  wf_offset = 16;
  for wf = 1:num_wfs
    hdr.wfs(wf).Nt = uint32(raw_file_data(hdr.offsets+wf_offset+0))*2^16 ...
      + uint32(raw_file_data(hdr.offsets+wf_offset+1));
    multifield = uint32(raw_file_data(hdr.offsets+wf_offset+2))*2^16 ...
      + uint32(raw_file_data(hdr.offsets+wf_offset+3));
    hdr.wfs(wf).bit_shifts = bitand(31,bitshift(multifield,-24));
    hdr.wfs(wf).start_idx = bitand(16383,bitshift(multifield,-10));
    hdr.wfs(wf).presums = bitand(1023,multifield);
    wf_offset = wf_offset + 4;
  end
  
  % Read in data for each waveform
  wf_offset = 80;
  for wf = 1:num_wfs
    Nt = double(median(hdr.wfs(wf).Nt));
    hdr.wfs(wf).Nt(:) = Nt;
    data{wf} = zeros(Nt,Nx,'int16');
    for rec = 1:Nx
      data{wf}(:,rec) = raw_file_data(hdr.offsets(rec)+wf_offset + (0:Nt-1));
    end
    data{wf} = single(data{wf}) - 2^13*hdr.wfs(wf).presums/2^hdr.wfs(wf).bit_shifts;
    wf_offset = wf_offset + Nt;
  end
  
elseif any(fparam.file_version == [402 403])
  %% Read waveforms 402, 403
  % =======================================================================
  num_wfs = 1+bitand(uint16(255),typecast(raw_file_data(hdr.offsets+16),'uint16'));
  num_wfs = median(num_wfs);
  Nx = length(hdr.offsets);

  wf_offset = 17;
  Nc = 4;
  for wf = 1:num_wfs
    hdr.wfs(wf).presums = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+wf_offset),'uint16'),-8));
    hdr.wfs(wf).bit_shifts = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+wf_offset),'uint16')),'int8');
    hdr.wfs(wf).bit_shifts = hdr.wfs(wf).bit_shifts(1:2:end);
    hdr.wfs(wf).start_idx = typecast(raw_file_data(hdr.offsets+1+wf_offset),'uint16');
    stop_idx = typecast(raw_file_data(hdr.offsets+2+wf_offset),'uint16');
    hdr.wfs(wf).Nt = stop_idx - hdr.wfs(wf).start_idx;
    Nt = double(median(hdr.wfs(wf).Nt));
    hdr.wfs(wf).Nt(:) = Nt;
    wf_offset = wf_offset + 4 + Nc*Nt;
    data{wf} = zeros(Nt,Nx,Nc,'int16');
    for rec = 1:Nx
      data{wf}(:,rec,:) = reshape(raw_file_data(hdr.offsets(rec)+20+wf_offset + (0:Nc*Nt-1)), [Nc Nt]).';
    end
    data{wf} = single(data{wf});
  end
  
elseif any(fparam.file_version == [404 407 408])
  %% Read waveforms 404, 407, 408
  % =======================================================================
  if fparam.file_version == 408
    num_wfs = 1+bitand(uint16(255),typecast(raw_file_data(hdr.offsets+40),'uint16'));
    wf_offset = 41;
    data_offset = 8;
  else % file_version == 404, 407
    num_wfs = 1+bitand(uint16(255),typecast(raw_file_data(hdr.offsets+20),'uint16'));
    wf_offset = 21;
    data_offset = 4;
  end
  num_wfs = median(num_wfs);
  Nx = length(hdr.offsets);
    
  for wf = 1:num_wfs
    if fparam.file_version == 408
      hdr.wfs(wf).presums = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+wf_offset),'uint16'),-8));
      hdr.wfs(wf).bit_shifts = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+wf_offset),'uint16')),'int8');
      hdr.wfs(wf).bit_shifts = hdr.wfs(wf).bit_shifts(1:2:end);
      hdr.wfs(wf).start_idx = typecast(raw_file_data(hdr.offsets+1+wf_offset),'uint16');
      stop_idx = typecast(raw_file_data(hdr.offsets+2+wf_offset),'uint16');
      hdr.wfs(wf).Nt = 8 * (stop_idx - hdr.wfs(wf).start_idx);
    else % file_version == 404, 407
      hdr.wfs(wf).presums = bitand(uint16(255),bitshift(typecast(raw_file_data(hdr.offsets+wf_offset),'uint16'),-8));
      hdr.wfs(wf).bit_shifts = typecast(bitand(uint16(255),typecast(raw_file_data(hdr.offsets+wf_offset),'uint16')),'int8');
      hdr.wfs(wf).bit_shifts = hdr.wfs(wf).bit_shifts(1:2:end);
      hdr.wfs(wf).start_idx = typecast(raw_file_data(hdr.offsets+1+wf_offset),'uint16');
      stop_idx = typecast(raw_file_data(hdr.offsets+2+wf_offset),'uint16');
      if fparam.file_version == 407
        hdr.wfs(wf).DDC_dec = 2.^(typecast(raw_file_data(hdr.offsets+5),'uint16')+1);
        hdr.wfs(wf).Nt = 16/hdr.wfs(wf).DDC_dec * (stop_idx - hdr.wfs(wf).start_idx);
      else % file_version == version 404
        hdr.wfs(wf).Nt = 4 * (stop_idx - hdr.wfs(wf).start_idx);
      end
    end
    Nt = double(median(hdr.wfs(wf).Nt));
    wf_offset = wf_offset + 4 + Nt;
    data{wf} = zeros(Nt,Nx,'int16');
    for rec = 1:Nx
      data{wf}(:,rec) = raw_file_data(hdr.offsets(rec)+data_offset+wf_offset + (0:Nt-1));
    end
    hdr.wfs(wf).Nt(:) = Nt;
    data{wf} = single(data{wf});
  end
  
end



toc; % DEBUG

return

% tic; [hdr2,data2] = basic_load_mcords3(fn); toc;
% dec2hex(hdr2.epri(1))

% 82F32
% syncs = find(data(1:2:end-mod(numel(data),2)) == fparam.sync1 ...
%   & data(2:2:end) == fparam.sync2);
if numel(hdr.offsets) < 20
  keyboard
  hdr.offsets = find(raw_file_data(2:2:end-1-mod(numel(data),2)) == fparam.sync1 ...
    & raw_file_data(3:2:end-1) == fparam.sync2);
  if numel(hdr.offsets) < 20
    keyboard
  end
end

toc;


