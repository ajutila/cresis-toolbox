  
%% Flightline Data Interpolation - Zachariae Isstrom Line 1
% Years: 2010, 2010DC8, 2014A, 2014B, 2016, 2017, 2018, 2019
% Author: Cody Barnett
%
% Load elevation and along track data from run_combine_passes.m that has
% been velocity corrected by velocity_coregister.m into a new structure
% for comparison. 
% Section 1 - load data into new struct and apply velocity correction to
% each along track profile from pass struct in previous functions.
% Section 2 - Mask out regions where there is no overlap and then clip 
% both the along track and elevation data to the correct sizes, with
% excess data being removed for non-overlap regions between years
% Section 3 - create query points for the both the beginning and ends of
% the profiles using points from both sides of the cut off profiles. Query
% points and elevation data is then interpolated to match the dimensions
% of the compared year data. Melt rates as then derived from this new
% resampled sections. 
 
%Make AT_data structure and save Bed, Surface, Along_track data
AT_data = struct('pass', [], 'vel', [], 'elevB', [], 'elevS', [],...
'elev_pad', [], 'elev_NC',[], 'Btrack', []);
%Save Bottom profiles
AT_data.elevB.P2010 = (pass(1).layers(2).layer_elev);
%AT_data.elevB.P2010DC8 = (pass(2).layers(2).layer_elev);
AT_data.elevB.P2014A = (pass(2).layers(2).layer_elev);
%AT_data.elevB.P2014B = (pass(4).layers(2).layer_elev);
AT_data.elevB.P2016 = (pass(3).layers(2).layer_elev);
AT_data.elevB.P2017 = (pass(4).layers(2).layer_elev);
AT_data.elevB.P2018 = (pass(5).layers(2).layer_elev);
AT_data.elevB.P2019 = pass(6).layers(2).layer_elev);

%Save Surface profiles
AT_data.elevS.P2010 = (pass(1).layers(1).layer_elev);
%AT_data.elevS.P2010DC8 = (pass(2).layers(1).layer_elev);
AT_data.elevS.P2014A = (pass(2).layers(1).layer_elev);
%AT_data.elevS.P2014B = (pass(4).layers(1).layer_elev);
AT_data.elevS.P2016 = (pass(3).layers(1).layer_elev);
AT_data.elevS.P2017 = (pass(4).layers(1).layer_elev);
AT_data.elevS.P2018 = (pass(5).layers(1).layer_elev);
AT_data.elevS.P2019 = (pass(6).layers(1).layer_elev);

%Save annual alongtrack profile data
AT_data.pass.P2010 = pass(1).along_track;
%AT_data.pass.P2010DC8 = pass(2).along_track;
AT_data.pass.P2014A = pass(2).along_track;
%AT_data.pass.P2014B = pass(4).along_track;
AT_data.pass.P2016 = pass(3).along_track;
AT_data.pass.P2017 = pass(4).along_track;
AT_data.pass.P2018 = pass(5).along_track;
AT_data.pass.P2019 = pass(6).along_track;

%Save annual velocity correction data
AT_data.vel.P2010 = pass(1).vel;
%AT_data.vel.P2010DC8 = pass(2).vel;
AT_data.vel.P2014A = pass(2).vel;
%AT_data.vel.P2014B = pass(4).vel;
AT_data.vel.P2016 = pass(3).vel;
AT_data.vel.P2017 = pass(4).vel;
AT_data.vel.P2018 = pass(5).vel;
AT_data.vel.P2019 = pass(6).vel;

%Save Velocity Corrected Along_track data
AT_data.AT_vel.P2010 = pass(baseline_master_idx).along_track + pass(1).vel;
%AT_data.AT_vel.P2010DC8 = pass(baseline_master_idx).along_track + pass(2).vel;
AT_data.AT_vel.P2014A = pass(baseline_master_idx).along_track + pass(2).vel;
%AT_data.AT_vel.P2014B = pass(baseline_master_idx).along_track + pass(4).vel;
AT_data.AT_vel.P2016 = pass(baseline_master_idx).along_track + pass(3).vel;
AT_data.AT_vel.P2017 = pass(baseline_master_idx).along_track + pass(4).vel;
AT_data.AT_vel.P2018 = pass(baseline_master_idx).along_track + pass(5).vel;
AT_data.AT_vel.P2019 = pass(baseline_master_idx).along_track + pass(6).vel;

% Latitudes and longitudes (Adjust for the master pass)
AT_data.latitudes.P2010 = interp1(pass(1).lat, pass(1).lat, pass(2).lat);
% AT_data.latitudes.P2010DC8 = interp1(pass(1).lat, pass(1).lat, pass(2).lat);
AT_data.latitudes.P2014A = pass(2).lat;
% AT_data.latitudes.P2014B = interp1(pass(3).lat, pass(3).lat, pass(2).lat);
AT_data.latitudes.P2016 = interp1(pass(3).lat, pass(3).lat, pass(2).lat);
AT_data.latitudes.P2017 = interp1(pass(4).lat, pass(4).lat, pass(2).lat);
AT_data.latitudes.P2018 = interp1(pass(5).lat, pass(5).lat, pass(2).lat);
AT_data.latitudes.P2019 = interp1(pass(6).lat, pass(6).lat, pass(2).lat);

AT_data.longitudes.P2010 = interp1(pass(1).lon, pass(1).lon, pass(2).lon);
% AT_data.longitudes.P2010DC8 = interp1(pass(1).lon, pass(1).lon, pass(2).lon);
AT_data.longitudes.P2014A = pass(2).lon;
% AT_data.longitudes.P2014B = interp1(pass(3).lon, pass(3).lon, pass(2).lon);
AT_data.longitudes.P2016 = interp1(pass(3).lon, pass(3).lon, pass(2).lon);
AT_data.longitudes.P2017 = interp1(pass(4).lon, pass(4).lon, pass(2).lon);
AT_data.longitudes.P2018 = interp1(pass(5).lon, pass(5).lon, pass(2).lon);
AT_data.longitudes.P2019 = interp1(pass(6).lon, pass(6).lon, pass(2).lon);

%% Section 2 - Mask, indexing, and clipping of along track
  
% Locate Along Track start element in each profile, save element ID as a
% variable for the clipping
% 2010
AT_data.Btrack.P10 = AT_data.AT_vel.P2010(AT_data.AT_vel.P2010 >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P10 = find(AT_data.AT_vel.P2010 == ...
  AT_data.Btrack.P10(1));

% 2010 DC8
% AT_data.Btrack.P10DC8 = AT_data.AT_vel.P2010DC8(AT_data.AT_vel.P2010DC8 >= ...
%   AT_data.AT_vel.P2010(1));
% AT_data.find_AT_value.P10DC8 = find(AT_data.AT_vel.P2010DC8 == ...
%   AT_data.Btrack.P10DC8(1));

% 2014A  
AT_data.Btrack.P14A = AT_data.AT_vel.P2014A(AT_data.AT_vel.P2014A >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P14A = find(AT_data.AT_vel.P2014A == ...
  AT_data.Btrack.P14A(1));


% 2014B  
% AT_data.Btrack.P14B = AT_data.AT_vel.P2014B(AT_data.AT_vel.P2014B >= ...
%   AT_data.AT_vel.P2010(1));
% AT_data.find_AT_value.P14B = find(AT_data.AT_vel.P2014B == ...
%   AT_data.Btrack.P14B(1));

% 2016
AT_data.Btrack.P16 = AT_data.AT_vel.P2016(AT_data.AT_vel.P2016 >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P16 = find(AT_data.AT_vel.P2016 == ...
  AT_data.Btrack.P16(1));
  
% 2017 
AT_data.Btrack.P17 = AT_data.AT_vel.P2017(AT_data.AT_vel.P2017 >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P17 = find(AT_data.AT_vel.P2017 == ... 
  AT_data.Btrack.P17(1));

% 2018 
AT_data.Btrack.P18 = AT_data.AT_vel.P2018(AT_data.AT_vel.P2018 >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P18 = find(AT_data.AT_vel.P2018 == ... 
  AT_data.Btrack.P18(1));
  
% 2019 
AT_data.Btrack.P19 = AT_data.AT_vel.P2019(AT_data.AT_vel.P2019 >= ...
  AT_data.AT_vel.P2010(1));
AT_data.find_AT_value.P19 = find(AT_data.AT_vel.P2019 == ... 
  AT_data.Btrack.P19(1));

% Clipping from start point in each profile to the end of the profile
AT_data.Btrack_Beg_Clip.P10 = AT_data.AT_vel.P2010...
  (AT_data.find_AT_value.P10:end);
% AT_data.Btrack_Beg_Clip.P10DC8 = AT_data.AT_vel.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end);
AT_data.Btrack_Beg_Clip.P14A = AT_data.AT_vel.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.Btrack_Beg_Clip.P14B = AT_data.AT_vel.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.Btrack_Beg_Clip.P16 = AT_data.AT_vel.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.Btrack_Beg_Clip.P17 = AT_data.AT_vel.P2017...
 (AT_data.find_AT_value.P17:end);
AT_data.Btrack_Beg_Clip.P18 = AT_data.AT_vel.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.Btrack_Beg_Clip.P19 = AT_data.AT_vel.P2019...
 (AT_data.find_AT_value.P19:end);

% Clipping from new start locations to a given value end element value 
AT_data.Btrack_End_Clip.P10 = AT_data.Btrack_Beg_Clip.P10...
  (AT_data.Btrack_Beg_Clip.P10 <= 5.79e+04);
% AT_data.Btrack_End_Clip.P10DC8 = AT_data.Btrack_Beg_Clip.P10DC8...
%   (AT_data.Btrack_Beg_Clip.P10DC8 <= 5.79e+04);
AT_data.Btrack_End_Clip.P14A = AT_data.Btrack_Beg_Clip.P14A...
  (AT_data.Btrack_Beg_Clip.P14A <= 5.79e+04);
% AT_data.Btrack_End_Clip.P14B = AT_data.Btrack_Beg_Clip.P14B...
%   (AT_data.Btrack_Beg_Clip.P14B <= 5.79e+04);
AT_data.Btrack_End_Clip.P16 = AT_data.Btrack_Beg_Clip.P16...
  (AT_data.Btrack_Beg_Clip.P16 <= 5.79e+04);
AT_data.Btrack_End_Clip.P17 = AT_data.Btrack_Beg_Clip.P17...
  (AT_data.Btrack_Beg_Clip.P17 <= 5.79e+04); 
AT_data.Btrack_End_Clip.P18 = AT_data.Btrack_Beg_Clip.P18...
  (AT_data.Btrack_Beg_Clip.P18 <= 5.79e+04);
AT_data.Btrack_End_Clip.P19 = AT_data.Btrack_Beg_Clip.P19...
  (AT_data.Btrack_Beg_Clip.P19 <= 5.79e+04);  

% Save along track data size as variable to see if there is any errors
AT_data.array_size.P10_AT = size(AT_data.Btrack_End_Clip.P10);
%AT_data.array_size.P10DC8_AT = size(AT_data.Btrack_End_Clip.P10DC8);
AT_data.array_size.P14A_AT = size(AT_data.Btrack_End_Clip.P14A);
%AT_data.array_size.P14B_AT = size(AT_data.Btrack_End_Clip.P14B);
AT_data.array_size.P16_AT = size(AT_data.Btrack_End_Clip.P16);
AT_data.array_size.P17_AT = size(AT_data.Btrack_End_Clip.P17);
AT_data.array_size.P18_AT = size(AT_data.Btrack_End_Clip.P18);
AT_data.array_size.P19_AT = size(AT_data.Btrack_End_Clip.P19);

%% Elevation data Clipping to Section size of Along Track files
% Elevation data beginning clipping from start element in Along Track BED
AT_data.elev_Beg_Clip.P2010 = AT_data.elevB.P2010...
  (AT_data.find_AT_value.P10:end); 
% AT_data.elev_Beg_Clip.P2010DC8 = AT_data.elevB.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end); 
AT_data.elev_Beg_Clip.P2014A = AT_data.elevB.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.elev_Beg_Clip.P2014B = AT_data.elevB.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.elev_Beg_Clip.P2016 = AT_data.elevB.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.elev_Beg_Clip.P2017 = AT_data.elevB.P2017...
  (AT_data.find_AT_value.P17:end);
AT_data.elev_Beg_Clip.P2018 = AT_data.elevB.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.elev_Beg_Clip.P2019 = AT_data.elevB.P2019...
  (AT_data.find_AT_value.P19:end);  

% Elevation data end clipping from end of Along track data BED
AT_data.elev_End_Clip.P2010 = AT_data.elev_Beg_Clip.P2010...
  (1:length(AT_data.Btrack_End_Clip.P10));
% AT_data.elev_End_Clip.P2010DC8 = AT_data.elev_Beg_Clip.P2010DC8...
%   (1:length(AT_data.Btrack_End_Clip.P10DC8));
AT_data.elev_End_Clip.P2014A = AT_data.elev_Beg_Clip.P2014A...
  (1:length(AT_data.Btrack_End_Clip.P14));
% AT_data.elev_End_Clip.P2014B = AT_data.elev_Beg_Clip.P2014B...
%   (1:length(AT_data.Btrack_End_Clip.P14B));
AT_data.elev_End_Clip.P2016 = AT_data.elev_Beg_Clip.P2016...
  (1:length(AT_data.Btrack_End_Clip.P16));
AT_data.elev_End_Clip.P2017 = AT_data.elev_Beg_Clip.P2017...
  (1:length(AT_data.Btrack_End_Clip.P17));  
AT_data.elev_End_Clip.P2018 = AT_data.elev_Beg_Clip.P2018...
  (1:length(AT_data.Btrack_End_Clip.P18));
AT_data.elev_End_Clip.P2019 = AT_data.elev_Beg_Clip.P2019...
  (1:length(AT_data.Btrack_End_Clip.P19));  

% Elevation data beginning clipping from start element in Along Track SURF
AT_data.elev_Beg_Clip_SURF.P2010 = AT_data.elevS.P2010...
  (AT_data.find_AT_value.P10:end); 
% AT_data.elev_Beg_Clip_SURF.P2010DC8 = AT_data.elevS.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end); 
AT_data.elev_Beg_Clip_SURF.P2014A = AT_data.elevS.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.elev_Beg_Clip_SURF.P2014B = AT_data.elevS.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.elev_Beg_Clip_SURF.P2016 = AT_data.elevS.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.elev_Beg_Clip_SURF.P2017 = AT_data.elevS.P2017...
  (AT_data.find_AT_value.P17:end);
AT_data.elev_Beg_Clip_SURF.P2018 = AT_data.elevS.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.elev_Beg_Clip_SURF.P2019 = AT_data.elevS.P2019...
  (AT_data.find_AT_value.P19:end);  

% Elevation data end clipping from end of Along track data SURF
AT_data.elev_End_Clip_SURF.P2010 = AT_data.elev_Beg_Clip_SURF.P2010...
  (1:length(AT_data.Btrack_End_Clip.P10));
% AT_data.elev_End_Clip_SURF.P2010DC8 = AT_data.elev_Beg_Clip_SURF.P2010DC8...
%   (1:length(AT_data.Btrack_End_Clip.P10DC8));
AT_data.elev_End_Clip_SURF.P2014A = AT_data.elev_Beg_Clip_SURF.P2014A...
  (1:length(AT_data.Btrack_End_Clip.P14));
% AT_data.elev_End_Clip_SURF.P2014B = AT_data.elev_Beg_Clip_SURF.P2014B...
%   (1:length(AT_data.Btrack_End_Clip.P14B));
AT_data.elev_End_Clip_SURF.P2016 = AT_data.elev_Beg_Clip_SURF.P2016...
  (1:length(AT_data.Btrack_End_Clip.P16));
AT_data.elev_End_Clip_SURF.P2017 = AT_data.elev_Beg_Clip_SURF.P2017...
  (1:length(AT_data.Btrack_End_Clip.P17));  
AT_data.elev_End_Clip_SURF.P2018 = AT_data.elev_Beg_Clip_SURF.P2018...
  (1:length(AT_data.Btrack_End_Clip.P18));
AT_data.elev_End_Clip_SURF.P2019 = AT_data.elev_Beg_Clip_SURF.P2019...
  (1:length(AT_data.Btrack_End_Clip.P19));  

% Elevation data beginning clipping from start element in Along Track LAT
AT_data.elev_Beg_Clip_LAT.P2010 = AT_data.latitudes.P2010...
  (AT_data.find_AT_value.P10:end); 
% AT_data.elev_Beg_Clip_LAT.P2010DC8 = AT_data.latitudes.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end); 
AT_data.elev_Beg_Clip_LAT.P2014A = AT_data.latitudes.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.elev_Beg_Clip_LAT.P2014B = AT_data.latitudes.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.elev_Beg_Clip_LAT.P2016 = AT_data.latitudes.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.elev_Beg_Clip_LAT.P2017 = AT_data.latitudes.P2017...
  (AT_data.find_AT_value.P17:end);
AT_data.elev_Beg_Clip_LAT.P2018 = AT_data.latitudes.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.elev_Beg_Clip_LAT.P2019 = AT_data.latitudes.P2019...
  (AT_data.find_AT_value.P19:end);  

% Elevation data end clipping from end of Along track data LAT
AT_data.elev_End_Clip_LAT.P2010 = AT_data.elev_Beg_Clip_LAT.P2010...
  (1:length(AT_data.Btrack_End_Clip.P10));
% AT_data.elev_End_Clip_LAT.P2010DC8 = AT_data.elev_Beg_Clip_LAT.P2010DC8...
%   (1:length(AT_data.Btrack_End_Clip.P10DC8));
AT_data.elev_End_Clip_LAT.P2014A = AT_data.elev_Beg_Clip_LAT.P2014A...
  (1:length(AT_data.Btrack_End_Clip.P14));
% AT_data.elev_End_Clip_LAT.P2014B = AT_data.elev_Beg_Clip_LAT.P2014B...
%   (1:length(AT_data.Btrack_End_Clip.P14B));
AT_data.elev_End_Clip_LAT.P2016 = AT_data.elev_Beg_Clip_LAT.P2016...
  (1:length(AT_data.Btrack_End_Clip.P16));
AT_data.elev_End_Clip_LAT.P2017 = AT_data.elev_Beg_Clip_LAT.P2017...
  (1:length(AT_data.Btrack_End_Clip.P17));  
AT_data.elev_End_Clip_LAT.P2018 = AT_data.elev_Beg_Clip_LAT.P2018...
  (1:length(AT_data.Btrack_End_Clip.P18));
AT_data.elev_End_Clip_LAT.P2019 = AT_data.elev_Beg_Clip_LAT.P2019...
  (1:length(AT_data.Btrack_End_Clip.P19));  

% Elevation data beginning clipping from start element in Along Track LON
AT_data.elev_Beg_Clip_LON.P2010 = AT_data.longitudes.P2010...
  (AT_data.find_AT_value.P10:end); 
% AT_data.elev_Beg_Clip_LON.P2010DC8 = AT_data.longitudes.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end); 
AT_data.elev_Beg_Clip_LON.P2014A = AT_data.longitudes.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.elev_Beg_Clip_LON.P2014B = AT_data.longitudes.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.elev_Beg_Clip_LON.P2016 = AT_data.longitudes.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.elev_Beg_Clip_LON.P2017 = AT_data.longitudes.P2017...
  (AT_data.find_AT_value.P17:end);
AT_data.elev_Beg_Clip_LON.P2018 = AT_data.longitudes.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.elev_Beg_Clip_LON.P2019 = AT_data.longitudes.P2019...
  (AT_data.find_AT_value.P19:end);  

% Elevation data end clipping from end of Along track data LON
AT_data.elev_End_Clip_LON.P2010 = AT_data.elev_Beg_Clip_LON.P2010...
  (1:length(AT_data.Btrack_End_Clip.P10));
% AT_data.elev_End_Clip_LON.P2010DC8 = AT_data.elev_Beg_Clip_LON.P2010DC8...
%   (1:length(AT_data.Btrack_End_Clip.P10DC8));
AT_data.elev_End_Clip_LON.P2014A = AT_data.elev_Beg_Clip_LON.P2014A...
  (1:length(AT_data.Btrack_End_Clip.P14));
% AT_data.elev_End_Clip_LON.P2014B = AT_data.elev_Beg_Clip_LON.P2014B...
%   (1:length(AT_data.Btrack_End_Clip.P14B));
AT_data.elev_End_Clip_LON.P2016 = AT_data.elev_Beg_Clip_LON.P2016...
  (1:length(AT_data.Btrack_End_Clip.P16));
AT_data.elev_End_Clip_LON.P2017 = AT_data.elev_Beg_Clip_LON.P2017...
  (1:length(AT_data.Btrack_End_Clip.P17));  
AT_data.elev_End_Clip_LON.P2018 = AT_data.elev_Beg_Clip_LON.P2018...
  (1:length(AT_data.Btrack_End_Clip.P18));
AT_data.elev_End_Clip_LON.P2019 = AT_data.elev_Beg_Clip_LON.P2019...
  (1:length(AT_data.Btrack_End_Clip.P19));  


% Elevation data beginning clipping from start element in Along Track PASS
AT_data.elev_Beg_Clip_PASS.P2010 = AT_data.pass.P2010...
  (AT_data.find_AT_value.P10:end); 
% AT_data.elev_Beg_Clip_PASS.P2010DC8 = AT_data.pass.P2010DC8...
%   (AT_data.find_AT_value.P10DC8:end); 
AT_data.elev_Beg_Clip_PASS.P2014A = AT_data.pass.P2014A...
  (AT_data.find_AT_value.P14A:end);
% AT_data.elev_Beg_Clip_PASS.P2014B = AT_data.pass.P2014B...
%   (AT_data.find_AT_value.P14B:end);
AT_data.elev_Beg_Clip_PASS.P2016 = AT_data.pass.P2016...
  (AT_data.find_AT_value.P16:end);
AT_data.elev_Beg_Clip_PASS.P2017 = AT_data.pass.P2017...
  (AT_data.find_AT_value.P17:end);
AT_data.elev_Beg_Clip_PASS.P2018 = AT_data.pass.P2018...
  (AT_data.find_AT_value.P18:end);
AT_data.elev_Beg_Clip_PASS.P2019 = AT_data.pass.P2019...
  (AT_data.find_AT_value.P19:end);  

% Elevation data end clipping from end of Along track data PASS
AT_data.elev_End_Clip_PASS.P2010 = AT_data.elev_Beg_Clip_PASS.P2010...
  (1:length(AT_data.Btrack_End_Clip.P10));
% AT_data.elev_End_Clip_PASS.P2010DC8 = AT_data.elev_Beg_Clip_PASS.P2010DC8...
%   (1:length(AT_data.Btrack_End_Clip.P10DC8));
AT_data.elev_End_Clip_PASS.P2014A = AT_data.elev_Beg_Clip_PASS.P2014A...
  (1:length(AT_data.Btrack_End_Clip.P14));
% AT_data.elev_End_Clip_PASS.P2014B = AT_data.elev_Beg_Clip_PASS.P2014B...
%   (1:length(AT_data.Btrack_End_Clip.P14B));
AT_data.elev_End_Clip_PASS.P2016 = AT_data.elev_Beg_Clip_PASS.P2016...
  (1:length(AT_data.Btrack_End_Clip.P16));
AT_data.elev_End_Clip_PASS.P2017 = AT_data.elev_Beg_Clip_PASS.P2017...
  (1:length(AT_data.Btrack_End_Clip.P17));  
AT_data.elev_End_Clip_PASS.P2018 = AT_data.elev_Beg_Clip_PASS.P2018...
  (1:length(AT_data.Btrack_End_Clip.P18));
AT_data.elev_End_Clip_PASS.P2019 = AT_data.elev_Beg_Clip_PASS.P2019...
  (1:length(AT_data.Btrack_End_Clip.P19));  

% Save along elevation data size as variable to see if there is any errors
% BED
AT_data.array_size.P10_elev = size(AT_data.elev_End_Clip.P2010);
% AT_data.array_size.P10DC8_elev = size(AT_data.elev_End_Clip.P2010DC8);
AT_data.array_size.P14A_elev = size(AT_data.elev_End_Clip.P2014A);
% AT_data.array_size.P14B_elev = size(AT_data.elev_End_Clip.P2014B);
AT_data.array_size.P16_elev = size(AT_data.elev_End_Clip.P2016);
AT_data.array_size.P17_elev = size(AT_data.elev_End_Clip.P2017);
AT_data.array_size.P18_elev = size(AT_data.elev_End_Clip.P2018);
AT_data.array_size.P19_elev = size(AT_data.elev_End_Clip.P2019);
% SURF
AT_data.array_size.P10_elevSURF = size(AT_data.elev_End_Clip_SURF.P2010);
% AT_data.array_size.P10DC8_elevSURF = size(AT_data.elev_End_Clip_SURF.P2010DC8);
AT_data.array_size.P14A_elevSURF = size(AT_data.elev_End_Clip_SURF.P2014A);
% AT_data.array_size.P14B_elevSURF = size(AT_data.elev_End_Clip_SURF.P2014B);
AT_data.array_size.P16_elevSURF = size(AT_data.elev_End_Clip_SURF.P2016);
AT_data.array_size.P17_elevSURF = size(AT_data.elev_End_Clip_SURF.P2017);
AT_data.array_size.P18_elevSURF = size(AT_data.elev_End_Clip_SURF.P2018);
AT_data.array_size.P19_elevSURF = size(AT_data.elev_End_Clip_SURF.P2019);
% LAT
AT_data.array_size.P10_LAT = size(AT_data.elev_End_Clip_LAT.P2010);
% AT_data.array_size.P10DC8_LAT = size(AT_data.elev_End_Clip_LAT.P2010DC8);
AT_data.array_size.P14A_LAT = size(AT_data.elev_End_Clip_LAT.P2014A);
% AT_data.array_size.P14B_LAT = size(AT_data.elev_End_Clip_LAT.P2014B);
AT_data.array_size.P16_LAT = size(AT_data.elev_End_Clip_LAT.P2016);
AT_data.array_size.P17_LAT = size(AT_data.elev_End_Clip_LAT.P2017);
AT_data.array_size.P18_LAT = size(AT_data.elev_End_Clip_LAT.P2018);
AT_data.array_size.P19_LAT = size(AT_data.elev_End_Clip_LAT.P2019);
% LON
AT_data.array_size.P10_LON = size(AT_data.elev_End_Clip_LON.P2010);
% AT_data.array_size.P10DC8_LON = size(AT_data.elev_End_Clip_LON.P2010DC8);
AT_data.array_size.P14A_LON = size(AT_data.elev_End_Clip_LON.P2014A);
% AT_data.array_size.P14B_LON = size(AT_data.elev_End_Clip_LON.P2014B);
AT_data.array_size.P16_LON = size(AT_data.elev_End_Clip_LON.P2016);
AT_data.array_size.P17_LON = size(AT_data.elev_End_Clip_LON.P2017);
AT_data.array_size.P18_LON = size(AT_data.elev_End_Clip_LON.P2018);
AT_data.array_size.P19_LON = size(AT_data.elev_End_Clip_LON.P2019);
% PASS
AT_data.array_size.P10_PASS = size(AT_data.elev_End_Clip_PASS.P2010);
% AT_data.array_size.P10DC8_PASS = size(AT_data.elev_End_Clip_PASS.P2010DC8);
AT_data.array_size.P14A_PASS = size(AT_data.elev_End_Clip_PASS.P2014A);
% AT_data.array_size.P14B_PASS = size(AT_data.elev_End_Clip_PASS.P2014B);
AT_data.array_size.P16_PASS = size(AT_data.elev_End_Clip_PASS.P2016);
AT_data.array_size.P17_PASS = size(AT_data.elev_End_Clip_PASS.P2017);
AT_data.array_size.P18_PASS = size(AT_data.elev_End_Clip_PASS.P2018);
AT_data.array_size.P19_PASS = size(AT_data.elev_End_Clip_PASS.P2019);

%% Derive Along track spacing array, interpolated profiles and melt by Year
  
% Creates along track array query points for Interp1. Makes for all years
% but only use 1 array as interp1. Multiple years are so you can
% interpolate by which ever line you choose. Sample spacing is every 0.1m
% Switch middle value to change sample step
  
AT_data.query_array.P10 = (AT_data.AT_vel.P2010(1):0.1:...
  AT_data.AT_vel.P2010(end));
%AT_data.query_array.P14 = (AT_data.AT_vel.P2014A(1):0.1:...
%AT_data.AT_vel.P2014A(end));
%AT_data.query_array.P16 = (AT_data.AT_vel.P2016(1):0.1:...
%AT_data.AT_vel.P2016(end));
%AT_data.query_array.P17 = (AT_data.AT_vel.P2017(1):0.1:...
%AT_data.AT_vel.P2017(end));
%AT_data.query_array.P18 = (AT_data.AT_vel.P2018(1):0.1:...
%AT_data.AT_vel.P2018(end));
%AT_data.query_array.P19 = (AT_data.AT_vel.P2019(1):0.1:...
%AT_data.AT_vel.P2019(end));

% Apply interpolation to each profile using selected query array
% 2010 BED
AT_data.interp_data.P10 = interp1(AT_data.Btrack_End_Clip.P10, ...
  AT_data.elev_End_Clip.P2010, AT_data.query_array.P10);
% 2010CD8 BED
% AT_data.interp_data.P10DC8 = interp1(AT_data.Btrack_End_Clip.P10DC8, ...
%   AT_data.elev_End_Clip.P2010DC8, AT_data.query_array.P10);
% 2014A BED
AT_data.interp_data.P14A = interp1(AT_data.Btrack_End_Clip.P14A, ...
  AT_data.elev_End_Clip.P2014A, AT_data.query_array.P10);
% 2014B BED
% AT_data.interp_data.P14B = interp1(AT_data.Btrack_End_Clip.P14B, ...
%   AT_data.elev_End_Clip.P2014B, AT_data.query_array.P10);
% 2016 BED
AT_data.interp_data.P16 = interp1(AT_data.Btrack_End_Clip.P16, ...
  AT_data.elev_End_Clip.P2016, AT_data.query_array.P10);
% 2017 BED
%AT_data.interp_data.P17 = interp1(AT_data.Btrack_End_Clip.P17, ...
%  AT_data.elev_End_Clip.P2017, AT_data.query_array.P10);
% 2018 BED
AT_data.interp_data.P18 = interp1(AT_data.Btrack_End_Clip.P18, ...
  AT_data.elev_End_Clip.P2018, AT_data.query_array.P10);
% 2019 BED
%AT_data.interp_data.P19 = interp1(AT_data.Btrack_End_Clip.P19, ...
%  AT_data.elev_End_Clip.P2019, AT_data.query_array.P10);

% 2010 SURF
AT_data.interp_data.P10_SURF = interp1(AT_data.Btrack_End_Clip.P10, ...
  AT_data.elev_End_Clip_SURF.P2010, AT_data.query_array.P10);
% 2010CD8 SURF
% AT_data.interp_data.P10DC8_SURF = interp1(AT_data.Btrack_End_Clip.P10DC8, ...
%   AT_data.elev_End_Clip_SURF.P2010DC8, AT_data.query_array.P10);
% 2014A SURF
AT_data.interp_data.P14A_SURF = interp1(AT_data.Btrack_End_Clip.P14A, ...
  AT_data.elev_End_Clip.P2014A_SURF, AT_data.query_array.P10);
% 2014B SURF
% AT_data.interp_data.P14B_SURF = interp1(AT_data.Btrack_End_Clip.P14B, ...
%   AT_data.elev_End_Clip_SURF.P2014B, AT_data.query_array.P10);
% 2016 SURF
AT_data.interp_data.P16_SURF = interp1(AT_data.Btrack_End_Clip.P16, ...
  AT_data.elev_End_Clip_SURF.P2016, AT_data.query_array.P10);
% 2017 SURF
%AT_data.interp_data.P17_SURF = interp1(AT_data.Btrack_End_Clip.P17, ...
%  AT_data.elev_End_Clip_SURF.P2017, AT_data.query_array.P10);
% 2018 SURF
AT_data.interp_data.P18_SURF = interp1(AT_data.Btrack_End_Clip.P18, ...
  AT_data.elev_End_Clip_SURF.P2018, AT_data.query_array.P10);
% 2019 SURF
%AT_data.interp_data.P19_SURF = interp1(AT_data.Btrack_End_Clip.P19, ...
%  AT_data.elev_End_Clip_SURF.P2019, AT_data.query_array.P10);

% 2010 LAT
AT_data.interp_data.P10_LAT = interp1(AT_data.Btrack_End_Clip.P10, ...
  AT_data.elev_End_Clip_LAT.P2010, AT_data.query_array.P10);
% 2010CD8 LAT
% AT_data.interp_data.P10DC8_LAT = interp1(AT_data.Btrack_End_Clip.P10DC8, ...
%   AT_data.elev_End_Clip_LAT.P2010DC8, AT_data.query_array.P10);
% 2014A LAT
AT_data.interp_data.P14A_LAT = interp1(AT_data.Btrack_End_Clip.P14A, ...
  AT_data.elev_End_Clip_LAT.P2014A, AT_data.query_array.P10);
% 2014B LAT
% AT_data.interp_data.P14B_LAT = interp1(AT_data.Btrack_End_Clip.P14B, ...
%   AT_data.elev_End_Clip_LAT.P2014B, AT_data.query_array.P10);
% 2016 LAT
AT_data.interp_data.P16_LAT = interp1(AT_data.Btrack_End_Clip.P16, ...
  AT_data.elev_End_Clip_LAT.P2016, AT_data.query_array.P10);
% 2017 LAT
%AT_data.interp_data.P17_LAT = interp1(AT_data.Btrack_End_Clip.P17, ...
%  AT_data.elev_End_Clip_LAT.P2017, AT_data.query_array.P10);
% 2018 LAT
AT_data.interp_data.P18_LAT = interp1(AT_data.Btrack_End_Clip.P18, ...
  AT_data.elev_End_Clip_LAT.P2018, AT_data.query_array.P10);
% 2019 LAT
%AT_data.interp_data.P19_LAT = interp1(AT_data.Btrack_End_Clip.P19, ...
%  AT_data.elev_End_Clip_LAT.P2019, AT_data.query_array.P10);

% 2010 LON
AT_data.interp_data.P10_LON = interp1(AT_data.Btrack_End_Clip.P10, ...
  AT_data.elev_End_Clip_LON.P2010, AT_data.query_array.P10);
% 2010CD8 LON
% AT_data.interp_data.P10DC8_LON = interp1(AT_data.Btrack_End_Clip.P10DC8, ...
%   AT_data.elev_End_Clip_LON.P2010DC8, AT_data.query_array.P10);
% 2014A LON
AT_data.interp_data.P14A_LON = interp1(AT_data.Btrack_End_Clip.P14A, ...
  AT_data.elev_End_Clip_LON.P2014A, AT_data.query_array.P10);
% 2014B LON
% AT_data.interp_data.P14B_LON = interp1(AT_data.Btrack_End_Clip.P14B, ...
%   AT_data.elev_End_Clip_LON.P2014B, AT_data.query_array.P10);
% 2016 LON
AT_data.interp_data.P16_LON = interp1(AT_data.Btrack_End_Clip.P16, ...
  AT_data.elev_End_Clip_LON.P2016, AT_data.query_array.P10);
% 2017 LON
%AT_data.interp_data.P17_LON = interp1(AT_data.Btrack_End_Clip.P17, ...
%  AT_data.elev_End_Clip_LON.P2017, AT_data.query_array.P10);
% 2018 LON
AT_data.interp_data.P18_LON = interp1(AT_data.Btrack_End_Clip.P18, ...
  AT_data.elev_End_Clip_LON.P2018, AT_data.query_array.P10);
% 2019 LON
%AT_data.interp_data.P19_LON = interp1(AT_data.Btrack_End_Clip.P19, ...
%  AT_data.elev_End_Clip_LON.P2019, AT_data.query_array.P10);

% 2010 PASS
AT_data.interp_data.P10_PASS = interp1(AT_data.Btrack_End_Clip.P10, ...
  AT_data.elev_End_Clip_PASS.P2010, AT_data.query_array.P10);
% 2010CD8 PASS
% AT_data.interp_data.P10DC8_PASS = interp1(AT_data.Btrack_End_Clip.P10DC8, ...
%   AT_data.elev_End_Clip_PASS.P2010DC8, AT_data.query_array.P10);
% 2014A PASS
AT_data.interp_data.P14A_PASS = interp1(AT_data.Btrack_End_Clip.P14A, ...
  AT_data.elev_End_Clip_PASS.P2014A, AT_data.query_array.P10);
% 2014B PASS
% AT_data.interp_data.P14B_PASS = interp1(AT_data.Btrack_End_Clip.P14B, ...
%   AT_data.elev_End_Clip_PASS.P2014B, AT_data.query_array.P10);
% 2016 PASS
AT_data.interp_data.P16_PASS = interp1(AT_data.Btrack_End_Clip.P16, ...
  AT_data.elev_End_Clip_PASS.P2016, AT_data.query_array.P10);
% 2017 PASS
%AT_data.interp_data.P17_PASS = interp1(AT_data.Btrack_End_Clip.P17, ...
%  AT_data.elev_End_Clip_PASS.P2017, AT_data.query_array.P10);
% 2018 PASS
AT_data.interp_data.P18_PASS = interp1(AT_data.Btrack_End_Clip.P18, ...
  AT_data.elev_End_Clip_PASS.P2018, AT_data.query_array.P10);
% 2019 PASS
%AT_data.interp_data.P19_PASS = interp1(AT_data.Btrack_End_Clip.P19, ...
%  AT_data.elev_End_Clip_PASS.P2019, AT_data.query_array.P10);

% Calculate melt rates from interpolated profile pairings
% 2010-2014A melt (Vertical difference in Features)
AT_data.melt_rates.P10_P14A = AT_data.interp_data.P14 - ...
  AT_data.interp_data.P10; 
% 2014A-2016 melt (Vertical difference in Features)
AT_data.melt_rates.P14A_P16 = AT_data.interp_data.P16 - ...
  AT_data.interp_data.P14;
% 2016-2017 melt (Vertical difference in Features)
%AT_data.melt_rates.P16_P17 = AT_data.interp_data.P17 - ...
%  AT_data.interp_data.P16;
% 2017-2018 melt (Vertical difference in Features)
%AT_data.melt_rates.P17_P18 = AT_data.interp_data.P18 - ...
%  AT_data.interp_data.P17;
% 2018-2019 melt (Vertical difference in Features)
%AT_data.melt_rates.P18_P19 = AT_data.interp_data.P19 - ...
%  AT_data.interp_data.P18;
% 2010-2019 melt (Vertical difference in Features)
%AT_data.melt_rates.P10_P19 = AT_data.interp_data.P19 - ...
%  AT_data.interp_data.P10;

%% Export data to csv
% Concatenate and take transpose of Lon, Lat, Surf, Bed fields. Concatenate horizontally for each year
AT_data.export.P10 = cat(2, AT_data.interp_data.P10_LON.', AT_data.interp_data.P10_LAT.', AT_data.interp_data.P10_SURF.', AT_data.interp_data.P10.' );
% AT_data.export.P10DC8 = cat(2, AT_data.interp_data.P10DC8_LON.', AT_data.interp_data.P10DC8_LAT.', AT_data.interp_data.P10DC8_SURF.', AT_data.interp_data.P10DC8.' );
AT_data.export.P14A = cat(2, AT_data.interp_data.P14A_LON.', AT_data.interp_data.P14A_LAT.', AT_data.interp_data.P14A_SURF.', AT_data.interp_data.P14B.' );
% AT_data.export.P14B = cat(2, AT_data.interp_data.P14B_LON.', AT_data.interp_data.P14B_LAT.', AT_data.interp_data.P14B_SURF.', AT_data.interp_data.P14B.' );
AT_data.export.P16 = cat(2, AT_data.interp_data.P16_LON.', AT_data.interp_data.P16_LAT.', AT_data.interp_data.P16_SURF.', AT_data.interp_data.P16.' );
AT_data.export.P17 = cat(2, AT_data.interp_data.P17_LON.', AT_data.interp_data.P17_LAT.', AT_data.interp_data.P17_SURF.', AT_data.interp_data.P17.' );
AT_data.export.P18 = cat(2, AT_data.interp_data.P18_LON.', AT_data.interp_data.P18_LAT.', AT_data.interp_data.P18_SURF.', AT_data.interp_data.P18.' );
AT_data.export.P19 = cat(2, AT_data.interp_data.P19_LON.', AT_data.interp_data.P19_LAT.', AT_data.interp_data.P19_SURF.', AT_data.interp_data.P19.' );

%% Define Header Array of strings and vertically concatenate to data 
cheader = {'Lons', 'Lats', 'Surface', 'Depth'}; % header
commaHeader = [cheader;repmat({','},1,numel(cheader))];
commaHeader = commaHeader(:)';
textHeader = cell2mat(commaHeader);

% change folder
cd 'C:\Users\c262b531\Documents\scripts\cresis-toolbox\cresis-toolbox\+multipass\CSV_export_files\'

%write header to file 2010
fid = fopen('ZI_lat_lon_surf_bed_10.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_10.csv', AT_data.export.P10, '-append');

%write header to file 2010DC8
% fid = fopen('ZI_lat_lon_surf_bed_10DC8.csv','w');
% fprintf(fid,'%s\n',textHeader);
% fclose(fid);
% dlmwrite('ZI_lat_lon_surf_bed_10DC8.csv', AT_data.export.P10DC8, '-append');

%write header to file 2014A
fid = fopen('ZI_lat_lon_surf_bed_14A.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_14A.csv', AT_data.export.P14A, '-append');

%write header to file 2014B
% fid = fopen('ZI_lat_lon_surf_bed_14B.csv','w');
% fprintf(fid,'%s\n',textHeader);
% fclose(fid);
% dlmwrite('ZI_lat_lon_surf_bed_14B.csv', AT_data.export.P14B, '-append');

%write header to file 2016
fid = fopen('ZI_lat_lon_surf_bed_16.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_16.csv', AT_data.export.P16, '-append');

%write header to file 2017
fid = fopen('ZI_lat_lon_surf_bed_17.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_17.csv', AT_data.export.P17, '-append');

%write header to file 2018
fid = fopen('ZI_lat_lon_surf_bed_18.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_18.csv', AT_data.export.P18, '-append');

%write header to file 2019
fid = fopen('ZI_lat_lon_surf_bed_19.csv','w');
fprintf(fid,'%s\n',textHeader);
fclose(fid);
dlmwrite('ZI_lat_lon_surf_bed_19.csv', AT_data.export.P19, '-append');

%% Test Figures Section 

figure(1)
h1 = plot(AT_data.Btrack_End_Clip.P10/1e3, AT_data.elev_End_Clip.P2010);
hold on
h2 = plot(AT_data.Btrack_End_Clip.P14/1e3, AT_data.elev_End_Clip.P2014A);
h3 = plot(AT_data.Btrack_End_Clip.P16/1e3, AT_data.elev_End_Clip.P2016);
%h4 = plot(AT_data.Btrack_End_Clip.P17/1e3, AT_data.elev_End_Clip.P2017);
h5 = plot(AT_data.Btrack_End_Clip.P18/1e3, AT_data.elev_End_Clip.P2018);
%h6 = plot(AT_data.Btrack_End_Clip.P19/1e3, AT_data.elev_End_Clip.P2019);
title('Test Plot 1 - Alignment of Profiles is Correct');
xlabel('Along Track (km)');
ylabel('Elevation (m)');
legend('original 2010', 'original 2014A', 'original 2016', ...
  'original 2017', 'original 2018', 'original 2019', ...
  'Location', 'southeast');
  
figure(2)
h1 = plot(AT_data.query_array.P10, AT_data.interp_data.P10);
hold on
h2 = plot(AT_data.query_array.P10, AT_data.interp_data.P14);
h3 = plot(AT_data.query_array.P10, AT_data.interp_data.P16);
%h4 = plot(AT_data.query_array.P10, AT_data.interp_data.P17);
h5 = plot(AT_data.query_array.P10, AT_data.interp_data.P18);
%h6 = plot(AT_data.query_array.P10, AT_data.interp_data.P19);
h7 = plot(AT_data.Btrack_End_Clip.P10, AT_data.elev_End_Clip.P2010);
h8 = plot(AT_data.Btrack_End_Clip.P14, AT_data.elev_End_Clip.P2014A);
h9 = plot(AT_data.Btrack_End_Clip.P16, AT_data.elev_End_Clip.P2016);
%h10 = plot(AT_data.Btrack_End_Clip.P17, AT_data.elev_End_Clip.P2017);
h11 = plot(AT_data.Btrack_End_Clip.P18, AT_data.elev_End_Clip.P2018);
%h12 = plot(AT_data.Btrack_End_Clip.P19, AT_data.elev_End_Clip.P2019);
title('Test Plot 2 - Interpolated files same location as Originals');
xlabel('Along Track (km)');
ylabel('Elevation (m)');
legend('interpolated 2010', 'interpolated 2014A', 'interpolated 2016', ...
  'interpolated 2017', 'interpolated 2018', 'interpolated 2019', ...
  'old 2010','old 2014A','old 2016', 'old 2017', 'old 2018', 'old 2019', ...
  'Location', 'southeast');
  
figure(3)
h1 = plot(AT_data.query_array.P10, AT_data.interp_data.P10);
hold on
h2 = plot(AT_data.query_array.P10, AT_data.interp_data.P14);
h3 = plot(AT_data.query_array.P10, AT_data.interp_data.P16);
%h4 = plot(AT_data.query_array.P10, AT_data.interp_data.P17);
h5 = plot(AT_data.query_array.P10, AT_data.interp_data.P18);
%h6 = plot(AT_data.query_array.P10, AT_data.interp_data.P19);
%h7 = plot(AT_data.query_array.P10, AT_data.melt_rates.P10_P19);
title('Test Plot 3 - Interpolation Profiles and Melt Profiles');
xlabel('Along Track (km)');
ylabel('Elevation (m)');
legend('interpolated 2010', 'interpolated 2014A', 'interpolated 2016',...
  'interpolated 2017','interpolated 2018', 'interpolated 2019', ...
  '2010-2019 melt', 'Location', 'southeast');
  
figure(4)
h1 = plot(AT_data.query_array.P10, AT_data.melt_rates.P10_P14);
hold on
h2 = plot(AT_data.query_array.P10, AT_data.melt_rates.P14_P16);
%h3 = plot(AT_data.query_array.P10, AT_data.melt_rates.P16_P17);
%h4 = plot(AT_data.query_array.P10, AT_data.melt_rates.P17_P18);
%h5 = plot(AT_data.query_array.P10, AT_data.melt_rates.P18_P19);
%h6 = plot(AT_data.query_array.P10, AT_data.melt_rates.P10_P19);
title('Test Plot 4 - Melt Profiles for all years');
xlabel('Along Track (km)');
ylabel('Elevation (m)');
legend('2010-2014A melt', '2014A-2016 melt', '2016-2017 melt', ...
  '2017-2018 melt', '2018-2018 melt', '2010-2019 melt', ...
  'Location', 'southeast');

% Subplot figure of melt rates
figure(5)
subplot(6,1,1);
plot(AT_data.query_array.P10, AT_data.melt_rates.P10_P14);
title('Melt 2010-2014A');

subplot(6,1,2);
plot(AT_data.query_array.P10, AT_data.melt_rates.P14_P16);
title('Melt 2014A-2016');

% subplot(6,1,3);
% plot(AT_data.query_array.P10, AT_data.melt_rates.P16_P17);
% title('Melt 2016-2018');

% subplot(6,1,4);
% plot(AT_data.query_array.P10, AT_data.melt_rates.P17_P18);
% title('Melt 2016-2018');

% subplot(6,1,5);
% plot(AT_data.query_array.P10, AT_data.melt_rates.P18_P19);
% title('Melt 2016-2018');

% subplot(6,1,6);
% plot(AT_data.query_array.P10, AT_data.melt_rates.P10_P19);
% title('Melt 2010-2018');

% Annual melt rate average based off 2010-2019 melt subtraction
% figure(6)
% plot(AT_data.query_array.P10/1e3, AT_data.melt_rates.P10_P19/9, 'color','g');
% title('Melt 2016-2018');
% ylim([-100, 400]);
% xlabel('Along Track Distance (km)');
