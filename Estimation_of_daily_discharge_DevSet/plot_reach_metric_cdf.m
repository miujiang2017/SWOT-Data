function est_median = plot_reach_metric_cdf(Q_results)
% 对所有 reach（跨 basin、跨 path）：
%   - 收集 corr / NSE / rRMSE / rB 的所有值（omitnan）
%   - 然后画 ECDF（CDF）
%   - 主产品 = 实线，interpolated = 虚线
% 额外功能：
%   - 输出并返回 est(KF) 的各个 metric 的 reach-wise median（omitnan）

% ========== 收集所有 reach 的 metric ==========
all = struct( ...
    'corr_est', [], 'corr_SIC', [], 'corr_MOM', [], 'corr_geo', [], 'corr_SADS', [], 'corr_MM', [], ...
    'corr_SIC_i', [], 'corr_MOM_i', [], 'corr_geo_i', [], 'corr_SADS_i', [], 'corr_MM_i', [], ...
    'NSE_est',[], 'NSE_SIC',[], 'NSE_MOM',[], 'NSE_geo',[], 'NSE_SADS',[], 'NSE_MM',[], ...
    'NSE_SIC_i',[], 'NSE_MOM_i',[], 'NSE_geo_i',[], 'NSE_SADS_i',[], 'NSE_MM_i',[], ...
    'rRMSE_est',[], 'rRMSE_SIC',[], 'rRMSE_MOM',[], 'rRMSE_geo',[], 'rRMSE_SADS',[], 'rRMSE_MM',[], ...
    'rRMSE_SIC_i',[], 'rRMSE_MOM_i',[], 'rRMSE_geo_i',[], 'rRMSE_SADS_i',[], 'rRMSE_MM_i',[], ...
    'rB_est',[], 'rB_SIC',[], 'rB_MOM',[], 'rB_geo',[], 'rB_SADS',[], 'rB_MM',[], ...
    'rB_SIC_i',[], 'rB_MOM_i',[], 'rB_geo_i',[], 'rB_SADS_i',[], 'rB_MM_i',[] );

for ib = 1:numel(Q_results)

    if ~isfield(Q_results(ib), "vali_estmed") || isempty(Q_results(ib).vali_estmed)
        continue
    end
    nPath = size(Q_results(ib).vali_estmed, 2);

    for p = 1:nPath

        % ---- 主产品 ----
        vE  = safe_cell(Q_results(ib), "vali_estmed",           1, p);

        vS  = safe_cell(Q_results(ib), "vali_SIC4DVar",         1, p);
        vM  = safe_cell(Q_results(ib), "vali_MOMMA",            1, p);
        vG  = safe_cell(Q_results(ib), "vali_geoBAM",           1, p);
        vA  = safe_cell(Q_results(ib), "vali_SADS",             1, p);
        vMM = safe_cell(Q_results(ib), "vali_MetroMan",         1, p);

        % ---- 插值版本 ----
        vSi = safe_cell(Q_results(ib), "vali_SIC4DVar_interp",  1, p);
        vMi = safe_cell(Q_results(ib), "vali_MOMMA_interp",     1, p);
        vGi = safe_cell(Q_results(ib), "vali_geoBAM_interp",    1, p);
        vAi = safe_cell(Q_results(ib), "vali_SADS_interp",      1, p);
        vMMi= safe_cell(Q_results(ib), "vali_MetroMan_interp",  1, p);

        % 只要 KF 有，就纳入；产品缺失就只是不加该产品（避免强制口径一致导致丢样本）
        if isempty(vE)
            continue;
        end

        % ---- corr ----
        all.corr_est   = [all.corr_est;   col(vE, "corr")];

        all.corr_SIC   = [all.corr_SIC;   col(vS, "corr")];
        all.corr_MOM   = [all.corr_MOM;   col(vM, "corr")];
        all.corr_geo   = [all.corr_geo;   col(vG, "corr")];
        all.corr_SADS  = [all.corr_SADS;  col(vA, "corr")];
        all.corr_MM    = [all.corr_MM;    col(vMM,"corr")];

        all.corr_SIC_i = [all.corr_SIC_i; col(vSi,"corr")];
        all.corr_MOM_i = [all.corr_MOM_i; col(vMi,"corr")];
        all.corr_geo_i = [all.corr_geo_i; col(vGi,"corr")];
        all.corr_SADS_i= [all.corr_SADS_i;col(vAi,"corr")];
        all.corr_MM_i  = [all.corr_MM_i;  col(vMMi,"corr")];

        % ---- NSE ----
        all.NSE_est    = [all.NSE_est;    col(vE, "NSE")];

        all.NSE_SIC    = [all.NSE_SIC;    col(vS, "NSE")];
        all.NSE_MOM    = [all.NSE_MOM;    col(vM, "NSE")];
        all.NSE_geo    = [all.NSE_geo;    col(vG, "NSE")];
        all.NSE_SADS   = [all.NSE_SADS;   col(vA, "NSE")];
        all.NSE_MM     = [all.NSE_MM;     col(vMM,"NSE")];

        all.NSE_SIC_i  = [all.NSE_SIC_i;  col(vSi,"NSE")];
        all.NSE_MOM_i  = [all.NSE_MOM_i;  col(vMi,"NSE")];
        all.NSE_geo_i  = [all.NSE_geo_i;  col(vGi,"NSE")];
        all.NSE_SADS_i = [all.NSE_SADS_i; col(vAi,"NSE")];
        all.NSE_MM_i   = [all.NSE_MM_i;   col(vMMi,"NSE")];

        % ---- rRMSE ----
        all.rRMSE_est  = [all.rRMSE_est;  col(vE, "rRMSE")];

        all.rRMSE_SIC  = [all.rRMSE_SIC;  col(vS, "rRMSE")];
        all.rRMSE_MOM  = [all.rRMSE_MOM;  col(vM, "rRMSE")];
        all.rRMSE_geo  = [all.rRMSE_geo;  col(vG, "rRMSE")];
        all.rRMSE_SADS = [all.rRMSE_SADS; col(vA, "rRMSE")];
        all.rRMSE_MM   = [all.rRMSE_MM;   col(vMM,"rRMSE")];

        all.rRMSE_SIC_i= [all.rRMSE_SIC_i;col(vSi,"rRMSE")];
        all.rRMSE_MOM_i= [all.rRMSE_MOM_i;col(vMi,"rRMSE")];
        all.rRMSE_geo_i= [all.rRMSE_geo_i;col(vGi,"rRMSE")];
        all.rRMSE_SADS_i=[all.rRMSE_SADS_i;col(vAi,"rRMSE")];
        all.rRMSE_MM_i = [all.rRMSE_MM_i; col(vMMi,"rRMSE")];

        % ---- rB ----
        all.rB_est     = [all.rB_est;     col(vE, "rB")];

        all.rB_SIC     = [all.rB_SIC;     col(vS, "rB")];
        all.rB_MOM     = [all.rB_MOM;     col(vM, "rB")];
        all.rB_geo     = [all.rB_geo;     col(vG, "rB")];
        all.rB_SADS    = [all.rB_SADS;    col(vA, "rB")];
        all.rB_MM      = [all.rB_MM;      col(vMM,"rB")];

        all.rB_SIC_i   = [all.rB_SIC_i;   col(vSi,"rB")];
        all.rB_MOM_i   = [all.rB_MOM_i;   col(vMi,"rB")];
        all.rB_geo_i   = [all.rB_geo_i;   col(vGi,"rB")];
        all.rB_SADS_i  = [all.rB_SADS_i;  col(vAi,"rB")];
        all.rB_MM_i    = [all.rB_MM_i;    col(vMMi,"rB")];

    end
end

% ========== 清理 NaN ==========
fn = fieldnames(all);
for i = 1:numel(fn)
    x = all.(fn{i});
    x = x(:);
    all.(fn{i}) = x(~isnan(x));
end

% ========== 输出并返回 est 的 reach-wise median ==========
est_median = struct();
est_median.corr  = median(all.corr_est,  'omitnan');
est_median.NSE   = median(all.NSE_est,   'omitnan');
est_median.rRMSE = median(all.rRMSE_est, 'omitnan');
est_median.rB    = median(all.rB_est,    'omitnan');

SIC_median = struct();
SIC_median.corr  = median(all.corr_SIC,  'omitnan');
SIC_median.NSE   = median(all.NSE_SIC,   'omitnan');
SIC_median.rRMSE = median(all.rRMSE_SIC, 'omitnan');
SIC_median.rB    = median(all.rB_SIC,    'omitnan');

MOM_median = struct();
MOM_median.corr  = median(all.corr_MOM,  'omitnan');
MOM_median.NSE   = median(all.NSE_MOM,   'omitnan');
MOM_median.rRMSE = median(all.rRMSE_MOM, 'omitnan');
MOM_median.rB    = median(all.rB_MOM,    'omitnan');

geo_median = struct();
geo_median.corr  = median(all.corr_geo,  'omitnan');
geo_median.NSE   = median(all.NSE_geo,   'omitnan');
geo_median.rRMSE = median(all.rRMSE_geo, 'omitnan');
geo_median.rB    = median(all.rB_geo,    'omitnan');

MM_median = struct();
MM_median.corr  = median(all.corr_MM,  'omitnan');
MM_median.NSE   = median(all.NSE_MM,   'omitnan');
MM_median.rRMSE = median(all.rRMSE_MM, 'omitnan');
MM_median.rB    = median(all.rB_MM,    'omitnan');

SIC_i_median = struct();
SIC_i_median.corr  = median(all.corr_SIC_i,  'omitnan');
SIC_i_median.NSE   = median(all.NSE_SIC_i,   'omitnan');
SIC_i_median.rRMSE = median(all.rRMSE_SIC_i, 'omitnan');
SIC_i_median.rB    = median(all.rB_SIC_i,    'omitnan');

MOM_i_median = struct();
MOM_i_median.corr  = median(all.corr_MOM_i,  'omitnan');
MOM_i_median.NSE   = median(all.NSE_MOM_i,   'omitnan');
MOM_i_median.rRMSE = median(all.rRMSE_MOM_i, 'omitnan');
MOM_i_median.rB    = median(all.rB_MOM_i,    'omitnan');

geo_i_median = struct();
geo_i_median.corr  = median(all.corr_geo_i,  'omitnan');
geo_i_median.NSE   = median(all.NSE_geo_i,   'omitnan');
geo_i_median.rRMSE = median(all.rRMSE_geo_i, 'omitnan');
geo_i_median.rB    = median(all.rB_geo_i,    'omitnan');

MM_i_median = struct();
MM_i_median.corr  = median(all.corr_MM_i,  'omitnan');
MM_i_median.NSE   = median(all.NSE_MM_i,   'omitnan');
MM_i_median.rRMSE = median(all.rRMSE_MM_i, 'omitnan');
MM_i_median.rB    = median(all.rB_MM_i,    'omitnan');

fprintf('\n=== Reach-wise median (est / KF) ===\n');
fprintf('N(corr)  = %d | median corr  = %.6f\n', numel(all.corr_est),  est_median.corr);
fprintf('N(NSE)   = %d | median NSE   = %.6f\n', numel(all.NSE_est),   est_median.NSE);
fprintf('N(rRMSE) = %d | median rRMSE = %.6f\n', numel(all.rRMSE_est), est_median.rRMSE);
fprintf('N(rB)    = %d | median rB    = %.6f\n', numel(all.rB_est),    est_median.rB);
fprintf('====================================\n\n');

fprintf('Sample sizes (after NaN removal):\n');
fprintf('  corr:  est=%d SIC=%d MOM=%d geo=%d SADS=%d MM=%d | SICi=%d MOMi=%d geoi=%d SADSi=%d MMi=%d\n', ...
    numel(all.corr_est), numel(all.corr_SIC), numel(all.corr_MOM), numel(all.corr_geo), numel(all.corr_SADS), numel(all.corr_MM), ...
    numel(all.corr_SIC_i), numel(all.corr_MOM_i), numel(all.corr_geo_i), numel(all.corr_SADS_i), numel(all.corr_MM_i));
fprintf('  NSE :  est=%d SIC=%d MOM=%d geo=%d SADS=%d MM=%d | SICi=%d MOMi=%d geoi=%d SADSi=%d MMi=%d\n', ...
    numel(all.NSE_est), numel(all.NSE_SIC), numel(all.NSE_MOM), numel(all.NSE_geo), numel(all.NSE_SADS), numel(all.NSE_MM), ...
    numel(all.NSE_SIC_i), numel(all.NSE_MOM_i), numel(all.NSE_geo_i), numel(all.NSE_SADS_i), numel(all.NSE_MM_i));
fprintf('  rRMSE: est=%d SIC=%d MOM=%d geo=%d SADS=%d MM=%d | SICi=%d MOMi=%d geoi=%d SADSi=%d MMi=%d\n', ...
    numel(all.rRMSE_est), numel(all.rRMSE_SIC), numel(all.rRMSE_MOM), numel(all.rRMSE_geo), numel(all.rRMSE_SADS), numel(all.rRMSE_MM), ...
    numel(all.rRMSE_SIC_i), numel(all.rRMSE_MOM_i), numel(all.rRMSE_geo_i), numel(all.rRMSE_SADS_i), numel(all.rRMSE_MM_i));
fprintf('  rB  :  est=%d SIC=%d MOM=%d geo=%d SADS=%d MM=%d | SICi=%d MOMi=%d geoi=%d SADSi=%d MMi=%d\n\n', ...
    numel(all.rB_est), numel(all.rB_SIC), numel(all.rB_MOM), numel(all.rB_geo), numel(all.rB_SADS), numel(all.rB_MM), ...
    numel(all.rB_SIC_i), numel(all.rB_MOM_i), numel(all.rB_geo_i), numel(all.rB_SADS_i), numel(all.rB_MM_i));

%% ====== 绘图布局 ======
lineW      = 2;
fontSize   = 16;
fontWeight = 'normal';

% ===== 颜色定义 =====
cKF  = [0 0.4470 0.7410];      % 蓝色
cSIC = [0.6350 0.0780 0.1840]; % 红色
cMOM = [0.4660 0.6740 0.1880]; % 绿色
cGEO = [0.4940 0.1840 0.5560]; % 紫色
cMM  = [0.9290 0.6940 0.1250]; % 黄色

figure;

%% -------- 1. corr --------
subplot(2,2,1); hold on;

hSIC_corr   = plot_ecdf_style(all.corr_SIC,'-',lineW,cSIC);
hSICi_corr  = plot_ecdf_style(all.corr_SIC_i,'--',lineW,cSIC);

hMOM_corr   = plot_ecdf_style(all.corr_MOM,'-',lineW,cMOM);
hMOMi_corr  = plot_ecdf_style(all.corr_MOM_i,'--',lineW,cMOM);

hGEO_corr   = plot_ecdf_style(all.corr_geo,'-',lineW,cGEO);
hGEOi_corr  = plot_ecdf_style(all.corr_geo_i,'--',lineW,cGEO);

hMM_corr    = plot_ecdf_style(all.corr_MM,'-',lineW,cMM);
hMMi_corr   = plot_ecdf_style(all.corr_MM_i,'--',lineW,cMM);

hEST_corr   = plot_ecdf_style(all.corr_est,'-',lineW,cKF);   % 最后画

title('(a). Correlation','FontSize',fontSize+2,'FontWeight',fontWeight);
xlabel('[-]','FontSize',fontSize,'FontWeight',fontWeight);
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
grid on;

%% -------- 2. NSE --------
subplot(2,2,2); hold on;

plot_ecdf_style(all.NSE_SIC,'-',lineW,cSIC);
plot_ecdf_style(all.NSE_SIC_i,'--',lineW,cSIC);

plot_ecdf_style(all.NSE_MOM,'-',lineW,cMOM);
plot_ecdf_style(all.NSE_MOM_i,'--',lineW,cMOM);

plot_ecdf_style(all.NSE_geo,'-',lineW,cGEO);
plot_ecdf_style(all.NSE_geo_i,'--',lineW,cGEO);

plot_ecdf_style(all.NSE_MM,'-',lineW,cMM);
plot_ecdf_style(all.NSE_MM_i,'--',lineW,cMM);

plot_ecdf_style(all.NSE_est,'-',lineW,cKF);   % 最后画

title('(b). NSE','FontSize',fontSize+2,'FontWeight',fontWeight);
xlabel('[-]','FontSize',fontSize,'FontWeight',fontWeight);
xlim([-2,1]);
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
grid on;

%% -------- 3. rRMSE --------
subplot(2,2,3); hold on;

plot_ecdf_style(all.rRMSE_SIC,'-',lineW,cSIC);
plot_ecdf_style(all.rRMSE_SIC_i,'--',lineW,cSIC);

plot_ecdf_style(all.rRMSE_MOM,'-',lineW,cMOM);
plot_ecdf_style(all.rRMSE_MOM_i,'--',lineW,cMOM);

plot_ecdf_style(all.rRMSE_geo,'-',lineW,cGEO);
plot_ecdf_style(all.rRMSE_geo_i,'--',lineW,cGEO);

plot_ecdf_style(all.rRMSE_MM,'-',lineW,cMM);
plot_ecdf_style(all.rRMSE_MM_i,'--',lineW,cMM);

plot_ecdf_style(all.rRMSE_est,'-',lineW,cKF);   % 最后画

title('(c). rRMSE','FontSize',fontSize+2,'FontWeight',fontWeight);
xlabel('[%]','FontSize',fontSize,'FontWeight',fontWeight);
xlim([0,600]);
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
grid on;

%% -------- 4. rB --------
subplot(2,2,4); hold on;

plot_ecdf_style(all.rB_SIC,'-',lineW,cSIC);
plot_ecdf_style(all.rB_SIC_i,'--',lineW,cSIC);

plot_ecdf_style(all.rB_MOM,'-',lineW,cMOM);
plot_ecdf_style(all.rB_MOM_i,'--',lineW,cMOM);

plot_ecdf_style(all.rB_geo,'-',lineW,cGEO);
plot_ecdf_style(all.rB_geo_i,'--',lineW,cGEO);

plot_ecdf_style(all.rB_MM,'-',lineW,cMM);
plot_ecdf_style(all.rB_MM_i,'--',lineW,cMM);

plot_ecdf_style(all.rB_est,'-',lineW,cKF);   % 最后画

title('(d). rBias','FontSize',fontSize+2,'FontWeight',fontWeight);
xlabel('[%]','FontSize',fontSize,'FontWeight',fontWeight);
xlim([0,400]);
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
grid on;
han = axes(gcf,'visible','off');
han.YLabel.Visible = 'on';
ylabel(han,'F(x)','FontSize',fontSize);
%% -------- legend：手动指定顺序 --------
legend([hEST_corr, ...
        hSIC_corr, hSICi_corr, ...
        hMOM_corr, hMOMi_corr, ...
        hGEO_corr, hGEOi_corr, ...
        hMM_corr,  hMMi_corr], ...
       {'Q_{est(med)}', ...
        'Q_{SIC4DVar}','Q_{SIC4DVar}^{interp}', ...
        'Q_{MOMMA}','Q_{MOMMA}^{interp}', ...
        'Q_{geoBAM}','Q_{geoBAM}^{interp}', ...
        'Q_{MetroMan}','Q_{MetroMan}^{interp}'}, ...
        'FontSize',fontSize, ...
        'FontWeight',fontWeight, ...
        'Location','southeast');
end

%% =====================================================================
%% 安全取 cell：缺字段/越界/报错就返回 []
function v = safe_cell(S, field, i, j)
    v = [];
    if ~isfield(S, field) || isempty(S.(field))
        return
    end
    try
        v = S.(field){i,j};
    catch
        v = [];
    end
end

%% 把 v.(name) 变成列向量；如果 v 为空或无字段就返回 []
function x = col(v, name)
    x = [];
    if isempty(v) || ~isstruct(v) || ~isfield(v, name) || isempty(v.(name))
        return
    end
    x = v.(name);
    x = x(:);
end

%% 辅助函数：ecdf（实线/虚线）
function h = plot_ecdf_style(data, style, lineW, color)
    data = data(~isnan(data));
    if isempty(data)
        h = gobjects(1);
        return;
    end
    [f,x] = ecdf(data);
    h = plot(x,f, style, 'LineWidth', lineW, 'Color', color);
end