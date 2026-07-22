function med_table = plot_reach_metric_median_barplot(Q_results)

fontSize = 15;

% ---- 深色 ----
cKF   = [0.0000 0.4470 0.7410];
cSIC  = [0.6350 0.0780 0.1840];
cMOM  = [0.4660 0.6740 0.1880];
cGEO  = [0.4940 0.1840 0.5560];
cMM   = [0.9290 0.6940 0.1250];

% ---- 浅色：interp ----
cSICi = lighten_color(cSIC,0.7);
cMOMi = lighten_color(cMOM,0.7);
cGEOi = lighten_color(cGEO,0.7);
cMMi  = lighten_color(cMM ,0.7);

% =========================================================
% 1. 收集所有 reach
% =========================================================
methods = { ...
    'est',   'vali_estmed'; ...
    'SIC',   'vali_SIC4DVar'; ...
    'SICi',  'vali_SIC4DVar_interp'; ...
    'MOM',   'vali_MOMMA'; ...
    'MOMi',  'vali_MOMMA_interp'; ...
    'geo',   'vali_geoBAM'; ...
    'geoi',  'vali_geoBAM_interp'; ...
    'MM',    'vali_MetroMan'; ...
    'MMi',   'vali_MetroMan_interp'};

metrics = {'corr','NSE','rRMSE','rB'};

all = struct();

for im = 1:size(methods,1)
    for k = 1:numel(metrics)
        all.(methods{im,1}).(metrics{k}) = [];
    end
end

for ib = 1:numel(Q_results)

    if ~isfield(Q_results(ib),'vali_estmed') || isempty(Q_results(ib).vali_estmed)
        continue
    end

    nPath = size(Q_results(ib).vali_estmed,2);

    for p = 1:nPath

        % 仍然以 KF 是否存在作为纳入口径
        S_est = safe_cell(Q_results(ib),'vali_estmed',1,p);
        if isempty(S_est)
            continue
        end

        for im = 1:size(methods,1)

            shortname = methods{im,1};
            fieldname = methods{im,2};

            S = safe_cell(Q_results(ib),fieldname,1,p);

            for k = 1:numel(metrics)
                name = metrics{k};
                all.(shortname).(name) = [all.(shortname).(name); col(S,name)];
            end
        end
    end
end

% =========================================================
% 2. 计算 median
% =========================================================
Y = nan(numel(metrics), size(methods,1));
N = zeros(numel(metrics), size(methods,1));

for im = 1:size(methods,1)

    shortname = methods{im,1};

    for k = 1:numel(metrics)

        name = metrics{k};
        x = all.(shortname).(name);
        x = x(:);
        x = x(~isnan(x) & ~isinf(x));

        N(k,im) = numel(x);

        if ~isempty(x)
            Y(k,im) = median(x,'omitnan');
        end
    end
end

labels = {'Q_{est(med)}', ...
          'Q_{SIC4DVar}', 'Q_{SIC4DVar}^{interp}', ...
          'Q_{MOMMA}', 'Q_{MOMMA}^{interp}', ...
          'Q_{neoBAM}', 'Q_{neoBAM}^{interp}', ...
          'Q_{MetroMan}', 'Q_{MetroMan}^{interp}'};

colors = {cKF,cSIC,cSICi,cMOM,cMOMi,cGEO,cGEOi,cMM,cMMi};

% 去掉完全没有数据的方法
keep = any(~isnan(Y),1);
Y = Y(:,keep);
N = N(:,keep);
labels_use = labels(keep);
colors_use = colors(keep);

% 返回 table
med_table = array2table(Y, ...
    'VariableNames', matlab.lang.makeValidName(labels_use), ...
    'RowNames', metrics);

disp('=== Reach-wise median over all reaches ===')
disp(med_table)

% =========================================================
% 3. 画 barplot
% =========================================================
fig = figure;
tl = tiledlayout(fig,2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

titles = {'(a). Correlation','(b). NSE','(c). rRMSE','(d). rBias'};
ylabs  = {'[-]','[-]','[%]','[%]'};

for k = 1:numel(metrics)

    ax = nexttile;

    % 注意：这里不要用 grouped
    b = bar(Y(k,:));
    hold on
    grid on
    yline(0,'k-','LineWidth',0.8);

    % 每根柱子单独上色
    b.FaceColor = 'flat';
    b.CData = cell2mat(colors_use');
    b.EdgeColor = 'none';

    title(ax,titles{k}, ...
        'FontSize',fontSize+1, ...
        'FontWeight','normal');

    ylabel(ax,ylabs{k}, ...
        'FontSize',fontSize, ...
        'FontWeight','normal');

    set(ax, ...
        'FontSize',fontSize, ...
        'FontWeight','normal', ...
        'XTick',1:numel(labels_use), ...
        'XTickLabel',[]);

    ylim(ax,get_ylim_metric(Y(k,:),metrics{k}));

    yl = ylim(ax);
    offset = 0.025 * range(yl);

    % 数值标注
    for j = 1:numel(labels_use)

        val = Y(k,j);

        if isnan(val)
            continue
        end

        switch lower(metrics{k})
            case {'corr','nse'}
                str = sprintf('%.2f', val);
            case {'rrmse','rb'}
                str = sprintf('%.0f', val);
        end

        if val >= 0
            y_text = val + offset;
            va = 'bottom';
        else
            y_text = val - offset;
            va = 'top';
        end

        text(j, y_text, str, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment',va, ...
            'FontSize',fontSize-3, ...
            'FontWeight','normal');
    end
end

% =========================================================
% 4. legend：fake handles，确保每个产品都有 legend
% =========================================================
ax_legend = nexttile(1);
hold(ax_legend,'on');

hLegend = gobjects(numel(labels_use),1);

for j = 1:numel(labels_use)
hLegend(j) = plot(ax_legend,nan,nan, ...
    'LineWidth',10, ...   % 关键：变成“长条”
    'Color',colors_use{j});
end

lgd = legend(ax_legend,hLegend,labels_use, ...
    'Orientation','horizontal', ...
    'Box','on', ...
    'FontSize',fontSize-2);

lgd.Layout.Tile = 'north';

end

%% =========================================================
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

%% =========================================================
function x = col(v, name)

x = [];

if isempty(v) || ~isstruct(v) || ~isfield(v, name) || isempty(v.(name))
    return
end

x = v.(name);

if ~isnumeric(x)
    x = [];
    return
end

x = x(:);

end

%% =========================================================
function c2 = lighten_color(c1,a)

c2 = c1 + (1-c1)*a;

end

%% =========================================================
function yl = get_ylim_metric(Y, metric_name)

vals = Y(:);
vals = vals(~isnan(vals) & ~isinf(vals));

if isempty(vals)
    switch lower(metric_name)
        case 'corr'
            yl = [-0.2 0.5];
        case 'nse'
            yl = [-1.2 0.5];
        otherwise
            yl = [0 100];
    end
    return
end

switch lower(metric_name)

    case 'corr'
        lo = min(vals);
        hi = max(vals);
        lo = min(lo,0);
        hi = max(hi,0.5);
        pad = 0.08 * max(hi-lo,0.5);
        yl = [lo-pad, hi+pad];

    case 'nse'
        lo = min(vals);
        hi = max(vals);
        hi = max(hi,0.2);
        pad = 0.12 * max(hi-lo,0.5);
        yl = [lo-pad, hi+pad];

    case 'rrmse'
        hi = max(vals);
        hi = max(hi,50);
        yl = [0, hi*1.18];

    case 'rb'
        lo = min(vals);
        hi = max(vals);

        if lo >= 0
            yl = [0, hi*1.18 + eps];
        else
            pad = 0.12 * max(hi-lo,50);
            yl = [lo-pad, hi+pad];
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