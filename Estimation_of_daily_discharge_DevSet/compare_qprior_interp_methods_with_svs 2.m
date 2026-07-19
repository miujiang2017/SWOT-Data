function out = compare_qprior_interp_methods_with_svs(basins_center, basins_wse)
% compare_qprior_interp_methods_with_svs
%
% Compare two Qprior interpolation methods against SVS gauge statistics.
%
% Inputs:
%   basins_center : basins generated with discharge_interp_coord = 'center_pos'
%   basins_wse    : basins generated with discharge_interp_coord = 'wse_sword'
%
% Comparisons:
%   mean_q_intpl vs mean(SVS_Q)
%   max_q_intpl  vs max(SVS_Q)
%
% Relative error:
%   abs(Qprior_stat - SVS_stat) / abs(SVS_stat) * 100

rows = {};

nB = min(numel(basins_center), numel(basins_wse));

for ib = 1:nB
    if ~isfield(basins_center(ib), 'Q_SVS') || isempty(basins_center(ib).Q_SVS)
        continue;
    end

    nP = min([ ...
        numel(basins_center(ib).Q_SVS), ...
        local_num_paths(basins_center(ib), 'mean_q_intpl'), ...
        local_num_paths(basins_center(ib), 'max_q_intpl'), ...
        local_num_paths(basins_wse(ib), 'mean_q_intpl'), ...
        local_num_paths(basins_wse(ib), 'max_q_intpl')]);

    for ip = 1:nP
        svs_path = basins_center(ib).Q_SVS{ip};
        if isempty(svs_path) || ~iscell(svs_path)
            continue;
        end

        qmean_center = local_prior_vec(basins_center(ib), 'mean_q_intpl', ip);
        qmean_wse    = local_prior_vec(basins_wse(ib),    'mean_q_intpl', ip);
        qmax_center  = local_prior_vec(basins_center(ib), 'max_q_intpl',  ip);
        qmax_wse     = local_prior_vec(basins_wse(ib),    'max_q_intpl',  ip);

        nR = min([numel(svs_path), numel(qmean_center), numel(qmean_wse), ...
            numel(qmax_center), numel(qmax_wse)]);

        for ir = 1:nR
            svs = svs_path{ir};
            if isempty(svs) || ~isnumeric(svs) || size(svs, 2) < 2
                continue;
            end

            qsvs = svs(:, 2);
            qsvs = qsvs(isfinite(qsvs));
            if isempty(qsvs)
                continue;
            end

            svs_mean = mean(qsvs);
            svs_max  = max(qsvs);

            re_mean_center = local_relative_error(qmean_center(ir), svs_mean);
            re_mean_wse    = local_relative_error(qmean_wse(ir),    svs_mean);
            re_max_center  = local_relative_error(qmax_center(ir),  svs_max);
            re_max_wse     = local_relative_error(qmax_wse(ir),     svs_max);

            rows(end+1, :) = { ...
                ib, ip, ir, local_reach_id(basins_center(ib), ip, ir), ...
                svs_mean, qmean_center(ir), qmean_wse(ir), ...
                re_mean_center, re_mean_wse, re_mean_wse - re_mean_center, ...
                svs_max, qmax_center(ir), qmax_wse(ir), ...
                re_max_center, re_max_wse, re_max_wse - re_max_center}; %#ok<AGROW>
        end
    end
end

var_names = { ...
    'basin_index', 'path_index', 'reach_index', 'reach_id', ...
    'SVS_mean_Q', 'Qprior_mean_center', 'Qprior_mean_wse', ...
    'relerr_mean_center_percent', 'relerr_mean_wse_percent', ...
    'delta_relerr_mean_wse_minus_center', ...
    'SVS_max_Q', 'Qprior_max_center', 'Qprior_max_wse', ...
    'relerr_max_center_percent', 'relerr_max_wse_percent', ...
    'delta_relerr_max_wse_minus_center'};

if isempty(rows)
    out.reach_table = cell2table(cell(0, numel(var_names)), 'VariableNames', var_names);
else
    out.reach_table = cell2table(rows, 'VariableNames', var_names);
end

out.summary = local_summary(out.reach_table);

disp(out.summary);

end


function n = local_num_paths(basin, fld)

n = 0;
if isfield(basin, fld) && ~isempty(basin.(fld)) && iscell(basin.(fld))
    n = numel(basin.(fld));
end

end


function q = local_prior_vec(basin, fld, ip)

q = [];
if ~isfield(basin, fld) || isempty(basin.(fld)) || numel(basin.(fld)) < ip || ...
        isempty(basin.(fld){ip})
    return;
end

v = basin.(fld){ip};
if isnumeric(v)
    q = v(:, 1);
end

end


function re = local_relative_error(q_prior, q_ref)

if ~isfinite(q_prior) || ~isfinite(q_ref) || q_ref == 0
    re = NaN;
else
    re = abs(q_prior - q_ref) / abs(q_ref) * 100;
end

end


function rid = local_reach_id(basin, ip, ir)

rid = NaN;
if ~isfield(basin, 'paths') || numel(basin.paths) < ip || isempty(basin.paths{ip})
    return;
end

path_ids = basin.paths{ip};
if numel(path_ids) >= ir
    rid = str2double(string(path_ids(ir)));
end

end


function summary = local_summary(T)

metrics = { ...
    'mean', 'relerr_mean_center_percent', 'relerr_mean_wse_percent'; ...
    'max',  'relerr_max_center_percent',  'relerr_max_wse_percent'};

rows = {};

for i = 1:size(metrics, 1)
    label = metrics{i, 1};
    center_col = metrics{i, 2};
    wse_col = metrics{i, 3};

    center_vals = T.(center_col);
    wse_vals = T.(wse_col);
    ok = isfinite(center_vals) & isfinite(wse_vals);
    center_vals = center_vals(ok);
    wse_vals = wse_vals(ok);

    delta = wse_vals - center_vals;

    rows(end+1, :) = { ...
        string(label), ...
        numel(center_vals), ...
        mean(center_vals, 'omitnan'), median(center_vals, 'omitnan'), ...
        mean(wse_vals, 'omitnan'), median(wse_vals, 'omitnan'), ...
        mean(delta, 'omitnan'), median(delta, 'omitnan'), ...
        sum(wse_vals < center_vals), sum(wse_vals > center_vals)}; %#ok<AGROW>
end

summary = cell2table(rows, 'VariableNames', { ...
    'statistic', 'n_reaches', ...
    'mean_relerr_center_percent', 'median_relerr_center_percent', ...
    'mean_relerr_wse_percent', 'median_relerr_wse_percent', ...
    'mean_delta_wse_minus_center', 'median_delta_wse_minus_center', ...
    'n_wse_better', 'n_center_better'});

end
