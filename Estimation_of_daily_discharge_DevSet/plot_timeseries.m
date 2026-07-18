function plot_timeseries(Q_results, data_KF_out, start_date, ib, p, option)
% PLOT_TIMESERIES
% 每个 basin / path 画一张图；
% 同一个 path 里，每个有数据的 reach 放在一个 tile
%
% 排版规则：
%   - nValid <= 8  : nValid x 1
%   - nValid > 8   : 两列排布

fontSize = 13;
start_dn = datenum(start_date);

if nargin < 4 || isempty(ib)
    ib = 1;
end

if nargin < 5 || isempty(p)
    p = 1;
end

if nargin < 6 || isempty(option)
    option = 1;
end

% ---- 颜色 ----
cKF  = [0 0.4470 0.7410];      % 蓝色
cSIC = [0.6350 0.0780 0.1840]; % 红色
cMOM = [0.4660 0.6740 0.1880]; % 绿色
cGEO = [0.4940 0.1840 0.5560]; % 紫色
cMM  = [0.9290 0.6940 0.1250]; % 黄色
cGau = [0 0 0];                % 黑色

if ib > numel(Q_results) || ~isfield(Q_results(ib), 'Qest_med') || ...
        numel(Q_results(ib).Qest_med) < p
    warning('No Qest_med found for ib=%d, path=%d.', ib, p);
    return;
end

Qmed_cell = Q_results(ib).Qest_med{p};
if isempty(Qmed_cell)
    warning('Empty Qest_med for ib=%d, path=%d.', ib, p);
    return;
end

if iscell(Qmed_cell)
    Qmed = Qmed_cell{1};
else
    Qmed = Qmed_cell;
end

if isempty(Qmed) || ~isnumeric(Qmed)
    warning('Invalid Qest_med for ib=%d, path=%d.', ib, p);
    return;
end

[nR, nT] = size(Qmed);
time_vec = start_dn + (0:nT-1);

% ---- Gauge ----
Gauge_path = get_gauge_path(data_KF_out(ib), p);

% ---- SWOT products ----
QS_path  = get_field_if_exists(data_KF_out(ib), 'Q_SIC4DVar', p);
QM_path  = get_field_if_exists(data_KF_out(ib), 'Q_MOMMA',    p);
QG_path  = get_field_if_exists(data_KF_out(ib), 'Q_geoBAM',   p);
QMM_path = get_field_if_exists(data_KF_out(ib), 'Q_MetroMan', p);

% =========================================================
% 找出要画的 reach
% =========================================================
valid_reaches = [];
reach_ids = [];
if isfield(data_KF_out(ib), 'paths') && ~isempty(data_KF_out(ib).paths) && numel(data_KF_out(ib).paths) >= p
    reach_ids = data_KF_out(ib).paths{p};
end

if option == 1
    for r = 1:nR
        if has_gauge_reach(Gauge_path, r)
            valid_reaches(end+1) = r; %#ok<AGROW>
        end
    end
elseif option == 2
    valid_reaches = 1:nR;
else
    error('option must be 1 or 2.');
end

if isempty(valid_reaches)
    warning('No reaches to plot for ib=%d, path=%d, option=%d.', ib, p, option);
    return;
end

nValid = numel(valid_reaches);

% =========================================================
% 排版
% =========================================================
if nValid <= 8
    nrow = nValid;
    ncol = 1;
    figW = 1250;
else
    ncol = 2;
    nrow = ceil(nValid / 2);
    figW = 1600;
end

figH = max(210*nrow, 460);

fig = figure('Name', sprintf('ib=%d, path=%d', ib, p), ...
             'Position', [60, 40, figW, figH]);

tl = tiledlayout(fig, nrow, ncol, ...
    'TileSpacing', 'none', ...
    'Padding', 'compact');

% 给顶部 legend 留点空间
tl.Padding = 'compact';
tl.TileSpacing = 'compact';

% 统一标题和坐标标签
title(tl, sprintf('ib = %d, path = %d', ib, p), ...
    'FontSize', fontSize+2, 'FontWeight', 'bold');
ylabel(tl, '[m^3/s]', ...
    'FontSize', fontSize+1, 'FontWeight', 'bold');
xlabel(tl, 'Time', ...
    'FontSize', fontSize+1, 'FontWeight', 'bold');

% 用于总 legend 的句柄
hKF  = [];
hSIC = [];
hMOM = [];
hGEO = [];
hMM  = [];
hGau = [];

ax_first = [];

for ii = 1:nValid
    r = valid_reaches(ii);

    ax = nexttile(tl);
    if isempty(ax_first)
        ax_first = ax;
    end
    hold(ax, 'on');

    Qkf = Qmed(r, :);

    % ---- Gauge ----
    [Qg_dn, Qg_val] = get_gauge_reach_ts(Gauge_path, r);

    % ---- SWOT products ----
    QS  = get_reach_ts_from_dailycell(QS_path,  r);
    QM  = get_reach_ts_from_dailycell(QM_path,  r);
    QGb = get_reach_ts_from_dailycell(QG_path,  r);
    QMM = get_reach_ts_from_dailycell(QMM_path, r);


    % 2) SIC4DVar
    if ~isempty(QS) && ~all(isnan(QS))
        qplot = match_ts_length(QS, nT);
        if ~isempty(qplot)
            h = plot(ax, time_vec, qplot, '*', ...
                'Color', cSIC, 'LineWidth', 1.3, 'MarkerSize', 6);
            if isempty(hSIC), hSIC = h; end
        end
    end

    % 3) MOMMA
    if ~isempty(QM) && ~all(isnan(QM))
        qplot = match_ts_length(QM, nT);
        if ~isempty(qplot)
            h = plot(ax, time_vec, qplot, 'o', ...
                'Color', cMOM, 'LineWidth', 1.3, 'MarkerSize', 6);
            if isempty(hMOM), hMOM = h; end
        end
    end

    % 4) geoBAM
    if ~isempty(QGb) && ~all(isnan(QGb))
        qplot = match_ts_length(QGb, nT);
        if ~isempty(qplot)
            h = plot(ax, time_vec, qplot, 's', ...
                'Color', cGEO, 'LineWidth', 1.3, 'MarkerSize', 6);
            if isempty(hGEO), hGEO = h; end
        end
    end

    % 5) MetroMan
    if ~isempty(QMM) && ~all(isnan(QMM))
        qplot = match_ts_length(QMM, nT);
        if ~isempty(qplot)
            h = plot(ax, time_vec, qplot, 'x', ...
                'Color', cMM, 'LineWidth', 1.3, 'MarkerSize', 6);
            if isempty(hMM), hMM = h; end
        end
    end

    % 6) Gauge
    if ~isempty(Qg_dn) && ~isempty(Qg_val) && ~all(isnan(Qg_val))
        h = plot(ax, Qg_dn, Qg_val, '-', ...
            'Color', cGau, 'LineWidth', 1.5);
        if isempty(hGau), hGau = h; end
    end
%             if ii ==3
% Qkf(432:488) =Qkf(432:488)+90;
%             end
%             if ii ==4
% Qkf(432:488) =Qkf(432:488)+140;
%             end
%                         if ii ==5
% Qkf(432:488) =Qkf(432:488)-90;
%             end
%             if ii ==6
% Qkf(432:488) =Qkf(432:488)+90;
%             end

    % 1) Estimated discharge
    if ~isempty(Qkf) && ~all(isnan(Qkf))
        h = plot(ax, time_vec, Qkf, '-', ...
            'Color', cKF, 'LineWidth', 1.8);
        if isempty(hKF), hKF = h; end
    end

    reach_id_str = sprintf('%d', r);   % 默认先用序号 r
    if ~isempty(reach_ids) && numel(reach_ids) >= r && ~isempty(reach_ids(r))
        reach_id_str = sprintf('%s', string(reach_ids(r)));
    end

            

    datetick(ax, 'x', 'yyyy-mm', 'keeplimits');
    xlim(ax, [time_vec(1), time_vec(end)]);
    grid(ax, 'on');
    set(ax, 'FontSize', fontSize);
    %         text(ax, 1, 0.96, sprintf('%s', reach_id_str), ...
    % 'Units', 'normalized', ...
    % 'HorizontalAlignment', 'right', ...
    % 'VerticalAlignment', 'top', ...
    % 'FontSize', fontSize, ...
    % 'FontWeight', 'normal');
text(ax, 1, 1, reach_id_str, ...
    'Units','normalized', ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom', ...
    'FontSize',fontSize, ...
    'Clipping','off');
    % 不是最左列 -> 不显示 yticklabel
    col_id = mod(ii-1, ncol) + 1;
    if col_id ~= 1
        set(ax, 'YTickLabel', []);
    end

    % 不是最后一行 -> 不显示 xticklabel
    row_id = ceil(ii / ncol);
    if row_id ~= nrow
        set(ax, 'XTickLabel', []);
    end

end

% =========================================================
% 单个 legend
% =========================================================
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
if ~isempty(hGau)
    leg_handles = [leg_handles, hGau];
    leg_labels{end+1} = 'Q_{Gauge}';
end

if ~isempty(leg_handles) && ~isempty(ax_first)
    lgd = legend(ax_first, leg_handles, leg_labels, ...
        'Box', 'on', ...
        'FontSize', fontSize+1, ...
        'Orientation', 'horizontal');
pos = ax.Position;
pos(3) = pos(3) * 1.05;   % 加宽子图
ax.Position = pos;
    drawnow;
    lgd.Units = 'normalized';

    % 顶部居中，带边框
    if ncol == 1
        lgd.Position = [0.2,0.957081545064378,0.648525469168901,0.037918454935622];
    else
        lgd.Position = [0.24 0.965 0.52 0.03];
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

%% ===== 小工具：只用 SVS_Q =====
function Gauge_path = get_gauge_path(s, p)
Gauge_path = [];
if isfield(s, 'SVS_Q') && ~isempty(s.SVS_Q) && numel(s.SVS_Q) >= p
    Gauge_path = s.SVS_Q{p};
end
end

%% ===== 小工具：判断某个 reach 是否有 gauge =====
function tf = has_gauge_reach(Gauge_path, r)
[Qg_dn, Qg_val] = get_gauge_reach_ts(Gauge_path, r);
tf = ~isempty(Qg_dn) && ~isempty(Qg_val) && any(isfinite(Qg_val));
end

%% ===== 小工具：取某个 reach 的 gauge 序列 =====
function [Qg_dn, Qg_val] = get_gauge_reach_ts(Gauge_path, r)
Qg_dn = [];
Qg_val = [];
if ~isempty(Gauge_path) && numel(Gauge_path) >= r && ~isempty(Gauge_path{r})
    gauge_data = Gauge_path{r};
    if isnumeric(gauge_data) && size(gauge_data, 2) >= 2
        Qg_dn  = gauge_data(:,1);
        Qg_val = gauge_data(:,2);
    end
end
end

%% ===== 小工具：把 reach×day cell 转成一条时间序列（1×nT double） =====
function q_ts = get_reach_ts_from_dailycell(path_cell, r)
q_ts = [];

if isempty(path_cell) || ~iscell(path_cell) || size(path_cell,1) < r
    return;
end

nDays = size(path_cell, 2);
q_ts  = nan(1, nDays);

row = path_cell(r, :);

for tt = 1:nDays
    v = row{tt};
    if ~isempty(v) && isnumeric(v)
        q_ts(tt) = mean(v(:), 'omitnan');
    end
end
end

%% ===== 小工具：把产品序列长度匹配到 nT =====
function qplot = match_ts_length(q, nT)
qplot = [];

if isempty(q) || all(isnan(q))
    return;
end

if numel(q) == nT
    qplot = q;
elseif numel(q) == nT + 1
    qplot = q(2:end);
end
end
