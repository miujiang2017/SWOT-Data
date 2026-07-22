function [group_vali_out, group_median, all_group_vali] = validation_flow_group_all2(data_KF_out, Q_results, use_svs)
% validation_flow_group_all2
%
% Version 2: 每条 reach 只从最早有原始 SWOT Q 产品的日期开始做 flow-group validation。
% 起始日期按 reach 单独判断：
%   min(first geoBAM raw, first SIC4DVar raw, first MOMMA raw, first MetroMan raw)
%
% INPUT:
%   data_KF_out
%   Q_results
%   use_svs   optional, default = true
%
% OUTPUT:
%   group_vali_out:
%       按 data_KF_out 的 basin/path 结构对应保存
%
%       group_vali_out(ib).paths(ip).Qest_med.low.corr
%       group_vali_out(ib).paths(ip).Qest_med.mid.rRMSE
%       group_vali_out(ib).paths(ip).SIC4DVar.high.residual
%       ...
%
%   group_median:
%       覆盖所有 basin / path / reach 的 median table
%
%   all_group_vali:
%       所有 basin/path/reach 汇总后的原始集合
%
% FLOW GROUP:
%   low  : gauge/SVS Q <= 15th percentile
%   mid  : 15th percentile < gauge/SVS Q < 85th percentile
%   high : gauge/SVS Q >= 85th percentile
%
% RESIDUAL:
%   residual = Q_product - Q_gauge
%   abs_error = abs(Q_product - Q_gauge)

if nargin < 3
    use_svs = true;
end

products = { ...
    'Qest_med', ...
    'SIC4DVar', 'MOMMA', 'geoBAM', 'SADS', 'MetroMan', ...
    'SIC4DVar_interp', 'MOMMA_interp', 'geoBAM_interp', ...
    'SADS_interp', 'MetroMan_interp'};

groups = {'low', 'mid', 'high'};
metrics = {'corr', 'rRMSE', 'NSE', 'rB', 'n'};

all_group_vali = init_collect(products, groups, metrics);

group_vali_out = struct([]);

for ib = 1:numel(data_KF_out)

    fprintf('Basin %d / %d\n', ib, numel(data_KF_out));

    sg_basin = data_KF_out(ib);

    if ~isfield(sg_basin, 'paths') || isempty(sg_basin.paths)
        warning('Basin %d has no paths. Skip.', ib);
        continue
    end

    nP = numel(sg_basin.paths);

    for ip = 1:nP

        fprintf('   Path %d / %d\n', ip, nP);

        sg_path = get_path_struct(sg_basin, ip);

        if ~isfield(sg_path, 'rch_len') || isempty(sg_path.rch_len) || isempty(sg_path.rch_len{1})
            warning('Basin %d Path %d has no rch_len. Skip.', ib, ip);
            continue
        end

        nR = length(sg_path.rch_len{1});

        if ~isfield(Q_results(ib), 'Qest_med') || ...
                size(Q_results(ib).Qest_med, 2) < ip || ...
                isempty(Q_results(ib).Qest_med{1, ip})
            warning('Basin %d Path %d has no Qest_med. Skip.', ib, ip);
            continue
        end

        Qest_med = Q_results(ib).Qest_med{1, ip};

        path_vali = calc_one_path_group_vali( ...
            Qest_med, sg_path, nR, use_svs, products, groups);

        group_vali_out(ib).paths(ip) = path_vali;

        all_group_vali = append_collect( ...
            all_group_vali, path_vali, products, groups, metrics);

    end
end

group_median = calc_median_table(all_group_vali, products, groups, metrics);

end


%% ========================================================================
function sg_path = get_path_struct(basin, ip)
% GET_PATH_STRUCT
%
% 从 data_KF_out(ib) 中提取第 ip 条 path 的子结构。
% 输出 sg_path 中所有按 path 存的字段都变成 1×1 cell 包裹。
%
% 例如：
%   basin.rch_len = {path1, path2, ...}
%   sg_path.rch_len = {basin.rch_len{ip}}

if ~isfield(basin, 'paths') || isempty(basin.paths)
    error('get_path_struct:NoPaths', ...
        '输入的 basin 结构里没有 paths 字段或为空。');
end

nPath = numel(basin.paths);

if ip < 1 || ip > nPath
    error('get_path_struct:IndexOutOfRange', ...
        'ip=%d 超出可用 path 数量 (1..%d)。', ip, nPath);
end

sg_path = struct();
fns = fieldnames(basin);

for k = 1:numel(fns)

    fld = fns{k};
    val = basin.(fld);

    if iscell(val) && numel(val) == nPath
        sg_path.(fld) = {val{ip}};
    else
        sg_path.(fld) = val;
    end

end

end


%% ========================================================================
function path_vali = calc_one_path_group_vali(Qest_med, sg_path, nR, use_svs, products, groups)

for iprod = 1:numel(products)
    path_vali.(products{iprod}) = make_empty_vali(nR, groups);
end

if use_svs

    if ~isfield(sg_path, 'SVS_Q') || isempty(sg_path.SVS_Q) || isempty(sg_path.SVS_Q{1})
        return
    end

    Q_gauge = sg_path.SVS_Q{1};

else

    if ~isfield(sg_path, 'Gauge_Q') || isempty(sg_path.Gauge_Q) || isempty(sg_path.Gauge_Q{1})
        return
    end

    Q_gauge = sg_path.Gauge_Q{1};

end

start_day_idx = local_first_raw_day_idx(sg_path, nR);

path_vali.Qest_med = calc_Qestmed_vali(Qest_med, Q_gauge, nR, groups, start_day_idx);

path_vali.SIC4DVar = calc_product_vali_safe( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', Q_gauge, nR, groups, 2, start_day_idx);

path_vali.MOMMA = calc_product_vali_safe( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', Q_gauge, nR, groups, 2, start_day_idx);

path_vali.geoBAM = calc_product_vali_safe( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', Q_gauge, nR, groups, 2, start_day_idx);

path_vali.SADS = calc_product_vali_safe( ...
    sg_path, 'Q_SADS', 'day_index_SADS', Q_gauge, nR, groups, 2, start_day_idx);

path_vali.MetroMan = calc_product_vali_safe( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', Q_gauge, nR, groups, 2, start_day_idx);

path_vali.SIC4DVar_interp = calc_product_vali_safe( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', Q_gauge, nR, groups, 3, start_day_idx);

path_vali.MOMMA_interp = calc_product_vali_safe( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', Q_gauge, nR, groups, 3, start_day_idx);

path_vali.geoBAM_interp = calc_product_vali_safe( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', Q_gauge, nR, groups, 3, start_day_idx);

path_vali.SADS_interp = calc_product_vali_safe( ...
    sg_path, 'Q_SADS', 'day_index_SADS', Q_gauge, nR, groups, 3, start_day_idx);

path_vali.MetroMan_interp = calc_product_vali_safe( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', Q_gauge, nR, groups, 3, start_day_idx);

end


%% ========================================================================
function start_day_idx = local_first_raw_day_idx(sg_path, nR)

start_day_idx = nan(nR,1);
dayidx_fields = { ...
    'day_index_geoBAM', ...
    'day_index_SIC4DVar', ...
    'day_index_MOMMA', ...
    'day_index_MetroMan'};

for f = 1:numel(dayidx_fields)
    dayidx_field_name = dayidx_fields{f};

    if ~isfield(sg_path, dayidx_field_name)
        continue
    end

    dayidx_all = sg_path.(dayidx_field_name);
    if isempty(dayidx_all) || isempty(dayidx_all{1})
        continue
    end

    day_idx = dayidx_all{1};
    for j = 1:nR
        if numel(day_idx) >= j && ~isempty(day_idx{j})
            valid_days = day_idx{j}(:);
            valid_days = valid_days(~isnan(valid_days));
            if ~isempty(valid_days)
                candidate = min(valid_days);
                if isnan(start_day_idx(j)) || candidate < start_day_idx(j)
                    start_day_idx(j) = candidate;
                end
            end
        end
    end
end

end


%% ========================================================================
function vali = make_empty_vali(nR, groups)

for ig = 1:numel(groups)

    g = groups{ig};

    vali.(g).corr      = nan(nR,1);
    vali.(g).rRMSE     = nan(nR,1);
    vali.(g).NSE       = nan(nR,1);
    vali.(g).rB        = nan(nR,1);
    vali.(g).n         = nan(nR,1);
    vali.(g).residual  = cell(nR,1);
    vali.(g).abs_error = cell(nR,1);

end

end


%% ========================================================================
function vali = calc_Qestmed_vali(Qest_med, Q_gauge, nR, groups, start_day_idx)

if ~iscell(Qest_med)
    Qest_med = {Qest_med};
end

nCase = numel(Qest_med);

for ig = 1:numel(groups)

    g = groups{ig};

    vali.(g).corr      = nan(nR,nCase);
    vali.(g).rRMSE     = nan(nR,nCase);
    vali.(g).NSE       = nan(nR,nCase);
    vali.(g).rB        = nan(nR,nCase);
    vali.(g).n         = nan(nR,nCase);
    vali.(g).residual  = cell(nR,nCase);
    vali.(g).abs_error = cell(nR,nCase);

end

for icase = 1:nCase

    Q_est = Qest_med{icase};

    for j = 1:nR

        if j > numel(Q_gauge) || isempty(Q_gauge{j}) || isnan(start_day_idx(j))
            continue
        end

        if size(Q_est, 1) < j
            continue
        end

        Q_true_all = Q_gauge{j}(2:end,2);
        idx_valid = find(~isnan(Q_true_all));
        idx_valid = idx_valid(idx_valid >= start_day_idx(j)-1);

        if isempty(idx_valid)
            continue
        end

        idx_valid = idx_valid(idx_valid <= size(Q_est, 2));

        if isempty(idx_valid)
            continue
        end

        group_idx = get_group_idx(Q_true_all, idx_valid);

        for ig = 1:numel(groups)

            g = groups{ig};
            idx_g = group_idx.(g);

            if isempty(idx_g)
                continue
            end

            Q_true_raw = Q_true_all(idx_g);
            Q_comp_raw = Q_est(j, idx_g)';

            metric = calc_metrics(Q_comp_raw, Q_true_raw);

            vali.(g).corr(j,icase)      = metric.corr;
            vali.(g).rRMSE(j,icase)     = metric.rRMSE;
            vali.(g).NSE(j,icase)       = metric.NSE;
            vali.(g).rB(j,icase)        = metric.rB;
            vali.(g).n(j,icase)         = metric.n;
            vali.(g).residual{j,icase}  = metric.residual;
            vali.(g).abs_error{j,icase} = metric.abs_error;

        end
    end
end

end


%% ========================================================================
function vali = calc_product_vali_safe(sg_path, q_field, day_field, Q_gauge, nR, groups, mode_flag, start_day_idx)

vali = make_empty_vali(nR, groups);

if ~isfield(sg_path, q_field) || ~isfield(sg_path, day_field)
    return
end

Q_all = sg_path.(q_field);
day_all = sg_path.(day_field);

if isempty(Q_all) || isempty(Q_all{1})
    return
end

if isempty(day_all) || isempty(day_all{1})
    return
end

Q_prod = Q_all{1};
day_idx = day_all{1};

if isempty(Q_prod)
    return
end

if isempty(day_idx)
    return
end

for j = 1:nR

    if j > numel(Q_gauge) || isempty(Q_gauge{j}) || isnan(start_day_idx(j))
        continue
    end

    if j > numel(day_idx) || isempty(day_idx{j})
        continue
    end

    Q_true_all = Q_gauge{j}(2:end,2);
    idx_validQ = find(~isnan(Q_true_all));
    idx_eval = idx_validQ(idx_validQ >= start_day_idx(j)-1);

    if isempty(idx_eval)
        continue
    end

    Q_prod_comp = Q_prod(:,2:end);

    group_idx = get_group_idx(Q_true_all, idx_eval);

    if mode_flag == 2

        idx_prod = day_idx{j} - 1;
        idx_available = intersect(idx_eval, idx_prod);
        idx_available = idx_available(idx_available <= size(Q_prod_comp, 2));

        if isempty(idx_available)
            continue
        end

        for ig = 1:numel(groups)

            g = groups{ig};
            idx_g = intersect(group_idx.(g), idx_available);

            if isempty(idx_g)
                continue
            end

            try
                Q_comp_raw = cell2mat(Q_prod_comp(j, idx_g))';
            catch
                continue
            end

            Q_true_raw = Q_true_all(idx_g);

            metric = calc_metrics(Q_comp_raw, Q_true_raw);

            vali.(g).corr(j,1)      = metric.corr;
            vali.(g).rRMSE(j,1)     = metric.rRMSE;
            vali.(g).NSE(j,1)       = metric.NSE;
            vali.(g).rB(j,1)        = metric.rB;
            vali.(g).n(j,1)         = metric.n;
            vali.(g).residual{j,1}  = metric.residual;
            vali.(g).abs_error{j,1} = metric.abs_error;

        end

    elseif mode_flag == 3

        idx_prod = intersect(idx_validQ, day_idx{j} - 1);
        idx_prod = idx_prod(idx_prod <= size(Q_prod_comp, 2));

        if numel(idx_prod) <= 1
            continue
        end

        try
            Q_tmp = cell2mat(Q_prod_comp(j, idx_prod))';
        catch
            continue
        end

        if numel(Q_tmp) ~= numel(idx_prod)
            continue
        end

        Q_interp_at_eval = interp1(idx_prod, Q_tmp, idx_eval, 'linear', 'extrap');

        for ig = 1:numel(groups)

            g = groups{ig};
            idx_g_global = group_idx.(g);

            if isempty(idx_g_global)
                continue
            end

            [idx_g, loc] = intersect(idx_g_global, idx_eval);

            if isempty(idx_g)
                continue
            end

            Q_true_raw = Q_true_all(idx_g);
            Q_comp_raw = Q_interp_at_eval(loc);

            metric = calc_metrics(Q_comp_raw, Q_true_raw);

            vali.(g).corr(j,1)      = metric.corr;
            vali.(g).rRMSE(j,1)     = metric.rRMSE;
            vali.(g).NSE(j,1)       = metric.NSE;
            vali.(g).rB(j,1)        = metric.rB;
            vali.(g).n(j,1)         = metric.n;
            vali.(g).residual{j,1}  = metric.residual;
            vali.(g).abs_error{j,1} = metric.abs_error;

        end
    end
end

end


%% ========================================================================
function group_idx = get_group_idx(Q_true_all, idx_valid)

Q_valid = Q_true_all(idx_valid);

q15 = prctile(Q_valid, 15);
q85 = prctile(Q_valid, 85);

group_idx.low  = idx_valid(Q_valid <= q15);
group_idx.mid  = idx_valid(Q_valid > q15 & Q_valid < q85);
group_idx.high = idx_valid(Q_valid >= q85);

end


%% ========================================================================
function metric = calc_metrics(Q_comp_raw, Q_true_raw)

% =========================================================
% Validation metrics for one reach / one product / one flow group
%
% 注意：
%   correlation 对样本数非常敏感。
%   如果只有 2 个有效点，corr 很容易等于 1 或 -1，
%   但统计意义很弱。
%
% 因此这里设置：
%   minN_corr = 5
%
% 即有效点数少于 5 时，不计算 correlation，保持 NaN。
% =========================================================

minN_corr = 10;

Q_comp_raw = Q_comp_raw(:);
Q_true_raw = Q_true_raw(:);

idx = ~isnan(Q_comp_raw) & ~isnan(Q_true_raw);

Q_comp_raw = Q_comp_raw(idx);
Q_true_raw = Q_true_raw(idx);

metric.corr      = nan;
metric.rRMSE     = nan;
metric.NSE       = nan;
metric.rB        = nan;
metric.n         = numel(Q_true_raw);
metric.residual  = [];
metric.abs_error = [];

if isempty(Q_true_raw)
    return
end

% ---------------------------------------------------------
% residual / absolute error
% ---------------------------------------------------------
metric.residual  = Q_comp_raw - Q_true_raw;
metric.abs_error = abs(Q_comp_raw - Q_true_raw);

% ---------------------------------------------------------
% rBias
% ---------------------------------------------------------
if mean(Q_true_raw) ~= 0
    metric.rB = abs(mean(Q_true_raw) - mean(Q_comp_raw)) / abs(mean(Q_true_raw)) * 100;
end

% ---------------------------------------------------------
% anomaly
% ---------------------------------------------------------
Q_comp_anom = Q_comp_raw - mean(Q_comp_raw);
Q_true_anom = Q_true_raw - mean(Q_true_raw);

denom = sum(Q_true_anom.^2);

% ---------------------------------------------------------
% rRMSE / NSE
%
% 这里仍然允许 n >= 2 时计算。
% 如果 gauge 在该 flow group 内没有变化，denom = 0，则保持 NaN。
% ---------------------------------------------------------
if numel(Q_true_raw) >= 2 && denom > 0
    metric.rRMSE = sqrt(sum((Q_true_anom - Q_comp_anom).^2)) / sqrt(denom) * 100;
    metric.NSE = 1 - sum((Q_true_anom - Q_comp_anom).^2) / denom;
end

% ---------------------------------------------------------
% correlation
%
% 至少需要 minN_corr 个有效点；
% 同时两个序列都必须有变化。
% ---------------------------------------------------------
if numel(Q_true_raw) >= minN_corr && ...
        std(Q_comp_raw) > 0 && ...
        std(Q_true_raw) > 0

    metric.corr = corr(Q_comp_raw, Q_true_raw);
end

end
%% ========================================================================
function all_group_vali = init_collect(products, groups, metrics)

for ip = 1:numel(products)

    p = products{ip};

    for ig = 1:numel(groups)

        g = groups{ig};

        for im = 1:numel(metrics)

            m = metrics{im};
            all_group_vali.(p).(g).(m) = [];

        end

        all_group_vali.(p).(g).residual = {};
        all_group_vali.(p).(g).abs_error = {};

    end
end

end


%% ========================================================================
function all_group_vali = append_collect(all_group_vali, path_vali, products, groups, metrics)

for ip = 1:numel(products)

    p = products{ip};

    for ig = 1:numel(groups)

        g = groups{ig};

        for im = 1:numel(metrics)

            m = metrics{im};
            tmp = path_vali.(p).(g).(m);

            all_group_vali.(p).(g).(m) = [ ...
                all_group_vali.(p).(g).(m); ...
                tmp(:)];

        end

        res_tmp = path_vali.(p).(g).residual(:);
        err_tmp = path_vali.(p).(g).abs_error(:);

        valid_res = ~cellfun(@isempty, res_tmp);
        valid_err = ~cellfun(@isempty, err_tmp);

        all_group_vali.(p).(g).residual = [ ...
            all_group_vali.(p).(g).residual; ...
            res_tmp(valid_res)];

        all_group_vali.(p).(g).abs_error = [ ...
            all_group_vali.(p).(g).abs_error; ...
            err_tmp(valid_err)];

    end
end

end


%% ========================================================================
function group_median = calc_median_table(all_group_vali, products, groups, metrics)

product_col = {};
group_col = {};
metric_col = {};
median_col = [];
count_col = [];

for ip = 1:numel(products)

    p = products{ip};

    for ig = 1:numel(groups)

        g = groups{ig};

        for im = 1:numel(metrics)

            m = metrics{im};

            vals = all_group_vali.(p).(g).(m);
            vals = vals(~isnan(vals));

            product_col{end+1,1} = p;
            group_col{end+1,1} = g;
            metric_col{end+1,1} = m;

            if isempty(vals)
                median_col(end+1,1) = nan;
                count_col(end+1,1) = 0;
            else
                median_col(end+1,1) = median(vals, 'omitnan');
                count_col(end+1,1) = numel(vals);
            end

        end

        res_cell = all_group_vali.(p).(g).residual;

        if isempty(res_cell)
            res_all = [];
        else
            res_all = cell2mat(res_cell(:));
            res_all = res_all(~isnan(res_all));
        end

        product_col{end+1,1} = p;
        group_col{end+1,1} = g;
        metric_col{end+1,1} = 'residual';

        if isempty(res_all)
            median_col(end+1,1) = nan;
            count_col(end+1,1) = 0;
        else
            median_col(end+1,1) = median(res_all, 'omitnan');
            count_col(end+1,1) = numel(res_all);
        end

        err_cell = all_group_vali.(p).(g).abs_error;

        if isempty(err_cell)
            err_all = [];
        else
            err_all = cell2mat(err_cell(:));
            err_all = err_all(~isnan(err_all));
        end

        product_col{end+1,1} = p;
        group_col{end+1,1} = g;
        metric_col{end+1,1} = 'abs_error';

        if isempty(err_all)
            median_col(end+1,1) = nan;
            count_col(end+1,1) = 0;
        else
            median_col(end+1,1) = median(err_all, 'omitnan');
            count_col(end+1,1) = numel(err_all);
        end

    end
end

group_median = table(product_col, group_col, metric_col, median_col, count_col, ...
    'VariableNames', {'product', 'flow_group', 'metric', 'median', 'count'});

end
