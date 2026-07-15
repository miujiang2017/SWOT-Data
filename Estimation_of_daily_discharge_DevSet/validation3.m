function [vali_estmed, ...
          vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
          vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
          vali_SADS_interp, vali_MetroMan_interp] = ...
          validation3(Qest_med, sg_path, nR,use_svs) %#ok<INUSD>
% VALIDATION3: 从每条河最早有原始 SWOT Q 产品的日期开始做验证
%
% 起始日期按 reach 单独判断：
%   min(first geoBAM raw, first SIC4DVar raw, first MOMMA raw, first MetroMan raw)
%
% 每个 vali_* 都是 struct，字段：
%   .corr   (nR×1)
%   .rRMSE  (nR×1)
%   .NSE    (nR×1)
%   .rB     (nR×1)
%   .error  (cell)

%% ===== 0. 工具函数：生成全 NaN 的 vali 结构 =====
make_empty_vali = @(nR) struct( ...
    'corr',  nan(nR,1), ...
    'rRMSE', nan(nR,1), ...
    'NSE',   nan(nR,1), ...
    'rB',    nan(nR,1), ...
    'error', {cell(nR,1)} );

%% ===== 1. 每条河 validation 的统一起始日期 =====
start_day_idx = local_first_raw_day_idx(sg_path, nR);

%% ===== 2. KF 中位数估计（Qest_med 不会为空） =====
if use_svs
[corr_med, ~, rRMSE_med, NSE_med, rB_med, error_med] = ...
    vali_calc(Qest_med, sg_path.SVS_Q{1,1}, nR, [], 1, start_day_idx);
else
[corr_med, ~, rRMSE_med, NSE_med, rB_med, error_med] = ...
    vali_calc(Qest_med, sg_path.Gauge_Q{1,1}, nR, [], 1, start_day_idx);
end
vali_estmed = struct( ...
    'corr',  corr_med, ...
    'rRMSE', rRMSE_med, ...
    'NSE',   NSE_med, ...
    'rB',    rB_med, ...
    'error', {error_med} );

%% ===== 3. SIC4DVar 原始 =====
vali_SIC4DVar = local_safe_vali( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', ...
    nR, 2, make_empty_vali, use_svs, start_day_idx);

%% ===== 4. MOMMA 原始 =====
vali_MOMMA = local_safe_vali( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', ...
    nR, 2, make_empty_vali, use_svs, start_day_idx);

%% ===== 5. geoBAM 原始 =====
vali_geoBAM = local_safe_vali( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', ...
    nR, 2, make_empty_vali, use_svs, start_day_idx);

%% ===== 6. SADS 原始 =====
vali_SADS = local_safe_vali( ...
    sg_path, 'Q_SADS', 'day_index_SADS', ...
    nR, 2, make_empty_vali, use_svs, start_day_idx);

%% ===== 7. MetroMan 原始 =====
vali_MetroMan = local_safe_vali( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', ...
    nR, 2, make_empty_vali, use_svs, start_day_idx);

%% ===== 8. SIC4DVar 插值版本 =====
vali_SIC4DVar_interp = local_safe_vali( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', ...
    nR, 3, make_empty_vali, use_svs, start_day_idx);

%% ===== 9. MOMMA 插值版本 =====
vali_MOMMA_interp = local_safe_vali( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', ...
    nR, 3, make_empty_vali, use_svs, start_day_idx);

%% ===== 10. geoBAM 插值版本 =====
vali_geoBAM_interp = local_safe_vali( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', ...
    nR, 3, make_empty_vali, use_svs, start_day_idx);

%% ===== 11. SADS 插值版本 =====
vali_SADS_interp = local_safe_vali( ...
    sg_path, 'Q_SADS', 'day_index_SADS', ...
    nR, 3, make_empty_vali, use_svs, start_day_idx);

%% ===== 12. MetroMan 插值版本 =====
vali_MetroMan_interp = local_safe_vali( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', ...
    nR, 3, make_empty_vali, use_svs, start_day_idx);

end


%% ===== 内部小函数：找每条河最早有原始产品的 day index =====
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
        continue;
    end

    dayidx_all = sg_path.(dayidx_field_name);
    if isempty(dayidx_all) || numel(dayidx_all) < 1 || ...
            isempty(dayidx_all{1}) || isempty(dayidx_all{1,1})
        continue;
    end

    day_idx = dayidx_all{1,1};
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


%% ===== 内部小函数：安全调用 vali_calc，自动处理空产品 =====
function vali_str = local_safe_vali(sg_path, q_field_name, dayidx_field_name, ...
    nR, mode_flag, make_empty_vali, use_svs, start_day_idx)

% 字段是否存在
if ~isfield(sg_path, q_field_name) || ~isfield(sg_path, dayidx_field_name)
    vali_str = make_empty_vali(nR);
    return;
end

Q_cell_all = sg_path.(q_field_name);
dayidx_all = sg_path.(dayidx_field_name);

% 检查 {1,1} 是否存在且非空
if isempty(Q_cell_all) || numel(Q_cell_all) < 1 || ...
        isempty(Q_cell_all{1}) || isempty(Q_cell_all{1,1}) || ...
        isempty(dayidx_all)   || numel(dayidx_all)   < 1 || ...
        isempty(dayidx_all{1})|| isempty(dayidx_all{1,1})
    vali_str = make_empty_vali(nR);
    return;
end

Q_cell  = Q_cell_all{1,1};
day_idx = dayidx_all{1,1};
if use_svs
    [corr_v, ~, rRMSE_v, NSE_v, rB_v, error_v] = ...
        vali_calc(Q_cell, sg_path.SVS_Q{1,1}, nR, day_idx, mode_flag, start_day_idx);
else
    [corr_v, ~, rRMSE_v, NSE_v, rB_v, error_v] = ...
        vali_calc(Q_cell, sg_path.Gauge_Q{1,1}, nR, day_idx, mode_flag, start_day_idx);
end
vali_str = struct( ...
    'corr',  corr_v, ...
    'rRMSE', rRMSE_v, ...
    'NSE',   NSE_v, ...
    'rB',    rB_v, ...
    'error', {error_v} );
end


function [corr_comp_true, RMSE_comp_true, rRMSE_comp_true, NSE_comp_true, rB_comp_true, error_comp_true] = ...
    vali_calc(Q_est, Q, nR, reserve, opt, start_day_idx)

if opt == 1
    nCase = length(Q_est);

    corr_comp_true  = cell(nCase,1);
    RMSE_comp_true  = cell(nCase,1);
    rRMSE_comp_true = cell(nCase,1);
    NSE_comp_true   = cell(nCase,1);
    rB_comp_true    = cell(nCase,1);
    error_comp_true = cell(nCase,1);

    for i = 1:nCase
        corr_comp_true{i}  = nan(nR,1);
        RMSE_comp_true{i}  = nan(nR,1);
        rRMSE_comp_true{i} = nan(nR,1);
        NSE_comp_true{i}   = nan(nR,1);
        rB_comp_true{i}    = nan(nR,1);
        error_comp_true{i} = cell(nR,1);

        for j = 1:nR
            if numel(Q) >= j && ~isempty(Q{j}) && ~isnan(start_day_idx(j))
                Q_tmp_true = Q{j}(2:end,2);
                idx_valid = find(~isnan(Q_tmp_true));
                idx_valid = idx_valid(idx_valid >= start_day_idx(j)-1);

                if ~isempty(idx_valid)
                    % ---- 去均值版本：用于 corr / rRMSE / NSE ----
                    Q_comp_anom = Q_est{i}(j,idx_valid)' - mean(Q_est{i}(j,idx_valid));
                    Q_true_anom = Q_tmp_true(idx_valid)   - mean(Q_tmp_true(idx_valid));

                    corr_comp_true{i}(j,1) = corr(Q_comp_anom, Q_true_anom);
                    RMSE_comp_true{i}(j,1) = sqrt(sum((Q_true_anom - Q_comp_anom).^2));
                    rRMSE_comp_true{i}(j,1) = RMSE_comp_true{i}(j,1) ./ sqrt(sum(Q_true_anom.^2)) * 100;
                    NSE_comp_true{i}(j,1) = 1 - sum((Q_true_anom - Q_comp_anom).^2) / sum((Q_true_anom - mean(Q_true_anom)).^2);

                    % ---- 原值版本：用于 rB / error ----
                    Q_comp_raw = Q_est{i}(j,idx_valid)';
                    Q_true_raw = Q_tmp_true(idx_valid);

                    rB_comp_true{i}(j,1) = abs(mean(Q_true_raw) - mean(Q_comp_raw)) / mean(Q_true_raw) * 100;
                    error_comp_true{i}{j,1} = abs(Q_comp_raw - Q_true_raw);
                else
                    corr_comp_true{i}(j,1)  = nan;
                    RMSE_comp_true{i}(j,1)  = nan;
                    rRMSE_comp_true{i}(j,1) = nan;
                    NSE_comp_true{i}(j,1)   = nan;
                    rB_comp_true{i}(j,1)    = nan;
                    error_comp_true{i}{j,1} = [];
                end
            else
                corr_comp_true{i}(j,1)  = nan;
                RMSE_comp_true{i}(j,1)  = nan;
                rRMSE_comp_true{i}(j,1) = nan;
                NSE_comp_true{i}(j,1)   = nan;
                rB_comp_true{i}(j,1)    = nan;
                error_comp_true{i}{j,1} = [];
            end
        end
    end

elseif opt == 2
    corr_comp_true  = nan(nR,1);
    RMSE_comp_true  = nan(nR,1);
    rRMSE_comp_true = nan(nR,1);
    NSE_comp_true   = nan(nR,1);
    rB_comp_true    = nan(nR,1);
    error_comp_true = cell(nR,1);

    for j = 1:nR
        if numel(reserve) >= j && numel(Q) >= j && ...
                ~isempty(reserve{j}) && ~isempty(Q{j}) && ~isnan(start_day_idx(j))
            Q_tmp_true = Q{j}(2:end,2);
            idx_validQ = find(~isnan(Q_tmp_true));
            idx_valid  = intersect(idx_validQ, reserve{j}-1);
            idx_valid  = idx_valid(idx_valid >= start_day_idx(j)-1);

            if ~isempty(idx_valid)
                Q_est_comp = Q_est(:,2:end);

                % ---- 原值版本：用于 rB / error ----
                Q_comp_raw = cell2mat(Q_est_comp(j,idx_valid))';
                Q_true_raw = Q_tmp_true(idx_valid);

                error_comp_true{j,1} = abs(Q_comp_raw - Q_true_raw);
                rB_comp_true(j,1) = abs(mean(Q_true_raw) - mean(Q_comp_raw)) / mean(Q_true_raw) * 100;

                % ---- 去均值版本：用于 corr / rRMSE / NSE ----
                Q_comp_anom = Q_comp_raw - mean(Q_comp_raw);
                Q_true_anom = Q_true_raw - mean(Q_true_raw);

                corr_comp_true(j,1) = corr(Q_comp_anom, Q_true_anom);
                RMSE_comp_true(j,1) = sqrt(sum((Q_true_anom - Q_comp_anom).^2));
                rRMSE_comp_true(j,1) = RMSE_comp_true(j,1) ./ sqrt(sum(Q_true_anom.^2)) * 100;
                NSE_comp_true(j,1) = 1 - sum((Q_true_anom - Q_comp_anom).^2) / sum((Q_true_anom - mean(Q_true_anom)).^2);
            else
                error_comp_true{j,1} = [];
            end
        else
            error_comp_true{j,1} = [];
        end
    end

elseif opt == 3
    corr_comp_true  = nan(nR,1);
    RMSE_comp_true  = nan(nR,1);
    rRMSE_comp_true = nan(nR,1);
    NSE_comp_true   = nan(nR,1);
    rB_comp_true    = nan(nR,1);
    error_comp_true = cell(nR,1);

    for j = 1:nR
        if numel(reserve) >= j && numel(Q) >= j && ...
                ~isempty(reserve{j}) && ~isempty(Q{j}) && ~isnan(start_day_idx(j))
            Q_tmp_true = Q{j}(2:end,2);
            idx_validQ = find(~isnan(Q_tmp_true));
            idx_eval   = idx_validQ(idx_validQ >= start_day_idx(j)-1);
            idx_valid  = intersect(idx_validQ, reserve{j}-1);

            if length(idx_valid) > 1 && ~isempty(idx_eval)
                Q_est_comp = Q_est(:,2:end);
                Q_tmp = cell2mat(Q_est_comp(j,idx_valid))';

                % 插值到统一起始日期之后 gauge 有值的时刻
                Q_comp_raw = interp1(idx_valid, Q_tmp, idx_eval, 'linear', 'extrap');
                Q_true_raw = Q_tmp_true(idx_eval);

                error_comp_true{j,1} = abs(Q_comp_raw - Q_true_raw);
                rB_comp_true(j,1) = abs(mean(Q_true_raw) - mean(Q_comp_raw)) / mean(Q_true_raw) * 100;

                % ---- 去均值版本：用于 corr / rRMSE / NSE ----
                Q_comp_anom = Q_comp_raw - mean(Q_comp_raw);
                Q_true_anom = Q_true_raw - mean(Q_true_raw);

                corr_comp_true(j,1) = corr(Q_comp_anom, Q_true_anom);
                RMSE_comp_true(j,1) = sqrt(sum((Q_true_anom - Q_comp_anom).^2));
                rRMSE_comp_true(j,1) = RMSE_comp_true(j,1) ./ sqrt(sum(Q_true_anom.^2)) * 100;
                NSE_comp_true(j,1) = 1 - sum((Q_true_anom - Q_comp_anom).^2) / sum((Q_true_anom - mean(Q_true_anom)).^2);
            else
                error_comp_true{j,1} = [];
            end
        else
            error_comp_true{j,1} = [];
        end
    end
end
end
