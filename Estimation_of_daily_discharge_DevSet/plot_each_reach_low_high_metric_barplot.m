function plot_each_reach_low_high_metric_barplot(group_vali_out, ib, ip)
% plot_each_reach_low_high_metric_barplot
%
% 对 validation_flow_group_all 输出的 group_vali_out，
% 自动画有有效数值的 reach。
%
% 每个有效 reach 画一张 4x2 图：
%
%   row 1: low corr      high corr
%   row 2: low NSE       high NSE
%   row 3: low rRMSE     high rRMSE
%   row 4: low rBias     high rBias
%
% INPUT:
%   group_vali_out : validation_flow_group_all 的第一个输出
%   ib             : basin index
%   ip             : path index
%
% Example:
%   plot_each_reach_low_high_metric_barplot(group_vali_out, 1, 1)

fontSize = 15;

% =========================================================
% 颜色设置
% =========================================================
cKF   = [0.0000 0.4470 0.7410];
cSIC  = [0.6350 0.0780 0.1840];
cMOM  = [0.4660 0.6740 0.1880];
cGEO  = [0.4940 0.1840 0.5560];
cSADS = [0.3010 0.7450 0.9330];
cMM   = [0.9290 0.6940 0.1250];

cSICi  = lighten_color(cSIC,  0.7);
cMOMi  = lighten_color(cMOM,  0.7);
cGEOi  = lighten_color(cGEO,  0.7);
cSADSi = lighten_color(cSADS, 0.7);
cMMi   = lighten_color(cMM,   0.7);

products = { ...
    'Qest_med', ...
    'SIC4DVar', 'SIC4DVar_interp', ...
    'MOMMA', 'MOMMA_interp', ...
    'geoBAM', 'geoBAM_interp', ...
    'SADS', 'SADS_interp', ...
    'MetroMan', 'MetroMan_interp'};

labels = { ...
    'Q_{est(med)}', ...
    'Q_{SIC4DVar}', 'Q_{SIC4DVar}^{interp}', ...
    'Q_{MOMMA}', 'Q_{MOMMA}^{interp}', ...
    'Q_{neoBAM}', 'Q_{neoBAM}^{interp}', ...
    'Q_{SADS}', 'Q_{SADS}^{interp}', ...
    'Q_{MetroMan}', 'Q_{MetroMan}^{interp}'};

colors = { ...
    cKF, ...
    cSIC, cSICi, ...
    cMOM, cMOMi, ...
    cGEO, cGEOi, ...
    cSADS, cSADSi, ...
    cMM, cMMi};

metrics = {'corr','NSE','rRMSE','rB'};
metric_titles = {'Correlation','NSE','rRMSE','rBias'};
ylabs = {'[-]','[-]','[%]','[%]'};

groups = {'low','high'};

% =========================================================
% 读取指定 basin/path
% =========================================================
if numel(group_vali_out) < ib || ...
        ~isfield(group_vali_out(ib), 'paths') || ...
        numel(group_vali_out(ib).paths) < ip
    error('Cannot find group_vali_out(%d).paths(%d).', ib, ip);
end

path_vali = group_vali_out(ib).paths(ip);

% =========================================================
% 判断 reach 数量
% =========================================================
nR = get_n_reach_from_path_vali(path_vali, products, groups, metrics);

if isempty(nR) || nR == 0
    error('No valid reach data found for basin %d path %d.', ib, ip);
end

% =========================================================
% 自动找有有效数值的 reach
% =========================================================
valid_reach = false(nR, 1);

for j = 1:nR

    Y_tmp = collect_one_reach_Y(path_vali, j, products, groups, metrics);

    if has_valid_Y(Y_tmp.low) || has_valid_Y(Y_tmp.high)
        valid_reach(j) = true;
    end
end

valid_reach_idx = find(valid_reach);

if isempty(valid_reach_idx)
    warning('Basin %d Path %d has no reach with valid low/high data.', ib, ip);
    return
end

fprintf('Basin %d Path %d: plotting %d valid reaches out of %d reaches.\n', ...
    ib, ip, numel(valid_reach_idx), nR);

% =========================================================
% 逐有效 reach 画图
% =========================================================
for ir = 1:numel(valid_reach_idx)

    j = valid_reach_idx(ir);

    Y_all = collect_one_reach_Y(path_vali, j, products, groups, metrics);

    % 这个 reach 中，low 或 high 有数据的产品才保留
    keep = any(~isnan(Y_all.low), 1) | any(~isnan(Y_all.high), 1);

    if ~any(keep)
        continue
    end

    labels_use = labels(keep);
    colors_use = colors(keep);

    fig = figure('Color','w');

    tl = tiledlayout(fig, 4, 2, ...
        'TileSpacing','compact', ...
        'Padding','compact');

    sgtitle(sprintf('Basin %d Path %d Reach %d: Low-flow and High-flow validation', ...
        ib, ip, j), ...
        'FontSize', fontSize+2, ...
        'FontWeight', 'normal');

    low_tiles  = [1 3 5 7];
    high_tiles = [2 4 6 8];

    for ig = 1:numel(groups)

        g = groups{ig};

        if strcmp(g, 'low')
            tiles = low_tiles;
            group_title = 'Low flow';
        else
            tiles = high_tiles;
            group_title = 'High flow';
        end

        Y_use = Y_all.(g)(:, keep);

        for im = 1:numel(metrics)

            ax = nexttile(tiles(im));

            b = bar(Y_use(im,:));
            hold on
            grid on
            yline(0, 'k-', 'LineWidth', 0.8);

            b.FaceColor = 'flat';
            b.CData = cell2mat(colors_use');
            b.EdgeColor = 'none';

            title(ax, sprintf('%s: %s', group_title, metric_titles{im}), ...
                'FontSize', fontSize, ...
                'FontWeight', 'normal');

            ylabel(ax, ylabs{im}, ...
                'FontSize', fontSize-1, ...
                'FontWeight', 'normal');

            set(ax, ...
                'FontSize', fontSize-1, ...
                'FontWeight', 'normal', ...
                'XTick', 1:numel(labels_use), ...
                'XTickLabel', []);

            ylim(ax, get_ylim_metric(Y_use(im,:), metrics{im}));
            % 
            % yl = ylim(ax);
            % offset = 0.025 * range(yl);
            % 
            % for k = 1:numel(labels_use)
            % 
            %     val = Y_use(im,k);
            % 
            %     if isnan(val)
            %         continue
            %     end
            % 
            %     switch lower(metrics{im})
            %         case {'corr','nse'}
            %             str = sprintf('%.2f', val);
            %         case {'rrmse','rb'}
            %             str = sprintf('%.0f', val);
            %         otherwise
            %             str = sprintf('%.2f', val);
            %     end
            % 
            %     if val >= 0
            %         y_text = val + offset;
            %         va = 'bottom';
            %     else
            %         y_text = val - offset;
            %         va = 'top';
            %     end
            % 
            %     text(k, y_text, str, ...
            %         'HorizontalAlignment','center', ...
            %         'VerticalAlignment', va, ...
            %         'FontSize', fontSize-5, ...
            %         'FontWeight','normal');
            % end
        end
    end

    % =====================================================
    % legend 放到整个 tiledlayout 顶部
    % =====================================================
    ax_legend = nexttile(1);
    hold(ax_legend, 'on');

    hLegend = gobjects(numel(labels_use), 1);

    for k = 1:numel(labels_use)
        hLegend(k) = plot(ax_legend, nan, nan, ...
            'LineWidth', 10, ...
            'Color', colors_use{k});
    end

    lgd = legend(ax_legend, hLegend, labels_use, ...
        'Orientation','horizontal', ...
        'Box','on', ...
        'FontSize', fontSize-3);

    lgd.Layout.Tile = 'north';

end

end

%% =========================================================
function Y_all = collect_one_reach_Y(path_vali, j, products, groups, metrics)

Y_all = struct();

for ig = 1:numel(groups)

    g = groups{ig};
    Y = nan(numel(metrics), numel(products));

    for iprod = 1:numel(products)

        p = products{iprod};

        if ~isfield(path_vali, p)
            continue
        end

        if ~isfield(path_vali.(p), g)
            continue
        end

        for im = 1:numel(metrics)

            m = metrics{im};

            if ~isfield(path_vali.(p).(g), m)
                continue
            end

            tmp = path_vali.(p).(g).(m);

            if isempty(tmp) || size(tmp,1) < j
                continue
            end

            vals = tmp(j,:);
            vals = vals(:);
            vals = vals(~isnan(vals) & ~isinf(vals));

            if ~isempty(vals)
                Y(im, iprod) = median(vals, 'omitnan');
            end
        end
    end

    Y_all.(g) = Y;
end

end

%% =========================================================
function tf = has_valid_Y(Y)

tf = any(~isnan(Y(:)) & ~isinf(Y(:)));

end

%% =========================================================
function nR = get_n_reach_from_path_vali(path_vali, products, groups, metrics)

nR = [];

for iprod = 1:numel(products)

    p = products{iprod};

    if ~isfield(path_vali, p)
        continue
    end

    for ig = 1:numel(groups)

        g = groups{ig};

        if ~isfield(path_vali.(p), g)
            continue
        end

        for im = 1:numel(metrics)

            m = metrics{im};

            if isfield(path_vali.(p).(g), m) && ...
                    ~isempty(path_vali.(p).(g).(m))

                nR = size(path_vali.(p).(g).(m), 1);
                return
            end
        end
    end
end

end

%% =========================================================
function c2 = lighten_color(c1, a)

c2 = c1 + (1 - c1) * a;

end

%% =========================================================
function yl = get_ylim_metric(Y, metric_name)

vals = Y(:);
vals = vals(~isnan(vals) & ~isinf(vals));

if isempty(vals)
    switch lower(metric_name)
        case 'corr'
            yl = [-0.2 0.8];
        case 'nse'
            yl = [-1.2 0.8];
        otherwise
            yl = [0 100];
    end
    return
end

switch lower(metric_name)

    case 'corr'
        lo = min(vals);
        hi = max(vals);

        lo = min(lo, 0);
        hi = max(hi, 0.5);

        pad = 0.08 * max(hi - lo, 0.5);
        yl = [lo - pad, hi + pad];

    case 'nse'
        lo = min(vals);
        hi = max(vals);

        hi = max(hi, 0.2);

        pad = 0.12 * max(hi - lo, 0.5);
        yl = [lo - pad, hi + pad];

    case 'rrmse'
        hi = max(vals);
        hi = max(hi, 50);

        yl = [0, hi * 1.18 + eps];

    case 'rb'
        lo = min(vals);
        hi = max(vals);

        if lo >= 0
            yl = [0, hi * 1.18 + eps];
        else
            pad = 0.12 * max(hi - lo, 50);
            yl = [lo - pad, hi + pad];
        end

    otherwise
        lo = min(vals);
        hi = max(vals);

        if lo == hi
            lo = lo - 1;
            hi = hi + 1;
        end

        yl = [lo hi];
end

end