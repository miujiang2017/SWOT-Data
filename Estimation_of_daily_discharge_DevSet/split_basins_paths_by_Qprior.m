function [basins_out, split_info] = split_basins_paths_by_Qprior(basins, opts)
% split_basins_paths_by_Qprior
%
% Split each basin path into smaller path segments using prior discharge
% magnitude, and synchronize all path-level fields in the basin structure.
%
% Recommended insertion point in main.m:
%   basins = add_SoS_results_to_basins(...);
%   basins = split_basins_paths_by_Qprior(basins, opts);
%   basins_out = filter_basins(basins, 2);

if nargin < 2 || isempty(opts)
    opts = struct();
end

basins_out = basins;
split_info = struct('basin_index', {}, 'old_path_index', {}, ...
    'segments', {}, 'Qprior', {});

for ib = 1:numel(basins_out)
    if ~isfield(basins_out(ib), 'paths') || isempty(basins_out(ib).paths)
        continue
    end

    n_paths = numel(basins_out(ib).paths);
    fields = fieldnames(basins_out(ib));
    new_values = struct();
    for f = 1:numel(fields)
        fld = fields{f};
        val = basins_out(ib).(fld);
        if local_is_path_field(val, n_paths)
            new_values.(fld) = {};
        end
    end

    new_path_count = 0;

    for ip = 1:n_paths
        Qprior = local_get_path_Qprior(basins_out(ib), ip);
        if isempty(Qprior)
            segments = [1 numel(basins_out(ib).paths{ip})];
        else
            segments = split_reaches_by_Qprior(Qprior, opts);
        end

        if size(segments,1) > 1
            split_info(end+1).basin_index = ib; %#ok<AGROW>
            split_info(end).old_path_index = ip;
            split_info(end).segments = segments;
            split_info(end).Qprior = Qprior;
        end

        for iseg = 1:size(segments,1)
            reach_idx = segments(iseg,1):segments(iseg,2);
            new_path_count = new_path_count + 1;

            for f = 1:numel(fields)
                fld = fields{f};
                if ~isfield(new_values, fld)
                    continue
                end

                val = basins_out(ib).(fld);
                new_values.(fld){new_path_count,1} = local_subset_path_value(val, ip, reach_idx);
            end
        end
    end

    new_fields = fieldnames(new_values);
    for f = 1:numel(new_fields)
        fld = new_fields{f};
        old_val = basins_out(ib).(fld);
        new_val = new_values.(fld);

        if isrow(old_val)
            new_val = new_val.';
        end

        if isstring(old_val)
            new_val = string(new_val);
        end

        basins_out(ib).(fld) = new_val;
    end

    if isfield(basins_out(ib), 'n_paths')
        basins_out(ib).n_paths = new_path_count;
    end
end

end


function tf = local_is_path_field(val, n_paths)

tf = false;
if iscell(val) && numel(val) == n_paths
    tf = true;
elseif isstring(val) && numel(val) == n_paths
    tf = true;
end

end


function Qprior = local_get_path_Qprior(basin, ip)

Qprior = [];
if isfield(basin, 'mean_q_intpl') && numel(basin.mean_q_intpl) >= ip && ...
        ~isempty(basin.mean_q_intpl{ip})
    q = basin.mean_q_intpl{ip};
    if isnumeric(q)
        Qprior = q(:,1);
    end
end

end


function out = local_subset_path_value(val, ip, reach_idx)

if isstring(val)
    out = val(ip);
    return
end

path_val = val{ip};
out = local_subset_reaches(path_val, reach_idx);

end


function out = local_subset_reaches(x, reach_idx)

out = x;
if isempty(x)
    return
end

if iscell(x)
    if isvector(x)
        out = x(reach_idx);
    elseif size(x,1) >= max(reach_idx)
        out = x(reach_idx,:);
    elseif size(x,2) >= max(reach_idx)
        out = x(:,reach_idx);
    end
elseif isnumeric(x) || islogical(x) || isstring(x)
    if isvector(x)
        out = x(reach_idx);
    elseif size(x,1) >= max(reach_idx)
        out = x(reach_idx,:);
    elseif size(x,2) >= max(reach_idx)
        out = x(:,reach_idx);
    end
end

end
