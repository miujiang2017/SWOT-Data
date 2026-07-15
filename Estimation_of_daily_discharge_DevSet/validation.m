function [vali_estmed, ...
          vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
          vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
          vali_SADS_interp, vali_MetroMan_interp] = ...
          validation(Qest_med, sg_path, nR) %#ok<INUSD>
% VALIDATION: 计算 KF 结果和 SWOT Q 产品的验证指标（含插值版本）
%
% 每个 vali_* 都是 struct，字段：
%   .corr   (nR×1)
%   .rRMSE  (nR×1)
%   .NSE    (nR×1)
%   .rB     (nR×1)
%
% 空产品时四个指标全部设为 NaN(nR,1)。

%% ===== 0. 工具函数：生成全 NaN 的 vali 结构 =====
make_empty_vali = @(nR) struct( ...
    'corr',  nan(nR,1), ...
    'rRMSE', nan(nR,1), ...
    'NSE',   nan(nR,1), ...
    'rB',    nan(nR,1) );

%% ===== 1. KF 中位数估计（Qest_med 不会为空） =====
[corr_med, ~, rRMSE_med, NSE_med, rB_med] = ...
    vali_calc(Qest_med, sg_path.Gauge_Q{1,1}, nR, [], 1);

vali_estmed = struct( ...
    'corr',  corr_med, ...
    'rRMSE', rRMSE_med, ...
    'NSE',   NSE_med, ...
    'rB',    rB_med );

%% ===== 2. SIC4DVar 原始 =====
vali_SIC4DVar = local_safe_vali( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', ...
    nR, 2, make_empty_vali);

%% ===== 3. MOMMA 原始 =====
vali_MOMMA = local_safe_vali( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', ...
    nR, 2, make_empty_vali);

%% ===== 4. geoBAM 原始 =====
vali_geoBAM = local_safe_vali( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', ...
    nR, 2, make_empty_vali);

%% ===== 5. SADS 原始 =====
vali_SADS = local_safe_vali( ...
    sg_path, 'Q_SADS', 'day_index_SADS', ...
    nR, 2, make_empty_vali);

%% ===== 6. MetroMan 原始 =====
vali_MetroMan = local_safe_vali( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', ...
    nR, 2, make_empty_vali);

%% ===== 7. SIC4DVar 插值版本 =====
vali_SIC4DVar_interp = local_safe_vali( ...
    sg_path, 'Q_SIC4DVar', 'day_index_SIC4DVar', ...
    nR, 3, make_empty_vali);

%% ===== 8. MOMMA 插值版本 =====
vali_MOMMA_interp = local_safe_vali( ...
    sg_path, 'Q_MOMMA', 'day_index_MOMMA', ...
    nR, 3, make_empty_vali);

%% ===== 9. geoBAM 插值版本 =====
vali_geoBAM_interp = local_safe_vali( ...
    sg_path, 'Q_geoBAM', 'day_index_geoBAM', ...
    nR, 3, make_empty_vali);

%% ===== 10. SADS 插值版本 =====
vali_SADS_interp = local_safe_vali( ...
    sg_path, 'Q_SADS', 'day_index_SADS', ...
    nR, 3, make_empty_vali);

%% ===== 11. MetroMan 插值版本 =====
vali_MetroMan_interp = local_safe_vali( ...
    sg_path, 'Q_MetroMan', 'day_index_MetroMan', ...
    nR, 3, make_empty_vali);

end


%% ===== 内部小函数：安全调用 vali_calc，自动处理空产品 =====
function vali_str = local_safe_vali(sg_path, q_field_name, dayidx_field_name, ...
    nR, mode_flag, make_empty_vali)

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

[corr_v, ~, rRMSE_v, NSE_v, rB_v] = ...
    vali_calc(Q_cell, sg_path.Gauge_Q{1,1}, nR, day_idx, mode_flag);

vali_str = struct( ...
    'corr',  corr_v, ...
    'rRMSE', rRMSE_v, ...
    'NSE',   NSE_v, ...
    'rB',    rB_v );
end


function [corr_comp_true,RMSE_comp_true,rRMSE_comp_true,NSE_comp_true,rB_comp_true]=vali_calc(Q_est,Q,nR,reserve,opt)

if opt ==1
    for i = 1:length(Q_est)
        for j = 1:nR
            if ~isempty(Q{j})
                Q_tmp_true = Q{j}(2:end,2);
                nt= sum(~isnan(Q_tmp_true));
                idx_valid = find(~isnan(Q_tmp_true)==1);
                if ~isempty(idx_valid)
                    Q_comp = Q_est{i}(j,idx_valid)'-mean(Q_est{i}(j,idx_valid));
                    Q_true = Q_tmp_true(idx_valid)-mean(Q_tmp_true(idx_valid));
                    corr_comp_true{i}(j,1) = corr(Q_comp,Q_true);
                    RMSE_comp_true{i}(j,1) = sqrt(sum((Q_true-Q_comp).^2));
                    rRMSE_comp_true{i}(j,1) = RMSE_comp_true{i}(j)./sqrt(sum(Q_true.^2))*100;


                    % RMSE_comp_true{i}(j,1) = sqrt(mean((Q_true - Q_comp).^2));
                    % rRMSE_comp_true{i}(j,1) = RMSE_comp_true{i}(j,1) / ((mean(abs(Q_comp)) + mean(abs(Q_true)))/2) * 100;

                    NSE_comp_true{i}(j,1) = 1-sum((Q_true-Q_comp).^2)/sum((Q_true-mean(Q_true)).^2);
                    Q_comp = Q_est{i}(j,idx_valid)';
                    Q_true = Q_tmp_true(idx_valid);
                    rB_comp_true{i}(j,1) = abs(mean(Q_true)-mean(Q_comp))/mean(Q_true)*100;
                else
                    corr_comp_true{i}(j,1) = nan;
                    RMSE_comp_true{i}(j,1) = nan;
                    rRMSE_comp_true{i}(j,1) = nan;
                    NSE_comp_true{i}(j,1) = nan;
                    rB_comp_true{i}(j,1) = nan;
                end
            else
                corr_comp_true{i}(j,1) = nan;
                RMSE_comp_true{i}(j,1) = nan;
                rRMSE_comp_true{i}(j,1) = nan;
                NSE_comp_true{i}(j,1) = nan;
                rB_comp_true{i}(j,1) = nan;
            end
        end
        med_corr{i,1} =  nanmedian(corr_comp_true{i});
        med_NSE{i,1} = nanmedian(NSE_comp_true{i});
        med_RMSE{i,1} = nanmedian(RMSE_comp_true{i});
        med_rRMSE{i,1} =  nanmedian(rRMSE_comp_true{i});
        med_rB{i,1} =  nanmedian(rB_comp_true{i});
        %     med_corr{i,1} =  mean(corr_comp_true{i});
        %     med_NSE{i,1} = mean(NSE_comp_true{i});
        %     med_RMSE{i,1} = mean(RMSE_comp_true{i});
        %     med_rRMSE{i,1} =  mean(rRMSE_comp_true{i});
    end
elseif opt ==2
    corr_comp_true = nan(nR,1);
    RMSE_comp_true = nan(nR,1);
    rRMSE_comp_true = nan(nR,1);
    NSE_comp_true = nan(nR,1);
    rB_comp_true = nan(nR,1);
    for j = 1:nR
        if ~isempty(reserve{j})&~isempty(Q{j})
             Q_tmp_true = Q{j}(2:end,2);
            idx_validQ = find(~isnan(Q_tmp_true)==1);
            idx_valid = intersect(idx_validQ,reserve{j}-1);
            if ~isempty(idx_valid)
                Q_est_comp = Q_est(:,2:end);
                Q_comp = cell2mat(Q_est_comp(j,idx_valid))'-mean(cell2mat(Q_est_comp(j,idx_valid)));
                Q_true = Q_tmp_true(idx_valid)-mean(Q_tmp_true(idx_valid));
                corr_comp_true(j) = corr(Q_comp,Q_true);
                RMSE_comp_true(j) = sqrt(sum((Q_true-Q_comp).^2));
                rRMSE_comp_true(j) = RMSE_comp_true(j)./sqrt(sum(Q_true.^2))*100;  

                % RMSE_comp_true(j) = sqrt(mean((Q_true - Q_comp).^2));
                % rRMSE_comp_true(j) = RMSE_comp_true(j) / ((mean(Q_comp) + mean(Q_true))/2) * 100;

                NSE_comp_true(j) = 1-sum((Q_true-Q_comp).^2)/sum((Q_true-mean(Q_true)).^2);
                Q_comp = cell2mat(Q_est_comp(j,idx_valid))';
                Q_true = Q_tmp_true(idx_valid);
                rB_comp_true(j) = abs(mean(Q_true)-mean(Q_comp))/mean(Q_true)*100;
                %         med_corr{j,1} =  median(corr_comp_true(j));
                % med_NSE{j,1} = median(NSE_comp_true(j));
                % med_RMSE{j,1} = median(RMSE_comp_true(j));
                % med_rRMSE{j,1} =  median(rRMSE_comp_true(j));
                % med_rB{j,1} =  median(rB_comp_true(j));
            end
        end

    end
elseif opt ==3
    corr_comp_true = nan(nR,1);
    RMSE_comp_true = nan(nR,1);
    rRMSE_comp_true = nan(nR,1);
    NSE_comp_true = nan(nR,1);
    rB_comp_true = nan(nR,1);
    for j = 1:nR
        if ~isempty(reserve{j})&~isempty(Q{j})
                         Q_tmp_true = Q{j}(2:end,2);
            idx_validQ = find(~isnan(Q_tmp_true)==1);
            nt_interp = max(idx_validQ);
            idx_valid = intersect(idx_validQ,reserve{j}-1);
            tmp= length(idx_valid);
            if tmp>1
                Q_est_comp = Q_est(:,2:end);
                Q_tmp =  cell2mat(Q_est_comp(j,idx_valid))';
                Q_comp = interp1(idx_valid, Q_tmp, idx_validQ, 'linear', 'extrap');
                Q_true = Q_tmp_true(idx_validQ);
                rB_comp_true(j) = abs(mean(Q_true)-mean(Q_comp))/mean(Q_true)*100;
                Q_comp = Q_comp-mean(Q_comp);
                Q_true =  Q_true-mean(Q_true);
                corr_comp_true(j) = corr(Q_comp,Q_true);
                RMSE_comp_true(j) = sqrt(sum((Q_true-Q_comp).^2));
                rRMSE_comp_true(j) = RMSE_comp_true(j)./sqrt(sum(Q_true.^2))*100;
                % 
                % RMSE_comp_true(j) = sqrt(sum((Q_true-Q_comp).^2));
                % rRMSE_comp_true(j) = RMSE_comp_true(j)/ ((mean(Q_comp) + mean(Q_true))/2) * 100;
                NSE_comp_true(j) = 1-sum((Q_true-Q_comp).^2)/sum((Q_true-mean(Q_true)).^2);
                % med_corr{j,1} =  median(corr_comp_true(j));
                % med_NSE{j,1} = median(NSE_comp_true(j));
                % med_RMSE{j,1} = median(RMSE_comp_true(j));
                % med_rRMSE{j,1} =  median(rRMSE_comp_true(j));
                % med_rB{j,1} =  median(rB_comp_true(j));
            end
        end
    end

end
end