function plot_group_vali_out_boxchart(group_vali_out)
% plot_group_vali_out_boxchart
% =========================================================
% 根据 group_vali_out 画 low-flow 和 high-flow 的 validation boxchart
% 加入 interp 产品的 metric result
% 不包含 SADS
%
% 输出：
%   Figure 1: low-flow  2x2 boxchart
%   Figure 2: high-flow 2x2 boxchart
%
% 结构假设：
%   group_vali_out(ib).paths(ipath).Qest_med.low.corr
%   group_vali_out(ib).paths(ipath).SIC4DVar.low.corr
%   group_vali_out(ib).paths(ipath).SIC4DVar_interp.low.corr
%   ...
%
% 如果某个 interp field 不存在，会自动跳过，不报错。

% =========================================================
% 1) 产品和指标设置
% =========================================================

% Qest 单独放第一个；后面每个产品有 original 和 interp 两个 box
prod_fields = { ...
    'Qest_med', ...
    'SIC4DVar', 'SIC4DVar_interp', ...
    'MOMMA',    'MOMMA_interp', ...
    'geoBAM',   'geoBAM_interp', ...
    'MetroMan', 'MetroMan_interp'};

% x 轴显示位置：
% Estimate 在 1；
% 后面每两个 box 一组，所以产品名放在两个 box 的中间。
xtick_pos = [1, 2.5, 4.5, 6.5, 8.5];

% x 轴产品名，真正写在 x 轴下面
xtick_lab = {'Estimate', 'SIC4DVar', 'MOMMA', 'neoBAM', 'MetroMan'};

metric_fields = {'corr', 'NSE', 'rRMSE', 'rB'};

metric_titles = { ...
    '(a) Correlation', ...
    '(b) NSE', ...
    '(c) rRMSE', ...
    '(d) rBias'};

metric_ylabs = {'[-]', '[-]', '[%]', '[%]'};

% =========================================================
% 2) 画 low 和 high 两张图
% =========================================================

plot_one_flow_group(group_vali_out, 'low', prod_fields, xtick_pos, ...
    xtick_lab, metric_fields, metric_titles, metric_ylabs);

plot_one_flow_group(group_vali_out, 'high', prod_fields, xtick_pos, ...
    xtick_lab, metric_fields, metric_titles, metric_ylabs);

end

%% =========================================================
% 画一个 flow group: low 或 high
% =========================================================
function plot_one_flow_group(group_vali_out, flow_name, prod_fields, xtick_pos, ...
    xtick_lab, metric_fields, metric_titles, metric_ylabs)

fontSize = 15;

% ---------------------------------------------------------
% 收集数据
% DATA.(metric).(product) = 所有 basin/path/reach 的非 NaN 值
% ---------------------------------------------------------
DATA = struct();

for im = 1:numel(metric_fields)
    m = metric_fields{im};

    for iprod = 1:numel(prod_fields)
        pfield = prod_fields{iprod};
        DATA.(m).(pfield) = [];
    end
end

% =========================================================
% loop over basin
% =========================================================
for ib = 1:numel(group_vali_out)

    if ~isfield(group_vali_out(ib), 'paths') || isempty(group_vali_out(ib).paths)
        continue
    end

    paths = group_vali_out(ib).paths;

    if iscell(paths)
        nPath = numel(paths);
    elseif isstruct(paths)
        nPath = numel(paths);
    else
        continue
    end

    % =====================================================
    % loop over path
    % =====================================================
    for ipath = 1:nPath

        if iscell(paths)
            P = paths{ipath};
        else
            P = paths(ipath);
        end

        if isempty(P) || ~isstruct(P)
            continue
        end

        % =================================================
        % loop over products
        % =================================================
        for iprod = 1:numel(prod_fields)

            pfield = prod_fields{iprod};

            if ~isfield(P, pfield) || isempty(P.(pfield))
                continue
            end

            Sprod = P.(pfield);

            if ~isstruct(Sprod) || ~isfield(Sprod, flow_name) || isempty(Sprod.(flow_name))
                continue
            end

            Sflow = Sprod.(flow_name);

            % =============================================
            % loop over metrics
            % =============================================
            for im = 1:numel(metric_fields)

                m = metric_fields{im};

                if ~isstruct(Sflow) || ~isfield(Sflow, m) || isempty(Sflow.(m))
                    continue
                end

                v = Sflow.(m);
                v = v(:);
                v = v(~isnan(v));

                DATA.(m).(pfield) = [DATA.(m).(pfield); v];

            end
        end
    end
end

% =========================================================
% 3) 颜色设置
% =========================================================

clr.Qest_med = [0.0000 0.4470 0.7410];

% 原始产品深色
clr.SIC4DVar = [0.6350 0.0780 0.1840];
clr.MOMMA    = [0.4660 0.6740 0.1880];
clr.geoBAM   = [0.4940 0.1840 0.5560];
clr.MetroMan = [0.9290 0.6940 0.1250];

% interp 产品浅色
clr.SIC4DVar_interp = [0.82 0.54 0.59];
clr.MOMMA_interp    = [0.73 0.84 0.59];
clr.geoBAM_interp   = [0.74 0.59 0.79];
clr.MetroMan_interp = [0.96 0.80 0.45];

% =========================================================
% 4) 作图
% =========================================================

figure('Color', 'w', 'Position', [100 100 1280 820]);

tl = tiledlayout(2, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'loose');

title(tl, sprintf('%s flow', upper_first(flow_name)), ...
    'FontSize', fontSize + 5, ...
    'FontWeight', 'bold');

ax_list = gobjects(numel(metric_fields), 1);

for im = 1:numel(metric_fields)

    ax = nexttile(tl);
    ax_list(im) = ax;

    hold(ax, 'on');
    box(ax, 'on');

    m = metric_fields{im};

    all_data = cell(1, numel(prod_fields));

    % -----------------------------------------------------
    % 收集每个 product 的数据，并做适度裁剪
    % -----------------------------------------------------
    for iprod = 1:numel(prod_fields)

        pfield = prod_fields{iprod};

        y = DATA.(m).(pfield);
        y = y(:);
        y = y(~isnan(y));

        switch m
            case 'corr'
                % correlation 主体范围
                y = clip_percentile(y, 2, 98);

            case 'NSE'
                % NSE 极端负值可能会把图压扁
                y = clip_percentile(y, 2, 98);

            case {'rRMSE', 'rB'}
                % 百分比指标裁剪极端 outlier，方便看主体分布
                y = clip_percentile(y, 2, 98);
        end

        all_data{iprod} = y;
    end

    % -----------------------------------------------------
    % 画 boxchart
    % -----------------------------------------------------
    for iprod = 1:numel(prod_fields)

        pfield = prod_fields{iprod};
        y = all_data{iprod};

        if isempty(y)
            continue
        end

        x = iprod * ones(size(y));

        h = boxchart(ax, x, y, ...
            'BoxWidth', 0.55, ...
            'MarkerStyle', 'none', ...
            'BoxFaceAlpha', 0.35, ...
            'LineWidth', 1.5);

        h.BoxFaceColor = clr.(pfield);
        h.BoxEdgeColor = clr.(pfield);

        try
            h.WhiskerLineColor = clr.(pfield);
        catch
        end
    end

    % -----------------------------------------------------
    % y = 0 reference line
    % -----------------------------------------------------
    yline(ax, 0, '-', ...
        'Color', [0.3 0.3 0.3], ...
        'LineWidth', 0.6);

    % -----------------------------------------------------
    % 根据 whisker 范围设置 ylim
    % -----------------------------------------------------
    mins = [];
    maxs = [];

    for k = 1:numel(all_data)

        v = all_data{k};

        if isempty(v)
            continue
        end

        [mn, mx] = get_box_whisker_range(v);

        if ~isnan(mn)
            mins(end+1) = mn; %#ok<AGROW>
        end

        if ~isnan(mx)
            maxs(end+1) = mx; %#ok<AGROW>
        end
    end

    if ~isempty(mins) && ~isempty(maxs)

        ymin = min(mins);
        ymax = max(maxs);

        if ymin == ymax
            pad = max(0.1, 0.1 * abs(ymax));
        else
            pad = 0.08 * (ymax - ymin);
        end

        ylow  = min(ymin - pad, 0);
        yhigh = max(ymax + pad, 0);

        ylim(ax, [ylow, yhigh]);
    end

    % -----------------------------------------------------
    % 坐标轴设置
    % 产品名用真正的 x 轴 tick label，写在 x 轴下面
    % -----------------------------------------------------
    set(ax, ...
        'XTick', xtick_pos, ...
        'XTickLabel', xtick_lab, ...
        'XTickLabelRotation', 0, ...
        'FontSize', fontSize, ...
        'FontWeight', 'normal');

    ax.TickLabelInterpreter = 'none';

    ylabel(ax, metric_ylabs{im}, 'FontSize', fontSize);

    title(ax, metric_titles{im}, ...
        'FontSize', fontSize, ...
        'FontWeight', 'normal');

    grid(ax, 'on');
    grid(ax, 'minor');

    xlim(ax, [0.4, numel(prod_fields) + 0.6]);

    % -----------------------------------------------------
    % 分隔线
    % Qest 单独一个，后面每两个是一组
    % -----------------------------------------------------
    for xsep = [1.5 3.5 5.5 7.5]
        xline(ax, xsep, '--', ...
            'Color', [0.3 0.3 0.3], ...
            'LineWidth', 1.0);
    end

end

% =========================================================
% 5) 图例
% =========================================================
% 不再新开 tile，避免覆盖第 4 个 subplot。
% 用最后一个 subplot 放全局 legend，并放到底部。

ax_leg = ax_list(end);
hold(ax_leg, 'on');

lg0 = plot(ax_leg, nan, nan, 's', ...
    'MarkerSize', 14, ...
    'MarkerFaceColor', clr.Qest_med, ...
    'MarkerEdgeColor', clr.Qest_med, ...
    'LineStyle', 'none');

lg1 = plot(ax_leg, nan, nan, 's', ...
    'MarkerSize', 14, ...
    'MarkerFaceColor', [0.4 0.4 0.4], ...
    'MarkerEdgeColor', [0.4 0.4 0.4], ...
    'LineStyle', 'none');

lg2 = plot(ax_leg, nan, nan, 's', ...
    'MarkerSize', 14, ...
    'MarkerFaceColor', [0.8 0.8 0.8], ...
    'MarkerEdgeColor', [0.8 0.8 0.8], ...
    'LineStyle', 'none');

lgd = legend(ax_leg, [lg0 lg1 lg2], ...
    {'Q_{est(med)}', 'Q_{SWOT}', 'Q_{interp}'}, ...
    'Orientation', 'horizontal', ...
    'Box', 'on');

try
    lgd.Layout.Tile = 'south';
catch
    legend(ax_leg, [lg0 lg1 lg2], ...
        {'Q_{est(med)}', 'Q_{SWOT}', 'Q_{interp}'}, ...
        'Orientation', 'horizontal', ...
        'Location', 'southoutside', ...
        'Box', 'on');
end

end

%% =========================================================
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

%% =========================================================
% 裁剪分位数
% =========================================================
function x = clip_percentile(x, p1, p2)

x = x(~isnan(x));

if isempty(x)
    return
end

lo = prctile(x, p1);
hi = prctile(x, p2);

x(x < lo) = lo;
x(x > hi) = hi;

end

%% =========================================================
% 首字母大写
% =========================================================
function s2 = upper_first(s)

if isempty(s)
    s2 = s;
else
    s2 = [upper(s(1)), s(2:end)];
end

end