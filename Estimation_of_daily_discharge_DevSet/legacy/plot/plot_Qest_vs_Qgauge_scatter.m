function plot_Qest_vs_Qgauge_scatter(Q_results, data_KF_out, start_date)
% plot_Qest_vs_Qgauge_scatter_with_products
%
% 每个 basin / path 画一张图；
% 同一个 path 里，每个有 gauge 且有 Qest/product 数据的 reach 放在一个 tile。
%
% 图的含义：
%   x-axis: Q_{est(med)} 或 SWOT product discharge
%   y-axis: Q_{Gauge}
%
% 图中：
%   黑色虚线  : 1:1 reference line
%   灰色虚线  : Q_Gauge 的 15th / 85th percentile
%
% 注意：
%   这不是严格意义上的 QQ plot；
%   更准确叫 estimated/product-versus-gauge discharge scatter plot.
%
% INPUT:
%   Q_results
%   data_KF_out
%   start_date : 例如 '2000-01-01'
%
% Example:
%   plot_Qest_vs_Qgauge_scatter_with_products(Q_results, data_KF_out, '2000-01-01')

fontSize = 15;
start_dn = datenum(start_date);

% ---- 颜色 ----
cKF  = [0 0.4470 0.7410];      % Qest 蓝色
cSIC = [0.6350 0.0780 0.1840]; % SIC4DVar 红色
cMOM = [0.4660 0.6740 0.1880]; % MOMMA 绿色
cGEO = [0.4940 0.1840 0.5560]; % neoBAM 紫色
cMM  = [0.9290 0.6940 0.1250]; % MetroMan 黄色
cOne = [0 0 0];                % 1:1 line
cPct = [0.35 0.35 0.35];       % percentile line

% =========================================================
% basin loop
% 如果只想画某个 basin，可以改成：
% for ib = 389
% =========================================================
for ib = 389%1:numel(Q_results)

    if ~isfield(Q_results(ib), 'Qest_med') || isempty(Q_results(ib).Qest_med)
        continue
    end

    nPath = numel(Q_results(ib).Qest_med);

    % =====================================================
    % path loop
    % 如果只想画某个 path，可以改成：
    % for p = 1
    % =====================================================
    for p = 1:nPath

        % =================================================
        % 读取 Qest_med
        % =================================================
        Qmed_cell = Q_results(ib).Qest_med{p};

        if isempty(Qmed_cell)
            continue
        end

        if iscell(Qmed_cell)
            Qmed = Qmed_cell{1};
        else
            Qmed = Qmed_cell;
        end

        if isempty(Qmed) || ~isnumeric(Qmed)
            continue
        end

        [nR, nT] = size(Qmed);
        time_vec = start_dn + (0:nT-1);

        % =================================================
        % 读取 Gauge
        % =================================================
        Gauge_path = [];

        if isfield(data_KF_out(ib), 'SVS_Q') && ...
                ~isempty(data_KF_out(ib).SVS_Q) && ...
                numel(data_KF_out(ib).SVS_Q) >= p

            Gauge_path = data_KF_out(ib).SVS_Q{p};
        end

        if isempty(Gauge_path)
            continue
        end

        % =================================================
        % 读取 SWOT products
        % =================================================
        QS_path  = get_field_if_exists(data_KF_out(ib), 'Q_SIC4DVar', p);
        QM_path  = get_field_if_exists(data_KF_out(ib), 'Q_MOMMA',    p);
        QG_path  = get_field_if_exists(data_KF_out(ib), 'Q_geoBAM',   p);
        QMM_path = get_field_if_exists(data_KF_out(ib), 'Q_MetroMan', p);

        % =================================================
        % reach id
        % =================================================
        reach_ids = [];

        if isfield(data_KF_out(ib), 'paths') && ...
                ~isempty(data_KF_out(ib).paths) && ...
                numel(data_KF_out(ib).paths) >= p

            reach_ids = data_KF_out(ib).paths{p};
        end

        % =================================================
        % 找出同时有 Gauge 且至少有一种 Q 数据的 reach
        % =================================================
        valid_reaches = [];

        for r = 1:nR

            % ---- Gauge ----
            if numel(Gauge_path) < r || isempty(Gauge_path{r})
                continue
            end

            gauge_data = Gauge_path{r};

            if ~isnumeric(gauge_data) || size(gauge_data, 2) < 2
                continue
            end

            Qg_dn  = gauge_data(:,1);
            Qg_val = gauge_data(:,2);

            if isempty(Qg_dn) || isempty(Qg_val) || all(isnan(Qg_val))
                continue
            end

            Qg_at_Q_time = interp1(Qg_dn, Qg_val, time_vec, 'linear', nan);

            % ---- Qest ----
            Qest = Qmed(r, :);

            hasKF = has_valid_pair(Qest, Qg_at_Q_time);

            % ---- Products ----
            QS  = match_ts_length(get_reach_ts_from_dailycell(QS_path,  r), nT);
            QM  = match_ts_length(get_reach_ts_from_dailycell(QM_path,  r), nT);
            QGb = match_ts_length(get_reach_ts_from_dailycell(QG_path,  r), nT);
            QMM = match_ts_length(get_reach_ts_from_dailycell(QMM_path, r), nT);

            hasSIC = has_valid_pair(QS,  Qg_at_Q_time);
            hasMOM = has_valid_pair(QM,  Qg_at_Q_time);
            hasGEO = has_valid_pair(QGb, Qg_at_Q_time);
            hasMM  = has_valid_pair(QMM, Qg_at_Q_time);

            if hasKF || hasSIC || hasMOM || hasGEO || hasMM
                valid_reaches(end+1) = r; %#ok<AGROW>
            end
        end

        if isempty(valid_reaches)
            continue
        end

        nValid = numel(valid_reaches);

        % =================================================
        % 排版
        % =================================================
        if nValid <= 8
            nrow = nValid;
            ncol = 1;
            figW = 1000;
        else
            nrow = ceil(nValid / 2);
            ncol = 2;
            figW = 1400;
        end

        figH = max(280 * nrow, 520);

        fig = figure('Name', sprintf('Q products vs Qgauge: ib=%d, path=%d', ib, p), ...
                     'Color', 'w', ...
                     'Position', [60, 40, figW, figH]);

        tl = tiledlayout(fig, nrow, ncol, ...
            'TileSpacing', 'compact', ...
            'Padding', 'compact');


        xlabel(tl, 'Q_{est/SWOT} [m^3/s]', ...
            'FontSize', fontSize+1);

        ylabel(tl, 'Q_{Gauge} [m^3/s]', ...
            'FontSize', fontSize+1);

        % legend handles
        hKF  = [];
        hSIC = [];
        hMOM = [];
        hGEO = [];
        hMM  = [];
        ax_first = [];

        % =================================================
        % 每个 reach 一个 scatter plot
        % =================================================
        for ii = 1:nValid

            r = valid_reaches(ii);
            ax = nexttile(tl);

            if isempty(ax_first)
                ax_first = ax;
            end

            hold(ax, 'on');

            % ---- Gauge ----
            gauge_data = Gauge_path{r};
            Qg_dn  = gauge_data(:,1);
            Qg_val = gauge_data(:,2);

            Qg_at_Q_time = interp1(Qg_dn, Qg_val, time_vec, 'linear', nan);
            Qg_col = Qg_at_Q_time(:);

            % ---- Qest and products ----
            Qest = Qmed(r, :);

            QS  = match_ts_length(get_reach_ts_from_dailycell(QS_path,  r), nT);
            QM  = match_ts_length(get_reach_ts_from_dailycell(QM_path,  r), nT);
            QGb = match_ts_length(get_reach_ts_from_dailycell(QG_path,  r), nT);
            QMM = match_ts_length(get_reach_ts_from_dailycell(QMM_path, r), nT);

            % =================================================
            % 先收集所有有效点，用于统一 axis / 1:1 line
            % =================================================
            all_x = [];
            all_y = [];

            [xKF,  yKF]  = get_pair(Qest(140:end), Qg_col(140:end));
            [xSIC, ySIC] = get_pair(QS,   Qg_col);
            [xMOM, yMOM] = get_pair(QM,   Qg_col);
            [xGEO, yGEO] = get_pair(QGb,  Qg_col);
            [xMM,  yMM]  = get_pair(QMM,  Qg_col);

            all_x = [all_x; xKF; xSIC; xMOM; xGEO; xMM];
            all_y = [all_y; yKF; ySIC; yMOM; yGEO; yMM];

            if isempty(all_x) || isempty(all_y)
                continue
            end

            qmin = min([all_x; all_y]);
            qmax = max([all_x; all_y]);

            if qmin == qmax
                qmin = qmin - 1;
                qmax = qmax + 1;
            end

            pad = 0.05 * (qmax - qmin);
            qlo = qmin - pad;
            qhi = qmax + pad;

            % Gauge 15th / 85th percentile
            q15 = prctile(all_y, 15);
            q85 = prctile(all_y, 85);

            % =================================================
            % 画 scatter
            % =================================================


            % 2) SIC4DVar
            if ~isempty(xSIC)
                h = scatter(ax, xSIC, ySIC, ...
                    34, ...
                    '*', ...
                    'MarkerEdgeColor', cSIC, ...
                    'LineWidth', 1.1);

                if isempty(hSIC), hSIC = h; end
            end

            % 3) MOMMA
            if ~isempty(xMOM)
                h = scatter(ax, xMOM, yMOM, ...
                    34, ...
                    'o', ...
                    'MarkerEdgeColor', cMOM, ...
                    'LineWidth', 1.1);

                if isempty(hMOM), hMOM = h; end
            end

            % 4) neoBAM / geoBAM
            if ~isempty(xGEO)
                h = scatter(ax, xGEO, yGEO, ...
                    34, ...
                    's', ...
                    'MarkerEdgeColor', cGEO, ...
                    'LineWidth', 1.1);

                if isempty(hGEO), hGEO = h; end
            end

            % 5) MetroMan
            if ~isempty(xMM)
                h = scatter(ax, xMM, yMM, ...
                    34, ...
                    'x', ...
                    'MarkerEdgeColor', cMM, ...
                    'LineWidth', 1.2);

                if isempty(hMM), hMM = h; end
            end

            % 1) Qest
            if ~isempty(xKF)
                h = scatter(ax, xKF, yKF, ...
                    30, ...
                    'filled', ...
                    'MarkerFaceColor', cKF, ...
                    'MarkerFaceAlpha', 0.68, ...
                    'MarkerEdgeColor', 'none');

                if isempty(hKF), hKF = h; end
            end
            % =================================================
            % 1:1 reference line
            % =================================================
            href = plot(ax, [qlo qhi], [qlo qhi], ':', ...
                'Color', cOne, ...
                'LineWidth', 1.2);

            % Gauge 15% line
            hline = yline(ax, q15, '--', ...
                'Q_{Gauge,15%}', ...
                'Color', cPct, ...
                'LineWidth', 1.2, ...
                'LabelHorizontalAlignment', 'right', ...
                'LabelVerticalAlignment', 'bottom', ...
                'FontSize', fontSize-2);

            % Gauge 85% line
            yline(ax, q85, '--', ...
                'Q_{Gauge,85%}', ...
                'Color', cPct, ...
                'LineWidth', 1.2, ...
                'LabelHorizontalAlignment', 'right', ...
                'LabelVerticalAlignment', 'top', ...
                'FontSize', fontSize-2);

            xlim(ax, [qlo qhi]);
            ylim(ax, [qlo qhi]);

            axis(ax, 'square');
            grid(ax, 'on');
            box(ax, 'on');

            set(ax, 'FontSize', fontSize);

            % =================================================
            % reach id
            % =================================================
            reach_id_str = sprintf('%d', r);

            if ~isempty(reach_ids) && numel(reach_ids) >= r && ~isempty(reach_ids(r))
                reach_id_str = sprintf('%s', string(reach_ids(r)));
            end

            title(ax, sprintf('Reach %s', reach_id_str), ...
                'FontSize', fontSize, ...
                'FontWeight', 'normal');

            % 不是最左列，不显示 y tick label
            col_id = mod(ii-1, ncol) + 1;

            if col_id ~= 1
                set(ax, 'YTickLabel', []);
            end

            % 不是最后一行，不显示 x tick label
            row_id = ceil(ii / ncol);

            if row_id ~= nrow
                set(ax, 'XTickLabel', []);
            end
        end

        % =================================================
        % 总 legend
        % =================================================
        leg_handles = [];
        leg_labels  = {};

        if ~isempty(hKF)
            leg_handles = [leg_handles, hKF];
            leg_labels{end+1} = 'Q_{est(med)}';
        end
        if ~isempty(hSIC)
            leg_handles = [leg_handles, hSIC];
            leg_labels{end+1} = 'Q_{SIC4DVar}';
        end
        if ~isempty(hMOM)
            leg_handles = [leg_handles, hMOM];
            leg_labels{end+1} = 'Q_{MOMMA}';
        end
        if ~isempty(hGEO)
            leg_handles = [leg_handles, hGEO];
            leg_labels{end+1} = 'Q_{neoBAM}';
        end
        if ~isempty(hMM)
            leg_handles = [leg_handles, hMM];
            leg_labels{end+1} = 'Q_{MetroMan}';
        end
        leg_handles = [leg_handles, href];
        leg_labels{end+1} = '1:1 line';
        leg_handles = [leg_handles, hline];
        leg_labels{end+1} = 'Gauge 15/85th percentiles';
        if ~isempty(leg_handles) && ~isempty(ax_first)
            lgd = legend(ax_first, leg_handles, leg_labels, ...
                'Box', 'on', ...
                'FontSize', fontSize, ...
                'Orientation', 'vertical');

            lgd.Units = 'pixels';

            if ncol == 1
                lgd.Position = [225,231,1000,520];
            else
                lgd.Position = [225,231,1000,520];
            end
        end

    end
end

end

%% ===== 小工具：安全取得 data_KF_out(ib).FIELD{p} =====
function path_cell = get_field_if_exists(s, fieldname, p)

path_cell = [];

if isfield(s, fieldname) && ~isempty(s.(fieldname)) && numel(s.(fieldname)) >= p
    path_cell = s.(fieldname){p};
end

end

%% ===== 小工具：把 reach×day cell 转成一条时间序列 1×nT double =====
function q_ts = get_reach_ts_from_dailycell(path_cell, r)

q_ts = [];

if isempty(path_cell) || ~iscell(path_cell) || size(path_cell, 1) < r
    return
end

nDays = size(path_cell, 2);
q_ts  = nan(1, nDays);

row = path_cell(r, :);

for tt = 1:nDays
    v = row{tt};

    if ~isempty(v) && isnumeric(v)
        q_ts(tt) = v;
    end
end

end

%% ===== 小工具：把产品序列长度匹配到 nT =====
function qplot = match_ts_length(q, nT)

qplot = [];

if isempty(q) || all(isnan(q))
    return
end

q = q(:)';

if numel(q) == nT
    qplot = q;
elseif numel(q) == nT + 1
    qplot = q(2:end);
else
    return
end

end

%% ===== 小工具：判断某个 Q 和 Gauge 是否有有效配对 =====
function tf = has_valid_pair(q, qg)

tf = false;

if isempty(q) || isempty(qg)
    return
end

q  = q(:);
qg = qg(:);

n = min(numel(q), numel(qg));

if n == 0
    return
end

q  = q(1:n);
qg = qg(1:n);

idx = ~isnan(q) & ~isnan(qg);

tf = any(idx);

end

%% ===== 小工具：提取 Q-product / Q-gauge 有效配对 =====
function [x, y] = get_pair(q, qg)

x = [];
y = [];

if isempty(q) || isempty(qg)
    return
end

q  = q(:);
qg = qg(:);

n = min(numel(q), numel(qg));

if n == 0
    return
end

q  = q(1:n);
qg = qg(1:n);

idx = ~isnan(q) & ~isnan(qg);

x = q(idx);
y = qg(idx);

end