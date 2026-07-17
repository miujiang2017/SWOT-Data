function [data_KF_out, removed_info] = filter_KF(data_KF)
% FILTER_KF: 删除 RiverSP 三字段中“全空”的 path
%
% 删除条件：
%   若 wse_RiverSP 或 width_RiverSP 或 slope_RiverSP 中，
%   该 path 的 n×m cell 全部为 []，则删除该 path。
%   若 wse_RiverSP 中，该 path 的每一个 reach 都只有 <= 4 个有效观测，
%   也删除该 path。
%
% filter 完以后：
%   对每个 product，在每个 SVS/gauge reach 上计算：
%
%       ratio = product 有效天数 / SVS_Q 有效天数 * 100
%
%   但只有 product 在该 SVS reach 上至少有一个有效值时，才参与统计。
%
%   然后把所有 basin/path/reach 的 ratio 合并，
%   对每个 product 打印 overall mean 和 median。
%
% 只打印，不存储。

data_KF_out = data_KF;

nB = numel(data_KF_out);
sp_fields = {'wse_RiverSP','width_RiverSP','slope_RiverSP'};
min_wse_obs_per_reach = 4;

keep_basin = true(nB,1);

removed_info = struct();
removed_info.basin = [];
removed_info.path  = [];
removed_info.reason = {};

for ib = 1:nB

    n_paths = [];

    if isfield(data_KF_out(ib),'paths') && iscell(data_KF_out(ib).paths)
        n_paths = numel(data_KF_out(ib).paths);
    else
        for k = 1:numel(sp_fields)
            fld = sp_fields{k};
            if isfield(data_KF_out(ib), fld) && iscell(data_KF_out(ib).(fld))
                n_paths = numel(data_KF_out(ib).(fld));
                break;
            end
        end
    end

    if isempty(n_paths) || n_paths == 0
        continue;
    end

    keep_flags = true(n_paths,1);

    for p = 1:n_paths

        field_all_empty = false(1, numel(sp_fields));

        for k = 1:numel(sp_fields)

            fld = sp_fields{k};

            if ~isfield(data_KF_out(ib), fld) || ...
               ~iscell(data_KF_out(ib).(fld)) || ...
               numel(data_KF_out(ib).(fld)) < p

                field_all_empty(k) = true;
                continue;
            end

            sp_path = data_KF_out(ib).(fld){p};

            if isempty(sp_path)
                field_all_empty(k) = true;
            elseif iscell(sp_path)
                field_all_empty(k) = all(cellfun('isempty', sp_path(:)));
            else
                field_all_empty(k) = false;
            end
        end

        remove_reason = '';

        if any(field_all_empty)
            remove_reason = 'empty_riversp_field';
        elseif path_has_too_few_wse_obs(data_KF_out(ib), p, min_wse_obs_per_reach)
            remove_reason = 'too_few_wse_observations';
        end

        if ~isempty(remove_reason)

            keep_flags(p) = false;

            removed_info.basin(end+1,1) = ib;
            removed_info.path(end+1,1)  = p;
            removed_info.reason{end+1,1} = remove_reason;
        end
    end

    if ~any(keep_flags)

        keep_basin(ib) = false;
        continue;
    end

    fields_kf = fieldnames(data_KF_out(ib));

    for f = 1:numel(fields_kf)

        fld = fields_kf{f};
        val = data_KF_out(ib).(fld);

        if iscell(val) && numel(val) == n_paths
            data_KF_out(ib).(fld) = val(keep_flags);
        end
    end
end

data_KF_out = data_KF_out(keep_basin);

print_product_ratio_relative_to_svs_nonzero_only(data_KF_out);

end


function tf = path_has_too_few_wse_obs(basin_data, path_idx, min_obs)
% true: 这个 path 里没有任何 reach 的 WSE 有效观测数超过 min_obs。

tf = true;

if ~isfield(basin_data, 'wse_RiverSP') || ...
        ~iscell(basin_data.wse_RiverSP) || ...
        numel(basin_data.wse_RiverSP) < path_idx
    return;
end

wse_path = basin_data.wse_RiverSP{path_idx};

if isempty(wse_path) || ~iscell(wse_path)
    return;
end

n_reach = size(wse_path, 1);

for r = 1:n_reach
    n_valid_obs = count_valid_wse_obs(wse_path(r, :));
    if n_valid_obs > min_obs
        tf = false;
        return;
    end
end
end


function n = count_valid_wse_obs(wse_row)
% 按天数 cell 统计有效 WSE 观测。一个 day cell 里只要有 finite numeric 值，
% 就算这个 reach 在这一天有一个有效观测。

n = 0;

for d = 1:numel(wse_row)
    v = wse_row{d};

    if isempty(v) || ~isnumeric(v)
        continue;
    end

    if any(isfinite(v(:)))
        n = n + 1;
    end
end
end


% =========================================================
% 每个 product：
%   对每个 SVS/gauge reach 计算：
%       ratio = product 在 SVS_Q 有效日中的有效天数 / SVS_Q 有效天数 * 100
%
% 重要：
%   如果某个 product 在该 reach 上没有任何对应 SVS_Q 日期的有效值，
%   即 n_product_valid_on_svs == 0，
%   那这个 reach 不参与该 product 的 mean / median。
%
% 只打印，不存储。
% =========================================================
function print_product_ratio_relative_to_svs_nonzero_only(data_KF_out)

product_fields = { ...
    'Q_MOMMA', ...
    'Q_SIC4DVar', ...
    'Q_geoBAM', ...
    'Q_SADS', ...
    'Q_MetroMan'};

product_names = { ...
    'MOMMA', ...
    'SIC4DVar', ...
    'geoBAM', ...
    'SADS', ...
    'MetroMan'};

n_prod = numel(product_fields);

all_ratio_percent = cell(n_prod, 1);

for ib = 1:numel(data_KF_out)

    if ~isfield(data_KF_out(ib), 'SVS_Q') || isempty(data_KF_out(ib).SVS_Q)
        continue;
    end

    for ip = 1:n_prod

        qfld = product_fields{ip};

        if ~isfield(data_KF_out(ib), qfld) || isempty(data_KF_out(ib).(qfld))
            continue;
        end

        n_paths = min(numel(data_KF_out(ib).SVS_Q), numel(data_KF_out(ib).(qfld)));

        for p = 1:n_paths

            svs_path  = data_KF_out(ib).SVS_Q{p};
            prod_path = data_KF_out(ib).(qfld){p};

            if isempty(svs_path) || isempty(prod_path) || ...
                    ~iscell(svs_path) || ~iscell(prod_path)
                continue;
            end

            nR = min(numel(svs_path), size(prod_path, 1));

            for r = 1:nR

                if isempty(svs_path{r}) || ...
                        ~isnumeric(svs_path{r}) || ...
                        size(svs_path{r}, 2) < 2
                    continue;
                end

                svs_q = svs_path{r}(:, 2);

                n_days = min(numel(svs_q), size(prod_path, 2));

                if n_days == 0
                    continue;
                end

                svs_q = svs_q(1:n_days);
                svs_valid = isfinite(svs_q(:));

                n_svs_valid = sum(svs_valid);

                if n_svs_valid == 0
                    continue;
                end

                product_valid = false(n_days, 1);

                for d = 1:n_days

                    val = prod_path{r, d};

                    if isempty(val) || ~isnumeric(val)
                        continue;
                    end

                    val = val(:);
                    val = val(isfinite(val));

                    if ~isempty(val)
                        product_valid(d) = true;
                    end
                end

                n_product_valid_on_svs = sum(product_valid & svs_valid);

                % 关键：这个 product 在这个 SVS reach 上完全没有值，就不要算 0%
                if n_product_valid_on_svs == 0
                    continue;
                end

                ratio_percent = 100 * n_product_valid_on_svs / n_svs_valid;

                all_ratio_percent{ip} = [all_ratio_percent{ip}; ratio_percent]; %#ok<AGROW>
            end
        end
    end
end

mean_ratio_percent   = nan(n_prod, 1);
median_ratio_percent = nan(n_prod, 1);
n_svs_reaches_used   = zeros(n_prod, 1);

for ip = 1:n_prod

    ratio_vals = all_ratio_percent{ip};
    ratio_vals = ratio_vals(isfinite(ratio_vals));

    n_svs_reaches_used(ip) = numel(ratio_vals);

    if isempty(ratio_vals)
        continue;
    end

    mean_ratio_percent(ip)   = mean(ratio_vals, 'omitnan');
    median_ratio_percent(ip) = median(ratio_vals, 'omitnan');
end

summary_ratio = table( ...
    string(product_names(:)), ...
    n_svs_reaches_used, ...
    mean_ratio_percent, ...
    median_ratio_percent, ...
    'VariableNames', { ...
        'product', ...
        'n_svs_reaches_used', ...
        'mean_valid_ratio_percent', ...
        'median_valid_ratio_percent'} ...
    );

fprintf('\nOverall product valid ratio relative to SVS_Q-valid time points after filtering:\n');
disp(summary_ratio);

end
