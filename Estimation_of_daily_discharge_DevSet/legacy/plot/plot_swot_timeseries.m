function plot_swot_timeseries(data_KF_out, start_date)
% PLOT_SWOT_TIMESERIES
% 为每个 basin / path / reach 画 SWOT discharge 五个产品 + SVS gauge 的时间序列
%
% 同时额外画两个图：
%   Panel (b): product - gauge error time series
%   Panel (c): empirical uncertainty decomposition
%
% 只有当同一个 reach 同时拥有五个产品，并且有 SVS_Q/gaugeQ 时才画三张图：
%   1) hydrograph
%   2) product-gauge error time series
%   3) empirical uncertainty decomposition
%
% 调用方式：
%   plot_swot_timeseries(data_KF_out, '2024-01-01')

fontSize = 15;

prod_fields = {'Q_MOMMA','Q_SIC4DVar','Q_geoBAM','Q_SADS','Q_MetroMan'};
prod_names  = {'MOMMA','SIC4DVar','neoBAM','SAD','MetroMan'};

nProd = numel(prod_fields);

for ib = 283%:numel(data_KF_out)

    % ---- 找这个 basin 最大 path 数 ----
    nPath = 0;

    for k = 1:nProd
        f = prod_fields{k};

        if isfield(data_KF_out(ib), f) && ~isempty(data_KF_out(ib).(f))
            nPath = max(nPath, numel(data_KF_out(ib).(f)));
        end
    end

    if nPath == 0
        continue;
    end

    for p = 1:nPath

        % ---- 从任意存在产品中推断 nR / nDays ----
        [nR, nDays, ok] = infer_size_from_any_product(data_KF_out(ib), prod_fields, p);

        if ~ok
            continue;
        end

        % ---- 使用 datetime 时间轴 ----
        time_vec = datetime(start_date, 'InputFormat', 'yyyy-MM-dd') + days(0:nDays-1);

        % ---- 对应 datenum 时间轴，用于和 gauge 对齐 ----
        time_dn = datenum(time_vec);

        % ---- Gauge path ----
        Gauge_path = [];
        if isfield(data_KF_out(ib), 'SVS_Q') && ...
                ~isempty(data_KF_out(ib).SVS_Q) && ...
                numel(data_KF_out(ib).SVS_Q) >= p
            Gauge_path = data_KF_out(ib).SVS_Q{p};
        end

        for r = 1:nR

            series_list = cell(1, nProd);
            name_list   = cell(1, nProd);

            has_all_products = true;

            % =====================================================
            % 读取 gauge / SVS_Q
            % =====================================================
            [Qg_dn, Qg_val] = get_gauge_ts_from_SVS(Gauge_path, r);

            hasGauge = ~isempty(Qg_dn) && ~isempty(Qg_val) && ...
                       nnz(~isnan(Qg_dn) & ~isnan(Qg_val)) >= 2;

            if ~hasGauge
                continue;
            end

            % ---- 把 gauge 插值到 daily SWOT 时间轴 ----
            Qg_daily = interp_gauge_to_daily(Qg_dn, Qg_val, time_dn);

            if isempty(Qg_daily) || all(isnan(Qg_daily))
                continue;
            end

            % =====================================================
            % 检查并收集五个产品
            % =====================================================
            for k = 1:nProd

                f = prod_fields{k};
                path_cell = get_field_if_exists(data_KF_out(ib), f, p);

                % 如果这个产品不存在，或者 path 不存在，直接不画
                if isempty(path_cell) || ~iscell(path_cell)
                    has_all_products = false;
                    break;
                end

                % 如果这个产品没有这个 reach，直接不画
                if size(path_cell, 1) < r
                    has_all_products = false;
                    break;
                end

                q_ts = get_reach_ts_from_dailycell(path_cell, r, nDays);

                % 如果这个产品在该 reach 全是 NaN，也不画
                if isempty(q_ts) || all(isnan(q_ts))
                    has_all_products = false;
                    break;
                end

                series_list{k} = q_ts;
                name_list{k}   = prod_names{k};

            end

            % ---- 只有五个产品和 gauge 都有效时才画 ----
            if ~has_all_products
                continue;
            end

            % =====================================================
            % Figure 1: 保留原来的 hydrograph 图，加上 SVS_Q / gaugeQ
            % =====================================================
            figure('Name', sprintf('Hydrograph | ib=%d, path=%d, reach=%d', ib, p, r), ...
                   'Position', [120, 120, 1200, 520]);
            hold on;

            hProd = gobjects(1, nProd);
            % ---- gauge / SVS_Q 黑线 ----
            hGauge = plot(datetime(Qg_dn, 'ConvertFrom', 'datenum'), Qg_val, 'k-', ...
                'LineWidth', 2.0);
            for kk = 1:nProd

                q_ts = series_list{kk};
                idx  = ~isnan(q_ts);

                % 只连接有效点，不让 NaN 断线
                if nnz(idx) >= 2

                    hProd(kk) = plot(time_vec(idx), q_ts(idx), 'o-', ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 5);

                elseif nnz(idx) == 1

                    hProd(kk) = plot(time_vec(idx), q_ts(idx), 'o', ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 5);

                end

            end



            % ---- x 轴时间格式：每 2 个月显示一次 ----
            xlim([time_vec(1), time_vec(end)]);

            tick_start = dateshift(time_vec(1), 'start', 'month');
            tick_end   = dateshift(time_vec(end), 'start', 'month');

            xticks(tick_start:calmonths(2):tick_end);
            xtickformat('yyyy-MM');
            xtickangle(45);

            xlabel('Time');
            ylabel('Discharge [m^3/s]');
            title(sprintf('SWOT discharge products and gauge | ib=%d, path=%d, reach=%d', ib, p, r));

            legend([hProd, hGauge], [name_list, {'SVS/Gauge'}], ...
                'Location', 'best');

            grid on;
            box on;
            set(gca, 'FontSize', fontSize+3);

            % =====================================================
            % Figure 2: Panel (b) Product-gauge error time series
            % =====================================================
            figure('Name', sprintf('Panel b error | ib=%d, path=%d, reach=%d', ib, p, r), ...
                   'Position', [160, 160, 1200, 520]);
            hold on;

            hErr = gobjects(1, nProd);

            for kk = 1:nProd

                q_ts = series_list{kk};

                % product 有效，并且 gauge daily 也有效的位置
                idx = ~isnan(q_ts) & ~isnan(Qg_daily);

                if nnz(idx) >= 2

                    err_ts = q_ts(idx) - Qg_daily(idx);

                    hErr(kk) = plot(time_vec(idx), err_ts, 'o-', ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 5);

                elseif nnz(idx) == 1

                    err_ts = q_ts(idx) - Qg_daily(idx);

                    hErr(kk) = plot(time_vec(idx), err_ts, 'o', ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 5);

                end
            end

            yline(0, 'k--', 'LineWidth', 1.2);

            xlim([time_vec(1), time_vec(end)]);

            xticks(tick_start:calmonths(2):tick_end);
            xtickformat('yyyy-MM');
            xtickangle(45);

            xlabel('Time');
            ylabel('Q_{product} - Q_{gauge} [m^3/s]');


            legend(hErr, name_list, 'Location', 'best');

            grid on;
            box on;
            set(gca, 'FontSize', fontSize);
            title(sprintf('(a) Error time series | ib=%d, path=%d, reach=%d', ib, p, r));
            set(gca, 'FontSize', fontSize+3 );
            
            % =====================================================
            % Figure 3: Panel (c) Empirical uncertainty decomposition
            % =====================================================
            bias_rel  = nan(1, nProd);
            rand_rel  = nan(1, nProd);
            total_rel = nan(1, nProd);

            for kk = 1:nProd

                q_ts = series_list{kk};

                idx = ~isnan(q_ts) & ~isnan(Qg_daily);

                if nnz(idx) < 2
                    continue;
                end

                err = q_ts(idx) - Qg_daily(idx);

                Qg_mean = mean(Qg_daily(idx), 'omitnan');

                if isempty(Qg_mean) || isnan(Qg_mean) || Qg_mean == 0
                    continue;
                end

                % systematic bias
                b_i = mean(err, 'omitnan');

                % residual variability after removing bias
                sigma_rand = std(err - b_i, 'omitnan');

                % total empirical uncertainty, equivalent to RMSE of product-gauge error
                sigma_tot = sqrt(mean(err.^2, 'omitnan'));

                % normalized by mean gauge discharge
                bias_rel(kk)  = abs(b_i) / Qg_mean;
                rand_rel(kk)  = sigma_rand / Qg_mean;
                total_rel(kk) = sigma_tot / Qg_mean;

            end

            Y = [bias_rel(:), rand_rel(:), total_rel(:)] * 100;

            figure('Name', sprintf('Panel c uncertainty | ib=%d, path=%d, reach=%d', ib, p, r), ...
                   'Position', [200, 200, 1000, 520]);

            bar(Y, 'grouped');

            set(gca, 'XTick', 1:nProd, ...
                     'XTickLabel', prod_names, ...
                     'FontSize', fontSize+3);

            ylabel('Relative value [% of mean gauge discharge]');
            title(sprintf('(b) Empirical uncertainty decomposition', ib, p, r));

            legend({'s_b / mean(Q_{gauge})', ...
                    '\sigma_{rand} / mean(Q_{gauge})', ...
                    '\sigma_{tot} / mean(Q_{gauge})'}, ...
                    'Location', 'best');

            grid on;
            box on;

        end
    end
end

end

%% ===== 安全读取字段 =====
function path_cell = get_field_if_exists(s, fieldname, p)

path_cell = [];

if isfield(s, fieldname) && ~isempty(s.(fieldname)) && numel(s.(fieldname)) >= p
    path_cell = s.(fieldname){p};
end

end

%% ===== 从任意存在产品推断尺寸 =====
function [nR, nDays, ok] = infer_size_from_any_product(s, prod_fields, p)

nR = 0;
nDays = 0;
ok = false;

for k = 1:numel(prod_fields)

    f = prod_fields{k};

    if isfield(s, f) && ~isempty(s.(f)) && numel(s.(f)) >= p

        pc = s.(f){p};

        if ~isempty(pc) && iscell(pc)
            [nR, nDays] = size(pc);
            ok = true;
            return;
        end

    end

end

end

%% ===== cell → 时间序列 =====
function q_ts = get_reach_ts_from_dailycell(path_cell, r, nDays_ref)

q_ts = [];

if isempty(path_cell) || ~iscell(path_cell) || size(path_cell, 1) < r
    return;
end

nDays = size(path_cell, 2);
nUse  = min(nDays, nDays_ref);

q_ts = nan(1, nDays_ref);
row = path_cell(r, :);

for tt = 1:nUse

    v = row{tt};

    if ~isempty(v) && isnumeric(v)

        if isscalar(v)
            q_ts(tt) = v;
        else
            q_ts(tt) = v(1);
        end

    end

end

end

%% ===== 读取 SVS_Q / gaugeQ =====
function [Qg_dn, Qg_val] = get_gauge_ts_from_SVS(Gauge_path, r)

Qg_dn  = [];
Qg_val = [];

if isempty(Gauge_path) || ~iscell(Gauge_path) || numel(Gauge_path) < r
    return;
end

if isempty(Gauge_path{r})
    return;
end

gauge_data = Gauge_path{r};

if isnumeric(gauge_data) && size(gauge_data, 2) >= 2

    Qg_dn  = gauge_data(:, 1);
    Qg_val = gauge_data(:, 2);

    idx = ~isnan(Qg_dn) & ~isnan(Qg_val);

    Qg_dn  = Qg_dn(idx);
    Qg_val = Qg_val(idx);

end

end

%% ===== gauge 插值到 daily time axis =====
function Qg_daily = interp_gauge_to_daily(Qg_dn, Qg_val, time_dn)

Qg_daily = nan(size(time_dn));

if isempty(Qg_dn) || isempty(Qg_val)
    return;
end

idx = ~isnan(Qg_dn) & ~isnan(Qg_val);

Qg_dn  = Qg_dn(idx);
Qg_val = Qg_val(idx);

if numel(Qg_dn) < 2
    return;
end

% ---- 防止重复日期导致 interp1 报错 ----
[Qg_dn_u, ~, ic] = unique(Qg_dn);
Qg_val_u = accumarray(ic, Qg_val, [], @mean);

if numel(Qg_dn_u) < 2
    return;
end

% ---- 不外推；超出 gauge 时间范围的地方保持 NaN ----
Qg_daily = interp1(Qg_dn_u, Qg_val_u, time_dn, 'linear', NaN);

end