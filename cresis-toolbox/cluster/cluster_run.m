function ctrl_chain = cluster_run(ctrl_chain,cluster_run_mode)
% ctrl_chain = cluster_run(ctrl_chain,cluster_run_mode)
%
% Submits jobs in a list of batch chains. Each chain in the list runs in
% parallel. Batches within a chain are run in series.
%
% Inputs:
% ctrl_chain: cell array of chains that can be run in parallel
%  ctrl_chain{chain}: cell array of batches that must be run in series (stages)
%   ctrl_chain{chain}{stage}: control structure for a batch
% cluster_run_mode: integer specifying the mode to run tasks. Possible
%   modes are:
%   0: Non-blocking mode. Use this mode when the ctrl_chain structure
%     properly represents which tasks have completed successfully.
%   1: Blocking mode. Same as 0 except continuously polls tasks until all
%     chains are finished. Default mode.
%   2: Non-block mode. Use this mode when the ctrl_chain structure does not
%     represent which tasks have completed successfully. cluster_run will
%     check every task in a chain before starting to run the chain.
%   3: Block mode. Same as 2 except continuously polls tasks until all
%     chains are finished.
%
% Outputs:
% ctrl_chain: updated list of batch chains that was passed in
%
% Example:
% % If there is just one control structure to run called ctrl
% ctrl_chain = {{ctrl}};
% ctrl_chain = cluster_run(ctrl_chain);
%
% % Let ctrl1 be in chain 1, let ctrl2a and ctrl2b be in chain 2
% ctrl_chain = {{ctrl1},{ctrl2a,ctrl2b}};
% ctrl_chain = cluster_run(ctrl_chain);
%
% Author: John Paden
%
% See also: cluster_chain_stage, cluster_cleanup, cluster_compile
%   cluster_exec_job, cluster_get_batch, cluster_get_batch_list, 
%   cluster_hold, cluster_job, cluster_new_batch, cluster_new_task,
%   cluster_print, cluster_run, cluster_submit_batch, cluster_submit_task,
%   cluster_update_batch, cluster_update_task

if isnumeric(ctrl_chain)
  ctrl_chain = cluster_load_chain(ctrl_chain);
end

if iscell(ctrl_chain)
  %% Input checking
  if ~exist('cluster_run_mode','var') || isempty(cluster_run_mode)
    cluster_run_mode = 1;
  end
  
  %% Traverse chain list
  active_stage = ones(numel(ctrl_chain),1);
  first_run = ones(numel(ctrl_chain),1);
  while any(isfinite(active_stage))
    for chain = 1:numel(ctrl_chain)
      if isempty(ctrl_chain{chain})
        % No batches in this chain
        active_stage(chain) = inf;
        continue;
      end
      if isfinite(active_stage(chain))
        % 1. There is at least one batch left to run in this chain
        ctrl = ctrl_chain{chain}{active_stage(chain)};
        
        % 2. If this is the first loop of cluster_run, force a complete
        %   update of the job status information.
        if first_run(chain)
          if cluster_run_mode < 2
            ctrl = cluster_get_batch(ctrl,[],2);
          else
            ctrl = cluster_get_batch(ctrl);
          end
          first_run(chain) = false;
        else
          ctrl = cluster_update_batch(ctrl);
          pause(ctrl.cluster.stat_pause);
        end
        
        % 3. Submit jobs from the active stage for each parallel control structure
        %   ctrl.max_active_jobs.
        ctrl = cluster_run(ctrl);
        
        % 4. Update ctrl_chain
        ctrl_chain{chain}{active_stage(chain)} = ctrl;
        
        % 5. If all jobs completed in a batch and:
        %    If no errors, move to the next stage
        %    If errors and out of retries, stop chain
        if all(ctrl.job_status=='C')
          if ~any(ctrl.error_mask)
            active_stage(chain) = active_stage(chain) + 1;
            first_run(chain) = true;
            if active_stage(chain) > numel(ctrl_chain{chain})
              % Chain is complete
              active_stage(chain) = inf;
            end
          elseif all(ctrl.retries >= ctrl.cluster.max_retries | ~ctrl.error_mask)
            % Stop chain
            active_stage(chain) = -inf;
          end
        end
        
        % 6. Check to see if a hold has been placed on this batch
        if exist(ctrl.hold_fn,'file')
          fprintf('This batch has a hold. Run cluster_hold(ctrl) to remove. Run "cluster_run_mode=0" to exit cluster_run.m in a clean way. Either way, run dbcont to continue.\n');
          keyboard
        end
      end
    end
    if cluster_run_mode == 0 || cluster_run_mode == 2
      break;
    end
  end

  for chain=1:numel(ctrl_chain)
    if active_stage(chain) == inf
      fprintf('Chain %d succeeded (%s)\n', chain, datestr(now));
    else
      fprintf('Chain %d not finished or failed (%s)\n', chain, datestr(now));
      for stage=1:numel(ctrl_chain{chain})
        ctrl = ctrl_chain{chain}{stage};
        if all(ctrl.job_status=='C')
          if all(ctrl.error_mask==0)
            fprintf('  Stage %d succeeded\n', stage);
          else any(ctrl.error_mask)
            fprintf('  Stage %d (batch %d) failed (%d of %d tasks failed)\n', stage, ctrl.batch_id, sum(ctrl.error_mask~=0), length(ctrl.error_mask));
          end
        else
          fprintf('  Stage %d not finished\n', stage);
        end
      end
    end
  end
  
elseif isstruct(ctrl_chain)
  ctrl = ctrl_chain;
  
  if strcmpi(ctrl.cluster.type,'none')
    return;
  end

  % Sort submission queue tasks based on memory usage: this is done to
  % increase the chance that tasks with similar memory usage will be
  % grouped together in jobs to make the cluster memory request more
  % efficient.
  [~,sort_idxs] = sort(ctrl.mem(ctrl.submission_queue));
  ctrl.submission_queue = ctrl.submission_queue(sort_idxs);
  
  job_tasks = [];
  job_cpu_time = 0;
  job_mem = 0;
  while ~isempty(ctrl.submission_queue) && ctrl.active_jobs < ctrl.cluster.max_jobs_active
    % Get task from queue
    task_id = ctrl.submission_queue(1);
    task_cpu_time = 30 + ctrl.cluster.cpu_time_mult*ctrl.cpu_time(task_id); % 30 sec to match cluster_run.sh end pause

    if isempty(job_tasks) ...
        && ctrl.cluster.max_time_per_job < job_cpu_time + task_cpu_time;
      error('ctrl.cluster.max_time_per_job is less than task %d:%d''s requested time: %.0f sec', ctrl.batch_id, task_id, task_cpu_time);
    end
    if ctrl.cluster.desired_time_per_job < job_cpu_time + task_cpu_time && ~isempty(job_tasks)
      [ctrl,new_job_id] = cluster_submit_job(ctrl,job_tasks,job_cpu_time,job_mem);
      fprintf('Submitted %d tasks in cluster job (%d): (%s)\n  %s\n  %d: %d', length(job_tasks), ...
        new_job_id, datestr(now), ctrl.notes{job_tasks(1)}, ctrl.batch_id, job_tasks(1));
      if length(job_tasks) > 1
        fprintf(', %d', job_tasks(2:end));
      end
      fprintf('\n');
      job_tasks = [];
      job_cpu_time = 0;
      job_mem = 0;
      pause(ctrl.cluster.submit_pause);
    end
    job_tasks(end+1) = task_id;
    job_cpu_time = job_cpu_time + task_cpu_time;
    job_mem = max(job_mem, ctrl.cluster.mem_mult*ctrl.mem(task_id));
    ctrl.submission_queue = ctrl.submission_queue(2:end);
    
    % Check to see if a hold has been placed on this batch
    if exist(ctrl.hold_fn,'file')
      fprintf('This batch has a hold. Run cluster_hold(ctrl) to remove. Run "cluster_run_mode=0" to exit cluster_run.m in a clean way. Either way, run dbcont to continue.\n');
      keyboard
    end
    
  end
  
  if ctrl.active_jobs < ctrl.cluster.max_jobs_active && ~isempty(job_tasks)
    [ctrl,new_job_id] = cluster_submit_job(ctrl,job_tasks,job_cpu_time,job_mem);
    fprintf('Submitted %d tasks in cluster job (%d): (%s)\n  %s\n  %d: %d', length(job_tasks), ...
      new_job_id, datestr(now), ctrl.notes{job_tasks(1)}, ctrl.batch_id, job_tasks(1));
    if length(job_tasks) > 1
      fprintf(', %d', job_tasks(2:end));
    end
    fprintf('\n');
    pause(ctrl.cluster.submit_pause);
    
  else
    % Put jobs back in the queue because they can't be run yet
    ctrl.submission_queue = cat(2,job_tasks,ctrl.submission_queue);
  end
  
  % Return the updated ctrl
  ctrl_chain = ctrl;
end

return
