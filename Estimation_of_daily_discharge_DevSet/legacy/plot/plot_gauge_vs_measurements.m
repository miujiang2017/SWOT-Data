function plot_gauge_vs_measurements(data_KF_out, ib, p, start_date, end_date)
% PLOT_GAUGE_VS_MEASUREMENTS
% 每个 reach 单独出一张图，不用 subplot
%
% 产品默认时间范围:
%   2023-03-29 到 2025-05-02
%
% 用户输入 start_date / end_date 后，只画这个范围内的数据
%
% Example:
% plot_gauge_vs_measurements(data_KF_out, 368, 1, '2024-01-01', '2024-12-31')

fontSize = 13;

% =========================================================
% 默认产品时间轴
% =========================================================
product_start_dn = datenum('2023-03-29');
product_end_dn   = datenum('2025-05-02');
product_time_vec = product_start_dn:product_end_dn;
nT_product = numel(product_time_vec);

% =========================================================
% 用户自定义画图时间范围
% =========================================================
user_start_dn = datenum(start_date);
user_end_dn   = datenum(end_date);

if user_start_dn < product_start_dn
    warning('start_date is earlier than product start date. Use product_start_date instead.');
    user_start_dn = product_start_dn;
end

if user_end_dn > product_end_dn
    warning('end_date is later than product end date. Use product_end_date instead.');
    user_end_dn = product_end_dn;
end

if user_start_dn > user_end_dn
    error('start_date must be earlier than or equal to end_date.');
end

idx_prod = product_time_vec >= user_start_dn & product_time_vec <= user_end_dn;
time_vec_plot = product_time_vec(idx_prod);

% =========================================================
% 颜色
% =========================================================
cSIC = [0.6350 0.0780 0.1840]; % red
cMOM = [0.4660 0.6740 0.1880]; % green
cGEO = [0.4940 0.1840 0.5560]; % purple
cMM  = [0.9290 0.6940 0.1250]; % yellow
cGau = [0 0 0];                % black

% =========================================================
% Gauge
% =========================================================
Gauge_path = [];
if isfield(data_KF_out(ib), 'Gauge_Q') && ...
        ~isempty(data_KF_out(ib).Gauge_Q) && ...
        numel(data_KF_out(ib).Gauge_Q) >= p
    Gauge_path = data_KF_out(ib).Gauge_Q{p};
end

% =========================================================
% Measurement products
% =========================================================
QS_path  = get_field_if_exists(data_KF_out(ib), 'Q_SIC4DVar', p);
QM_path  = get_field_if_exists(data_KF_out(ib), 'Q_MOMMA',    p);
QG_path  = get_field_if_exists(data_KF_out(ib), 'Q_geoBAM',   p);
QMM_path = get_field_if_exists(data_KF_out(ib), 'Q_MetroMan', p);

% =========================================================
% Reach IDs
% =========================================================
reach_ids = [];
if isfield(data_KF_out(ib), 'paths') && ...
        ~isempty(data_KF_out(ib).paths) && ...
        numel(data_KF_out(ib).paths) >= p
    reach_ids = data_KF_out(ib).paths{p};
end

% =========================================================
% 判断 reach 数量
% =========================================================
nR = 0;

if ~isempty(Gauge_path)
    nR = max(nR, numel(Gauge_path));
end

if ~isempty(QS_path) && iscell(QS_path)
    nR = max(nR, size(QS_path, 1));
end

if ~isempty(QM_path) && iscell(QM_path)
    nR = max(nR, size(QM_path, 1));
end

if ~isempty(QG_path) && iscell(QG_path)
    nR = max(nR, size(QG_path, 1));
end

if ~isempty(QMM_path) && iscell(QMM_path)
    nR = max(nR, size(QMM_path, 1));
end

if nR == 0
    warning('No reach data found.');
    return;
end

% =========================================================
% 找有数据的 reach
% =========================================================
valid_reaches = [];

for r = 1:nR

    % -----------------------------------------------------
    % Gauge
    % -----------------------------------------------------
    Qg_dn  = [];
    Qg_val = [];

    if ~isempty(Gauge_path) && numel(Gauge_path) >= r && ~isempty(Gauge_path{r})
        gauge_data = Gauge_path{r};

        if isnumeric(gauge_data) && size(gauge_data, 2) >= 2
            Qg_dn  = gauge_data(:, 1);
            Qg_val = gauge_data(:, 2);
        end
    end

    if ~isempty(Qg_dn)
        idx_gauge = Qg_dn >= user_start_dn & Qg_dn <= user_end_dn;
        Qg_val_plot = Qg_val(idx_gauge);
    else
        Qg_val_plot = [];
    end

    % -----------------------------------------------------
    % Products
    % -----------------------------------------------------
    QS_all  = get_reach_ts_from_dailycell(QS_path,  r);
    QM_all  = get_reach_ts_from_dailycell(QM_path,  r);
    QGb_all = get_reach_ts_from_dailycell(QG_path,  r);
    QMM_all = get_reach_ts_from_dailycell(QMM_path, r);

    QS_all  = match_ts_length(QS_all,  nT_product);
    QM_all  = match_ts_length(QM_all,  nT_product);
    QGb_all = match_ts_length(QGb_all, nT_product);
    QMM_all = match_ts_length(QMM_all, nT_product);

    QS  = subset_by_date(QS_all,  idx_prod);
    QM  = subset_by_date(QM_all,  idx_prod);
    QGb = subset_by_date(QGb_all, idx_prod);
    QMM = subset_by_date(QMM_all, idx_prod);

    hasGauge = ~isempty(Qg_val_plot) && ~all(isnan(Qg_val_plot));
    hasSIC   = ~isempty(QS)  && ~all(isnan(QS));
    hasMOM   = ~isempty(QM)  && ~all(isnan(QM));
    hasGEO   = ~isempty(QGb) && ~all(isnan(QGb));
    hasMM    = ~isempty(QMM) && ~all(isnan(QMM));

    if hasGauge || hasSIC || hasMOM || hasGEO || hasMM
        valid_reaches(end+1) = r; %#ok<AGROW>
    end
end

if isempty(valid_reaches)
    warning('No valid Gauge or measurement data found in selected date range.');
    return;
end

% =========================================================
% 一个 reach 一个 figure
% =========================================================
for ii = 1:numel(valid_reaches)

    r = valid_reaches(ii);

    % -----------------------------------------------------
    % Reach ID
    % -----------------------------------------------------
    reach_id_str = sprintf('%d', r);

    if ~isempty(reach_ids) && numel(reach_ids) >= r && ~isempty(reach_ids(r))
        reach_id_str = sprintf('%s', string(reach_ids(r)));
    end

    % -----------------------------------------------------
    % New figure
    % -----------------------------------------------------
    figure('Name', sprintf('ib=%d, path=%d, reach=%s', ib, p, reach_id_str), ...
           'Position', [100, 100, 1250, 420]);

    hold on;

    % 每张图单独 legend
    leg_handles = [];
    leg_labels  = {};

    % -----------------------------------------------------
    % Gauge
    % -----------------------------------------------------
    Qg_dn  = [];
    Qg_val = [];

    if ~isempty(Gauge_path) && numel(Gauge_path) >= r && ~isempty(Gauge_path{r})
        gauge_data = Gauge_path{r};

        if isnumeric(gauge_data) && size(gauge_data, 2) >= 2
            Qg_dn  = gauge_data(:, 1);
            Qg_val = gauge_data(:, 2);
        end
    end

    if ~isempty(Qg_dn)
        idx_gauge = Qg_dn >= user_start_dn & Qg_dn <= user_end_dn;
        Qg_dn_plot  = Qg_dn(idx_gauge);
        Qg_val_plot = Qg_val(idx_gauge);
    else
        Qg_dn_plot  = [];
        Qg_val_plot = [];
    end

    % -----------------------------------------------------
    % Products
    % -----------------------------------------------------
    QS_all  = get_reach_ts_from_dailycell(QS_path,  r);
    QM_all  = get_reach_ts_from_dailycell(QM_path,  r);
    QGb_all = get_reach_ts_from_dailycell(QG_path,  r);
    QMM_all = get_reach_ts_from_dailycell(QMM_path, r);

    QS_all  = match_ts_length(QS_all,  nT_product);
    QM_all  = match_ts_length(QM_all,  nT_product);
    QGb_all = match_ts_length(QGb_all, nT_product);
    QMM_all = match_ts_length(QMM_all, nT_product);

    QS  = subset_by_date(QS_all,  idx_prod);
    QM  = subset_by_date(QM_all,  idx_prod);
    QGb = subset_by_date(QGb_all, idx_prod);
    QMM = subset_by_date(QMM_all, idx_prod);

    % -----------------------------------------------------
    % Plot products
    % -----------------------------------------------------
    if ~isempty(QS) && ~all(isnan(QS))
        h = plot(time_vec_plot, QS, '*', ...
            'Color', cSIC, ...
            'LineWidth', 1.3, ...
            'MarkerSize', 6);

        leg_handles = [leg_handles, h];
        leg_labels{end+1} = 'Q_{SIC4DVar}';
    end
    % 
    % if ~isempty(QM) && ~all(isnan(QM))
    %     h = plot(time_vec_plot, QM, 'o', ...
    %         'Color', cMOM, ...
    %         'LineWidth', 1.3, ...
    %         'MarkerSize', 6);
    % 
    %     leg_handles = [leg_handles, h];
    %     leg_labels{end+1} = 'Q_{MOMMA}';
    % end
    % 
    % if ~isempty(QGb) && ~all(isnan(QGb))
    %     h = plot(time_vec_plot, QGb, 's', ...
    %         'Color', cGEO, ...
    %         'LineWidth', 1.3, ...
    %         'MarkerSize', 6);
    % 
    %     leg_handles = [leg_handles, h];
    %     leg_labels{end+1} = 'Q_{geoBAM}';
    % end
    % 
    % if ~isempty(QMM) && ~all(isnan(QMM))
    %     h = plot(time_vec_plot, QMM, 'x', ...
    %         'Color', cMM, ...
    %         'LineWidth', 1.3, ...
    %         'MarkerSize', 6);
    % 
    %     leg_handles = [leg_handles, h];
    %     leg_labels{end+1} = 'Q_{MetroMan}';
    % end

    % -----------------------------------------------------
    % Plot Gauge
    % -----------------------------------------------------
    if ~isempty(Qg_dn_plot) && ~isempty(Qg_val_plot) && ~all(isnan(Qg_val_plot))
        h = plot(Qg_dn_plot, Qg_val_plot, '-', ...
            'Color', cGau, ...
            'LineWidth', 1.8);

        leg_handles = [leg_handles, h];
        leg_labels{end+1} = 'Q_{Gauge}';
    end

    % -----------------------------------------------------
    % Axis / labels
    % -----------------------------------------------------
    xlim([user_start_dn, user_end_dn]);
    datetick('x', 'yyyy-mm', 'keeplimits');

    grid on;
    box on;

    set(gca, 'FontSize', fontSize);

    xlabel('Time', ...
        'FontSize', fontSize + 1, ...
        'FontWeight', 'bold');

    ylabel('[m^3/s]', ...
        'FontSize', fontSize + 1, ...
        'FontWeight', 'bold');

    title(sprintf('Gauge vs measurements | ib = %d, path = %d, reach = %s', ...
        ib, p, reach_id_str), ...
        'FontSize', fontSize + 2, ...
        'FontWeight', 'bold');

    if ~isempty(leg_handles)
        legend(leg_handles, leg_labels, ...
            'Box', 'on', ...
            'FontSize', fontSize, ...
            'Location', 'best');
    end

end

end

%% =========================================================
% 小工具：安全取得 data_KF_out(ib).FIELD{p}
% =========================================================
function path_cell = get_field_if_exists(s, fieldname, p)

path_cell = [];

if isfield(s, fieldname) && ...
        ~isempty(s.(fieldname)) && ...
        numel(s.(fieldname)) >= p
    path_cell = s.(fieldname){p};
end

end

%% =========================================================
% 小工具：把 reach x day cell 转成 1 x nDays double
% =========================================================
function q_ts = get_reach_ts_from_dailycell(path_cell, r)

q_ts = [];

if isempty(path_cell) || ~iscell(path_cell) || size(path_cell, 1) < r
    return;
end

nDays = size(path_cell, 2);
q_ts = nan(1, nDays);

for tt = 1:nDays
    v = path_cell{r, tt};

    if ~isempty(v) && isnumeric(v)
        q_ts(tt) = v;
    end
end

end

%% =========================================================
% 小工具：把产品序列长度匹配到默认产品时间轴
% =========================================================
function qplot = match_ts_length(q, nT)

qplot = [];

if isempty(q) || all(isnan(q))
    return;
end

q = q(:)';

if numel(q) == nT
    qplot = q;

elseif numel(q) == nT + 1
    qplot = q(2:end);

elseif numel(q) > nT
    qplot = q(1:nT);

elseif numel(q) < nT
    qplot = nan(1, nT);
    qplot(1:numel(q)) = q;
end

end

%% =========================================================
% 小工具：按照用户日期范围裁剪产品序列
% =========================================================
function q_sub = subset_by_date(q_all, idx)

q_sub = [];

if isempty(q_all) || all(isnan(q_all))
    return;
end

if numel(q_all) ~= numel(idx)
    return;
end

q_sub = q_all(idx);

end