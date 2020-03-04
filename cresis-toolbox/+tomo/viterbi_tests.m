function viterbi_tests()
  % TODO[reece]: Tune weights
  % TODO[reece]: Rewrite viterbi_costs.md
  % TODO[reece]: Update wiki, address indexing issue (pass 1-indexed, viterbi will compensate)
  global matrix layer;
  global gt layer;
  
  % CONSTANTS
  rows = 20;
  cols = 10;
  surf = 5;
  mult = 10;
  grnd = 17;
  matrix = zeros(rows, cols);
  matrix(surf, :) = ones(1, cols) * 30; % Surface
  matrix(mult, :) = ones(1, cols) * 20; % Mult 1
  matrix(grnd, :) = ones(1, cols) * 10; % Bottom
  
  surf_bins = ones(1, cols) * surf;
  gt = [1 cols; mult mult];
  
  % Viterbi params
  transition_weights = ones(1, cols-1);
  gt_weights = ones(1, cols);
  
  surf_weight = 1000;
  mult_weight = 100;
  mult_weight_decay = .3;
  mult_weight_local_decay = .7;
  zero_bin = 1;
  
  % Other environment vars
  mask = inf*ones(1, cols);
  slope = round(diff(surf_bins));
  bounds = [];
  mask_dist = ones(1, cols) * Inf;
  cost_matrix = ones(rows,cols);
  
  % RUN
  layer = tomo.viterbi(matrix, surf_bins, gt, mask, 1, slope, bounds, ...
        gt_weights, mask_dist, cost_matrix, transition_weights, ...
        surf_weight, mult_weight, mult_weight_decay, ...
        mult_weight_local_decay, int64(zero_bin));
  hfig = setup();
  resize(hfig);
  
 [index_vals, path_prob_vals, path_prob_next_vals, path_vals] = import_data();
 
end

function plot_viterbi()
  global layer gt;
  
  hold on;
  
  scatter(gt(1, :), gt(2, :), 'rx');
  
  plot(layer, 'g');
      
  hold off;
end


function hfig = setup() 
  if ishandle(1)
    hfig = figure(1);
  else
    hfig = figure('SizeChangedFcn', @resize);
  end
end


function resize(src,~)
  global matrix;
  
  r = size(matrix, 1);
  c = size(matrix, 2);
  
  % Plot matrix
  clf;
  colormap(1-gray);
  imagesc(matrix);
  
  % X-axis
  xticks(.5:(c + .5));
  xlim([.5 (c + .5)]);
  xticklabels('');
  
  % Y-axis
  yticks(.5:(r + .5));
  ylim([.5 (r + .5)]);
  yticklabels('');
  grid;
  
  w = src.Position(3);
  h = src.Position(4);
  axes_pos = get(gca, 'Position');

  left = axes_pos(1) * w;
  bottom = axes_pos(2) * h;

  xmargin = axes_pos(3)*w/c;
  ymargin = axes_pos(4)*h/r;
  dimensions = [r c];
  for axis = 1:2
    for i = 1:dimensions(axis)
      char = uicontrol('Style', 'text', 'String', sprintf('%d | %d', i-1, i), 'FontSize', 10);
      char_pos = get(char, 'Extent');
      char_width = char_pos(3);
      char_height = char_pos(4);
      if axis == 2
        set(char, 'Position', [left + xmargin*i - xmargin/2 - char_width/2, bottom - char_height * 1.25, char_width, char_height]);
      else
        set(char, 'Position', [left - char_width * 1.25, bottom + ymargin*(r-i) + ymargin/2 - char_height/2, char_width, char_height]);
      end
    end
  end
 
  plot_viterbi();
end

function [index_vals, path_prob_vals, path_prob_next_vals, path_vals] = import_data()
  global matrix;
  r = size(matrix, 1);
  c = size(matrix, 2);
  
  index_vals = csvread('+tomo/viterbi_debug/index.csv')';
  path_prob_vals = csvread('+tomo/viterbi_debug/path_prob.csv')';
  path_prob_next_vals = csvread('+tomo/viterbi_debug/path_prob_next.csv')';
  path_vals = csvread('+tomo/viterbi_debug/path.csv')';
  index_vals = index_vals(1:end-1,:);
  path_prob_vals = path_prob_vals(1:end-1,:);
  path_prob_next_vals = path_prob_next_vals(1:end-1,:);
  path_vals = path_vals(1:end-1,end);
  path_vals = reshape(path_vals, r, c);
end

