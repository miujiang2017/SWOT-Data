function plot_metric_compare_est_vs_interp(Q_results)
% 把 4 个原始产品合并成一类（蓝圈）
% 把 4 个 interp 产品合并成一类（红叉）
% 横轴: product metric
% 纵轴: Q_est(med) metric

metric_names = {'corr','NSE','rRMSE','rB'};
panel_titles = {'(a) Correlation [-]', ...
                '(b) NSE [-]', ...
                '(c) rRMSE [%]', ...
                '(d) rBias [%]'};

products_org = {'vali_SIC4DVar', ...
                'vali_MOMMA', ...
                'vali_geoBAM', ...
                'vali_MetroMan'};

products_int = {'vali_SIC4DVar_interp', ...
                'vali_MOMMA_interp', ...
                'vali_geoBAM_interp', ...
                'vali_MetroMan_interp'};

% ---------------------------------------------------------
% 1) 初始化：每个 metric 只存两大类
% ---------------------------------------------------------
for m = 1:numel(metric_names)
    f = metric_names{m};

    D.org.(f).x = [];
    D.org.(f).y = [];

    D.int.(f).x = [];
    D.int.(f).y = [];
end

% ---------------------------------------------------------
% 2) 收集数据
% ---------------------------------------------------------
for ib = 1:numel(Q_results)

    if ~isfield(Q_results(ib),'vali_estmed') || isempty(Q_results(ib).vali_estmed)
        continue
    end

    nPath = numel(Q_results(ib).vali_estmed);

    for p = 1:nPath

        S_est = getS(Q_results(ib), 'vali_estmed', p);
        if isempty(S_est)
            continue
        end

        for m = 1:numel(metric_names)
            f = metric_names{m};

            v_est = getv(S_est, f);
            if isempty(v_est)
                continue
            end

            % -------- 原始 4 产品，全都并到 org --------
            for i = 1:4
                S_org = getS(Q_results(ib), products_org{i}, p);
                v_org = getv(S_org, f);

                if isempty(v_org)
                    continue
                end

                n = min(numel(v_est), numel(v_org));
                if n == 0
                    continue
                end

                D.org.(f).x = [D.org.(f).x; v_org(1:n)];
                D.org.(f).y = [D.org.(f).y; v_est(1:n)];
            end

            % -------- interp 4 产品，全都并到 int --------
            for i = 1:4
                S_int = getS(Q_results(ib), products_int{i}, p);
                v_int = getv(S_int, f);

                if isempty(v_int)
                    continue
                end

                n = min(numel(v_est), numel(v_int));
                if n == 0
                    continue
                end

                D.int.(f).x = [D.int.(f).x; v_int(1:n)];
                D.int.(f).y = [D.int.(f).y; v_est(1:n)];
            end
        end
    end
end

% ---------------------------------------------------------
% 3) 作图
% ---------------------------------------------------------
figure('color','w','position',[100 100 1000 800])
lim_vec=[0,1;
    -10,1;
    0,100;
    0,100];

for k = 1:4
    f = metric_names{k};

    subplot(2,2,k); hold on; box on

    % 原始产品
    x1 = D.org.(f).x;
    y1 = D.org.(f).y;
    m1 = ~isnan(x1) & ~isnan(y1);

    % interp 产品
    x2 = D.int.(f).x;
    y2 = D.int.(f).y;
    m2 = ~isnan(x2) & ~isnan(y2);

    h1 = scatter(x1(m1), y1(m1), 26, ...
        'o', ...
        'MarkerEdgeColor', 'b', ...
        'LineWidth', 0.9);

    h2 = scatter(x2(m2), y2(m2), 26, ...
        'x', ...
        'MarkerEdgeColor', 'r', ...
        'LineWidth', 0.9);

    allx = [x1(m1); x2(m2)];
    ally = [y1(m1); y2(m2)];

    if isempty(allx)
        title(panel_titles{k}, 'FontSize', 14)
        xlabel('Product metric')
        ylabel('Q_{est(med)} metric')
        set(gca, 'FontSize', 12)
        axis square
        continue
    end

    xmin = min([allx; ally]);
    xmax = max([allx; ally]);

    if xmax == xmin
        pad = 0.1 * max(1, abs(xmax));
    else
        pad = 0.03 * (xmax - xmin);
    end

    xlim([lim_vec(k,1), lim_vec(k,2)])
    ylim([lim_vec(k,1), lim_vec(k,2)])

    xx = linspace(xmin-pad, xmax+pad, 200);
    hline = plot(xx, xx, 'k-.', 'LineWidth', 1.2);

    title(panel_titles{k}, 'FontSize', 14)
    xlabel('Product metric')
    ylabel('Q_{est(med)} metric')
    set(gca, 'FontSize', 12)
    axis square

    if k == 1
        legend([h1 h2 hline], ...
            {'Original products', 'Interpolated products', '1:1 line'}, ...
            'Location', 'northoutside', ...
            'Orientation', 'horizontal');
    end
end

end

% =========================================================
% 子函数
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

function v = getv(S, f)

if ~isstruct(S) || ~isfield(S, f) || isempty(S.(f))
    v = [];
else
    v = S.(f)(:);
end

end