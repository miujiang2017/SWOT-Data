function plot_metric_improvement_boxchart(Q_results)
% plot_metric_improvement_boxchart
% =========================================================
% 画 Q_est(med) 相对各产品的 improvement 箱线图
%
% 八个 box：
%   SIC4DVar, SIC4DVar_interp,
%   MOMMA,    MOMMA_interp,
%   geoBAM,   geoBAM_interp,
%   MetroMan, MetroMan_interp
%
% 约定：
%   - 同一种产品同一个颜色
%   - 原始产品：深色
%   - interp产品：浅色
%
% 四个指标统一定义为“越大越好”：
%   Imp_corr   = corr_est - corr_prod
%   Imp_NSE    = NSE_est  - NSE_prod
%   Imp_rRMSE  = rRMSE_prod - rRMSE_est
%   Imp_absrB  = abs(rB_prod) - abs(rB_est)

% ---------------------------------------------------------
% 1) 产品定义
% ---------------------------------------------------------
prod_fields = { ...
    'vali_SIC4DVar',        'vali_SIC4DVar_interp', ...
    'vali_MOMMA',           'vali_MOMMA_interp', ...
    'vali_geoBAM',          'vali_geoBAM_interp', ...
    'vali_MetroMan',        'vali_MetroMan_interp'};

prod_labels = repmat({''}, 1, 8);   % 不显示每个 box 的 xtick label
base_names  = {'SIC4DVar','MOMMA','neoBAM','MetroMan'};

% ---------------------------------------------------------
% 2) 初始化 improvement 容器
% ---------------------------------------------------------
IMP.corr   = init_imp_struct(prod_fields);
IMP.NSE    = init_imp_struct(prod_fields);
IMP.rRMSE  = init_imp_struct(prod_fields);
IMP.absrB  = init_imp_struct(prod_fields);

% ---------------------------------------------------------
% 3) 收集 improvement
% ---------------------------------------------------------
for ib = 1:numel(Q_results)

    if ~isfield(Q_results(ib), 'vali_estmed') || isempty(Q_results(ib).vali_estmed)
        continue
    end

    nPath = numel(Q_results(ib).vali_estmed);

    for p = 1:nPath

        S_est = getS(Q_results(ib), 'vali_estmed', p);
        if isempty(S_est)
            continue
        end

        est_corr  = getv(S_est, 'corr');
        est_NSE   = getv(S_est, 'NSE');
        est_rRMSE = getv(S_est, 'rRMSE');
        est_rB    = getv(S_est, 'rB');

        for i = 1:numel(prod_fields)
            f = prod_fields{i};

            S_prod = getS(Q_results(ib), f, p);
            if isempty(S_prod)
                continue
            end

            prod_corr  = getv(S_prod, 'corr');
            prod_NSE   = getv(S_prod, 'NSE');
            prod_rRMSE = getv(S_prod, 'rRMSE');
            prod_rB    = getv(S_prod, 'rB');

            % corr / NSE：est - prod
            IMP.corr.(f) = [IMP.corr.(f); compute_imp(est_corr,  prod_corr,  'direct')];
            IMP.NSE.(f)  = [IMP.NSE.(f);  compute_imp(est_NSE,   prod_NSE,   'direct')];

            % rRMSE：prod - est（越大越好）
            IMP.rRMSE.(f) = [IMP.rRMSE.(f); compute_imp(est_rRMSE, prod_rRMSE, 'direct')];

            % abs(rB)：abs(prod) - abs(est)（越大越好）
            IMP.absrB.(f) = [IMP.absrB.(f); compute_imp(est_rB,    prod_rB,    'direct')];
        end
    end
end

% ---------------------------------------------------------
% 4) 颜色：同一种产品同色
% ---------------------------------------------------------
% clr.SIC4DVar = [0.0000 0.4470 0.7410];
% clr.MOMMA    = [0.8500 0.3250 0.0980];
% clr.geoBAM   = [0.4660 0.6740 0.1880];
% clr.MetroMan = [0.4940 0.1840 0.5560];

clr.SIC4DVar = [0.6350 0.0780 0.1840]; % 红色
clr.MOMMA = [0.4660 0.6740 0.1880]; % 绿色
clr.geoBAM = [0.4940 0.1840 0.5560]; % 紫色
clr.MetroMan  = [0.9290 0.6940 0.1250]; % 黄色
% ---------------------------------------------------------
% 5) 作图（tiledlayout + nexttile）
% ---------------------------------------------------------
figure('Color', 'w', 'Position', [100 100 1280 760]);

tiledlayout(2, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');
fontSize   = 16;
fontWeight = 'normal';
ax1 = nexttile;
plot_one_panel(ax1, IMP.corr, 'corr', prod_fields, prod_labels, base_names, clr, ...
    '(a). Correlation difference', '[-]');
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
ax2 = nexttile;
plot_one_panel(ax2, IMP.NSE, 'NSE', prod_fields, prod_labels, base_names, clr, ...
    '(b). NSE difference', '[-]');
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
ax3 = nexttile;
plot_one_panel(ax3, IMP.rRMSE, 'rRMSE', prod_fields, prod_labels, base_names, clr, ...
    '(c). rRMSE difference', '[%]');
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
ax4 = nexttile;
plot_one_panel(ax4, IMP.absrB, 'absrB', prod_fields, prod_labels, base_names, clr, ...
    '(d). rBias difference', '[%]');
set(gca,'FontSize',fontSize,'FontWeight',fontWeight);
% ---------------------------------------------------------
% 6) 图例
% ---------------------------------------------------------
lg1 = plot(ax4, nan, nan, 's', ...
    'MarkerSize', 16, ...
    'MarkerFaceColor', [0.4 0.4 0.4], ...
    'MarkerEdgeColor', [0.4 0.4 0.4], ...
    'LineStyle', 'none');

lg2 = plot(ax4, nan, nan, 's', ...
    'MarkerSize', 16, ...
    'MarkerFaceColor', [0.8 0.8 0.8], ...
    'MarkerEdgeColor', [0.8 0.8 0.8], ...
    'LineStyle', 'none');

legend(ax4, [lg1 lg2], {'Q_{SWOT}', 'Q_{interp}'}, ...
    'Orientation', 'vertical', ...
    'Location', 'southoutside', ...
    'Box', 'on');

end

% =========================================================
% 初始化结构体
% =========================================================
function S = init_imp_struct(fields)

S = struct();
for i = 1:numel(fields)
    S.(fields{i}) = [];
end

end

% =========================================================
% 单个 panel
% =========================================================
function plot_one_panel(ax, IMP_oneMetric, metric_name, prod_fields, prod_labels, base_names, clr, ttl, ylab)

axes(ax);
hold(ax, 'on');
box(ax, 'on');

all_data = cell(1, numel(prod_fields));

% 浅色（interp）
clr.SIC4DVar_int =  [0.82 0.54 0.59];
clr.MOMMA_int    = [0.73 0.84 0.59];
clr.geoBAM_int   = [0.74 0.59 0.79];
clr.MetroMan_int = [0.96 0.8 0.45];

% ---------------------------------------------------------
% 1) 收集并裁剪数据
% ---------------------------------------------------------
for i = 1:numel(prod_fields)
    x = IMP_oneMetric.(prod_fields{i});
    x = x(~isnan(x));

    switch metric_name
        case 'corr'
            x = clip_percentile(x, 0, 100);

        case 'NSE'
            if contains(prod_fields{i}, '_interp')
                x = clip_percentile(x, 2, 85);
            else
                x = clip_percentile(x, 2, 98);
            end

        case 'rRMSE'
            x = clip_percentile(x, 2, 98);

        case 'absrB'
            x = clip_percentile(x, 2, 98);

        otherwise
            error('Unknown metric_name: %s', metric_name);
    end

    all_data{i} = x;
end

% ---------------------------------------------------------
% 2) 画 8 个 boxchart
% ---------------------------------------------------------
for i = 1:numel(prod_fields)

    y = all_data{i};
    if isempty(y)
        continue
    end

    xpos = i * ones(size(y));

    if strcmp(prod_fields{i}, 'vali_SIC4DVar')
        c = clr.SIC4DVar;      fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_SIC4DVar_interp')
        c = clr.SIC4DVar_int;  fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_MOMMA')
        c = clr.MOMMA;         fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_MOMMA_interp')
        c = clr.MOMMA_int;     fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_geoBAM')
        c = clr.geoBAM;        fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_geoBAM_interp')
        c = clr.geoBAM_int;    fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_MetroMan')
        c = clr.MetroMan;      fa = 0.35;
    elseif strcmp(prod_fields{i}, 'vali_MetroMan_interp')
        c = clr.MetroMan_int;  fa = 0.35;
    else
        c = [0.5 0.5 0.5];     fa = 0.35;
    end

    h = boxchart(ax, xpos, y, ...
        'BoxWidth', 0.55, ...
        'MarkerStyle', 'none', ...
        'BoxFaceAlpha', fa, ...
        'LineWidth', 1.6);

    h.BoxFaceColor = c;
    h.BoxEdgeColor = c;

    try
        h.WhiskerLineColor = c;
    catch
    end
end

% ---------------------------------------------------------
% 3) 零线
% ---------------------------------------------------------
yline(ax, 0, '-', 'LineWidth', 0.4);

% ---------------------------------------------------------
% 4) 综合 8 个 box 的 whisker 范围设 ylim
% ---------------------------------------------------------
mins = [];
maxs = [];

for i = 1:numel(all_data)
    v = all_data{i};
    if isempty(v)
        continue
    end

    [mn, mx] = get_box_whisker_range(v);
    if ~isnan(mn), mins(end+1) = mn; end %#ok<AGROW>
    if ~isnan(mx), maxs(end+1) = mx; end %#ok<AGROW>
end

if ~isempty(mins) && ~isempty(maxs)
    ymin = min(mins);
    ymax = max(maxs);

    if ymax == ymin
        pad = max(1, 0.1 * abs(ymax));
    else
        pad = 0.08 * (ymax - ymin);
    end

    ylow  = min(ymin - pad, 0);
    yhigh = max(ymax + pad, 0);
    ylim(ax, [ylow yhigh]);
end

% ---------------------------------------------------------
% 5) 给底部产品名留空间
% ---------------------------------------------------------
yl = ylim(ax);
yr = yl(2) - yl(1);
ylim(ax, [yl(1) - 0.08 * yr, yl(2)]);

% ---------------------------------------------------------
% 6) 坐标轴格式
% ---------------------------------------------------------
set(ax, ...
    'XTick', 1:numel(prod_fields), ...
    'XTickLabel', prod_labels, ...
    'XTickLabelRotation', 0, ...
    'FontSize', 14, ...
    'FontWeight', 'normal');

ylabel(ax, ylab);
title(ax, ttl, 'FontSize', 13, 'FontWeight', 'normal');

grid(ax, 'on');
grid(ax, 'minor');

% ---------------------------------------------------------
% 7) 分隔线
% ---------------------------------------------------------
for xsep = [2.5 4.5 6.5]
    xline(ax, xsep, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
end

% ---------------------------------------------------------
% 8) 产品名移到 x 轴下面
% ---------------------------------------------------------
yl = ylim(ax);
y_text = yl(1) + 0.04 * (yl(2) - yl(1));

for k = 1:numel(base_names)
    xc = 2 * k - 0.5;
    text(ax, xc, y_text, base_names{k}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'FontSize', 14, ...
        'FontWeight', 'normal');
end

xlim(ax, [0.4 numel(prod_fields) + 0.6]);

end

% =========================================================
% 取指定 path 的 struct
% =========================================================
function S = getS(A, field, p)

S = [];
if ~isfield(A, field), return; end

C = A.(field);
if isempty(C), return; end
if numel(C) < p, return; end
if isempty(C{1,p}), return; end

S = C{1,p};

end

% =========================================================
% 取向量
% =========================================================
function v = getv(S, f)

if ~isstruct(S) || ~isfield(S, f) || isempty(S.(f))
    v = [];
else
    v = S.(f)(:);
end

end

% =========================================================
% 箱线图 whisker 范围
% =========================================================
function [minw, maxw] = get_box_whisker_range(v)

v = v(~isnan(v));

if isempty(v)
    minw = NaN;
    maxw = NaN;
    return
end

Q1 = prctile(v, 25);
Q3 = prctile(v, 75);
IQR = Q3 - Q1;

lower_limit = Q1 - 1.5 * IQR;
upper_limit = Q3 + 1.5 * IQR;

v_mid = v(v >= lower_limit & v <= upper_limit);

if isempty(v_mid)
    minw = min(v);
    maxw = max(v);
else
    minw = min(v_mid);
    maxw = max(v_mid);
end

end

% =========================================================
% improvement
% mode:
%   'direct'      : est - prod
%   'reverse'     : prod - est
%   'abs_reverse' : abs(prod) - abs(est)
% =========================================================
function imp = compute_imp(v_est, v_prod, mode)

if nargin < 3
    mode = 'direct';
end

if isempty(v_est) || isempty(v_prod)
    imp = [];
    return
end

n = min(numel(v_est), numel(v_prod));
if n == 0
    imp = [];
    return
end

v_est  = v_est(1:n);
v_prod = v_prod(1:n);

mask = ~isnan(v_est) & ~isnan(v_prod);

v_est  = v_est(mask);
v_prod = v_prod(mask);

switch mode
    case 'direct'
        imp = v_est - v_prod;

    case 'reverse'
        imp = v_prod - v_est;

    case 'abs_reverse'
        imp = abs(v_prod) - abs(v_est);

    otherwise
        error('Unknown mode: %s', mode);
end

end

% =========================================================
% 裁剪分位数
% =========================================================
function x = clip_percentile(x, p1, p2)

x = x(~isnan(x));
if isempty(x), return; end

lo = prctile(x, p1);
hi = prctile(x, p2);

x(x < lo) = lo;
x(x > hi) = hi;

end