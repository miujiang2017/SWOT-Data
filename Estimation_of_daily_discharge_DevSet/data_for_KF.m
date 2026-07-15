function data_KF = data_for_KF(basins, start_date, end_date, state_ep)
% data_KF = data_for_KF(basins, start_date, end_date, state_ep)
%
% 处理内容：
%   1) Q_MOMMA / Q_SIC4DVar / Q_geoBAM / Q_SADS / Q_MetroMan
%      - basins(ib).Q_*(p){reach} = K×2 double [time_sec, Q]
%      - 输出:
%          data_KF(ib).Q_*(p)           : n_reach×n_days cell
%          data_KF(ib).mean_*(p)        : n_reach×1 cell
%          data_KF(ib).day_index_*(p)   : n_reach×1 cell
%
%   2) RiverSP_ReachData（time / wse / width / slope / dA / dA_unc）
%
%   3) Gauge：USGS / WSC / MEFCCWP
%      - 输出:
%          data_KF(ib).Gauge_Q{p}{r} = N×2 double [datenum, Q]
%
%   4) SVS：Q_SVS
%      - 单独输出:
%          data_KF(ib).SVS_Q{p}{r} = N×2 double [datenum, Q]
%
%   5) data_KF(ib).paths = basins(ib).paths
%   6) 利用 Gauge_Q + position 生成 start_value

%% 日期转换
start_dn = datenum(start_date);
end_dn   = datenum(end_date);
n_days   = end_dn - start_dn + 1;

% Q 产品和 RiverSP 的 time 是 seconds since 2000-01-01
reference_date = datetime(2000,1,1,0,0,0,'TimeZone','UTC');

%% Q 产品字段
q_fields = { ...
    'Q_MOMMA', ...
    'Q_SIC4DVar', ...
    'Q_geoBAM', ...
    'Q_SADS', ...
    'Q_MetroMan'};

day_fields = { ...
    'day_index_MOMMA', ...
    'day_index_SIC4DVar', ...
    'day_index_geoBAM', ...
    'day_index_SADS', ...
    'day_index_MetroMan'};

mean_fields = { ...
    'mean_MOMMA', ...
    'mean_SIC4DVar', ...
    'mean_geoBAM', ...
    'mean_SADS', ...
    'mean_MetroMan'};

nB = numel(basins);
data_KF = struct([]);

for ib = 1:nB

    %% ---------- 基本信息 ----------
    data_KF(ib).rch_len    = basins(ib).length;
    data_KF(ib).basin_id   = basins(ib).basin_id;
    data_KF(ib).center_pos = basins(ib).position;
    data_KF(ib).w_sword    = basins(ib).width_sword;
    data_KF(ib).s_sword    = basins(ib).slope_sword;
    data_KF(ib).s_IRIS     = basins(ib).slope_IRIS;
    data_KF(ib).Q_prior    = basins(ib).mean_q_intpl;
    data_KF(ib).minQ_prior = basins(ib).min_q_intpl;
    data_KF(ib).maxQ_prior = basins(ib).max_q_intpl;

    if isfield(basins(ib), 'paths') && ~isempty(basins(ib).paths)
        data_KF(ib).paths = basins(ib).paths;
    else
        data_KF(ib).paths = {};
    end

    %% ---------- 1. Q_* 产品 ----------
    for iq = 1:numel(q_fields)

        fld      = q_fields{iq};
        day_fld  = day_fields{iq};
        mean_fld = mean_fields{iq};

        if ~isfield(basins(ib), fld) || isempty(basins(ib).(fld))
            continue;
        end

        q_paths = basins(ib).(fld);
        n_paths = numel(q_paths);

        data_KF(ib).(fld)      = cell(n_paths, 1);
        data_KF(ib).(day_fld)  = cell(n_paths, 1);
        data_KF(ib).(mean_fld) = cell(n_paths, 1);

        for p = 1:n_paths

            path_reaches = q_paths{p};

            if isempty(path_reaches) || ~iscell(path_reaches)
                continue;
            end

            n_reach = numel(path_reaches);

            daily_Q        = cell(n_reach, n_days);
            mean_reach     = cell(n_reach, 1);
            dayindex_reach = cell(n_reach, 1);

            for r = 1:n_reach

                ts = path_reaches{r};

                if isempty(ts) || ~isnumeric(ts) || size(ts,2) < 2
                    continue;
                end

                time_in_seconds = ts(:,1);
                q_value         = ts(:,2);

                dates     = reference_date + seconds(time_in_seconds);
                day_index = floor(datenum(dates)) - start_dn + 1;

                valid = (day_index >= 1) & ...
                        (day_index <= n_days) & ...
                        ~isnan(q_value);

                day_index = day_index(valid);
                q_value   = q_value(valid);

                if isempty(q_value)
                    continue;
                end

                mean_reach{r,1}     = mean(q_value, 'omitnan');
                dayindex_reach{r,1} = unique(day_index(:));

                for k = 1:numel(day_index)
                    d = day_index(k);
                    daily_Q{r, d} = q_value(k);
                end
            end

            data_KF(ib).(fld){p}      = daily_Q;
            data_KF(ib).(mean_fld){p} = mean_reach;
            data_KF(ib).(day_fld){p}  = dayindex_reach;
        end
    end

    %% ---------- 2. RiverSP_ReachData ----------
    if isfield(basins(ib), 'RiverSP_ReachData') && ~isempty(basins(ib).RiverSP_ReachData)

        sp_paths   = basins(ib).RiverSP_ReachData;
        n_paths_sp = numel(sp_paths);

        data_KF(ib).wse_RiverSP    = cell(n_paths_sp,1);
        data_KF(ib).width_RiverSP  = cell(n_paths_sp,1);
        data_KF(ib).slope_RiverSP  = cell(n_paths_sp,1);
        data_KF(ib).dA_RiverSP     = cell(n_paths_sp,1);
        data_KF(ib).dA_unc_RiverSP = cell(n_paths_sp,1);

        for p = 1:n_paths_sp

            path_reaches = sp_paths{p};

            if isempty(path_reaches)
                continue;
            end

            n_reach = numel(path_reaches) / 2;

            wse_daily     = cell(n_reach, n_days);
            width_daily   = cell(n_reach, n_days);
            slope_daily   = cell(n_reach, n_days);
            dA_daily      = cell(n_reach, n_days);
            dA_unc_daily  = cell(n_reach, n_days);

            for r = 1:n_reach

                rd = path_reaches{r,1};

                if ~isfield(rd, 'time')  || isempty(rd.time)  || ...
                   ~isfield(rd, 'wse')   || isempty(rd.wse)   || ...
                   ~isfield(rd, 'wse_u') || isempty(rd.wse_u) || ...
                   ~isfield(rd, 'width') || isempty(rd.width) || ...
                   ~isfield(rd, 'slope') || isempty(rd.slope)
                    continue;
                end

                time_sec = rd.time;
                H        = rd.wse;
                H_unc    = rd.wse_u;
                width    = rd.width;
                slope    = rd.slope;

                mask_valid = (H > -1e10) & ...
                             isfinite(H) & ...
                             isfinite(H_unc) & ...
                             (width > -1e10) & ...
                             (slope > -1e10);

                time_sec = time_sec(mask_valid);
                H        = H(mask_valid);
                H_unc    = H_unc(mask_valid);
                width    = width(mask_valid);
                slope    = slope(mask_valid);

                if isempty(time_sec)
                    continue;
                end

                dates     = reference_date + seconds(time_sec);
                day_index = floor(datenum(dates)) - start_dn + 1;

                mask_ok = (day_index >= 1) & (day_index <= n_days);

                day_index = day_index(mask_ok);
                H         = H(mask_ok);
                H_unc     = H_unc(mask_ok);
                width     = width(mask_ok);
                slope     = slope(mask_ok);

                if isempty(day_index)
                    continue;
                end

                H_med = median(H, 'omitnan');

                for k = 1:numel(day_index)

                    d = day_index(k);

                    Hj  = H(k);
                    Huj = H_unc(k);

                    dA_val = width(k) * (Hj - H_med);

                    dA_unc_val = sqrt(((Hj - H_med) * sqrt(width(k))) + ...
                                      (width(k) * Huj)^2);

                    dA_daily{r, d}     = dA_val;
                    dA_unc_daily{r, d} = dA_unc_val;

                    wse_daily{r, d}    = Hj;
                    width_daily{r, d}  = width(k);
                    slope_daily{r, d}  = slope(k);
                end
            end

            data_KF(ib).wse_RiverSP{p}    = wse_daily;
            data_KF(ib).width_RiverSP{p}  = width_daily;
            data_KF(ib).slope_RiverSP{p}  = slope_daily;
            data_KF(ib).dA_RiverSP{p}     = dA_daily;
            data_KF(ib).dA_unc_RiverSP{p} = dA_unc_daily;
        end
    end

    %% ---------- 3. Gauge：USGS / WSC / MEFCCWP ----------
    gauge_fields = {'USGS','WSC','MEFCCWP'};

    has_any_gauge = false;

    for gfi = 1:numel(gauge_fields)
        if isfield(basins(ib), gauge_fields{gfi}) && ...
                ~isempty(basins(ib).(gauge_fields{gfi}))
            has_any_gauge = true;
            break;
        end
    end

    if has_any_gauge && ...
            isfield(basins(ib), 'position') && ...
            ~isempty(basins(ib).position)

        n_paths_pos = numel(basins(ib).position);
        data_KF(ib).Gauge_Q = cell(n_paths_pos,1);

        for p = 1:n_paths_pos

            pos_p = basins(ib).position{p};

            if isempty(pos_p)
                continue;
            end

            nR = numel(pos_p);

            data_KF(ib).Gauge_Q{p} = cell(nR,1);

            for r = 1:nR

                series_dnQ_list = {};

                for gfi = 1:numel(gauge_fields)

                    fld = gauge_fields{gfi};

                    if ~isfield(basins(ib), fld)
                        continue;
                    end

                    fld_paths = basins(ib).(fld);

                    if numel(fld_paths) < p || isempty(fld_paths{p})
                        continue;
                    end

                    reach_cells = fld_paths{p};

                    if numel(reach_cells) < r || isempty(reach_cells{r})
                        continue;
                    end

                    entry = reach_cells{r};

                    if isnumeric(entry)

                        if size(entry,2) >= 2
                            series_dnQ_list{end+1} = entry(:,1:2); %#ok<AGROW>
                        end

                    elseif iscell(entry)

                        for cc = 1:numel(entry)
                            if ~isempty(entry{cc}) && ...
                                    isnumeric(entry{cc}) && ...
                                    size(entry{cc},2) >= 2
                                series_dnQ_list{end+1} = entry{cc}(:,1:2); %#ok<AGROW>
                            end
                        end
                    end
                end

                if isempty(series_dnQ_list)
                    continue;
                end

                dnq_merged = merge_gauges_to_daily(series_dnQ_list, start_dn, end_dn);

                data_KF(ib).Gauge_Q{p}{r} = dnq_merged;
            end
        end
    end

    %% ---------- 4. SVS：Q_SVS 单独处理，但格式类似 Gauge_Q ----------
    if isfield(basins(ib), 'Q_SVS') && ~isempty(basins(ib).Q_SVS)

        svs_paths = basins(ib).Q_SVS;
        n_paths_svs = numel(svs_paths);

        data_KF(ib).SVS_Q = cell(n_paths_svs, 1);

        for p = 1:n_paths_svs

            path_reaches = svs_paths{p};

            if isempty(path_reaches) || ~iscell(path_reaches)
                continue;
            end

            nR = numel(path_reaches);
            data_KF(ib).SVS_Q{p} = cell(nR, 1);

            for r = 1:nR

                ts = path_reaches{r};

                if isempty(ts) || ~isnumeric(ts) || size(ts,2) < 2
                    continue;
                end

                dn = ts(:,1);
                q  = ts(:,2);

                mask = ~isnan(dn) & ~isnan(q);

                dn = dn(mask);
                q  = q(mask);

                if isempty(dn)
                    continue;
                end

                data_KF(ib).SVS_Q{p}{r} = merge_gauges_to_daily({[dn, q]}, start_dn, end_dn);
            end
        end
    end

    %% ---------- 5. Gauge_Q + position 生成 start_value ----------
    if isfield(basins(ib), 'position') && ...
            ~isempty(basins(ib).position) && ...
            isfield(data_KF(ib), 'Gauge_Q') && ...
            ~isempty(data_KF(ib).Gauge_Q)

        n_paths_pos = numel(basins(ib).position);
        data_KF(ib).start_value = cell(n_paths_pos, 1);

        target_dn = (start_dn : start_dn + state_ep - 1)';

        for p = 1:n_paths_pos

            pos_p = basins(ib).position{p};

            if isempty(pos_p)
                data_KF(ib).start_value{p} = [];
                continue;
            end

            nR = numel(pos_p);

            if numel(data_KF(ib).Gauge_Q) < p || ...
                    isempty(data_KF(ib).Gauge_Q{p})
                data_KF(ib).start_value{p} = [];
                continue;
            end

            Q_mat = nan(nR, state_ep);

            reach_cell_p = data_KF(ib).Gauge_Q{p};

            for r = 1:nR

                if numel(reach_cell_p) < r || isempty(reach_cell_p{r})
                    continue;
                end

                gauge_data = reach_cell_p{r};

                if isempty(gauge_data)
                    continue;
                end

                dn_r    = gauge_data(:,1);
                Q_r_all = gauge_data(:,2);

                [tf, loc] = ismember(target_dn, dn_r);

                if ~any(tf)
                    continue;
                end

                q_r = nan(1, state_ep);
                q_r(tf) = Q_r_all(loc(tf));

                Q_mat(r, :) = q_r;
            end

            Q_interp = Q_mat;

            for tt = 1:state_ep

                col  = Q_mat(:, tt);
                mask = ~isnan(col);

                if sum(mask) >= 2
                    Q_interp(:, tt) = interp1(pos_p(mask), col(mask), pos_p, 'linear', 'extrap');
                elseif sum(mask) == 1
                    Q_interp(:, tt) = col(mask);
                end
            end

            data_KF(ib).start_value{p} = Q_interp;
        end

    else
        data_KF(ib).start_value = {};
    end
end

end


%% ======= 辅助函数：合并多个 gauge/SVS 序列并按天插值 =======
function dnq_merged = merge_gauges_to_daily(series_dnQ_list, start_dn, end_dn)

all_dn = [];
all_Q  = [];

for i = 1:numel(series_dnQ_list)

    dn = series_dnQ_list{i}(:,1);
    Q  = series_dnQ_list{i}(:,2);

    mask = ~isnan(dn) & ~isnan(Q);

    dn = dn(mask);
    Q  = Q(mask);

    all_dn = [all_dn; dn];
    all_Q  = [all_Q;  Q ];
end

grid_dn = (start_dn:end_dn)';
n_days  = numel(grid_dn);

if isempty(all_dn)
    dnq_merged = [grid_dn, nan(n_days,1)];
    return;
end

dn_day = floor(all_dn);

[u_day, ~, ic] = unique(dn_day);
Q_day = accumarray(ic, all_Q, [], @mean);

daily = nan(n_days,1);

mask_win = (u_day >= start_dn) & (u_day <= end_dn);

u_win = u_day(mask_win);
Q_win = Q_day(mask_win);

if ~isempty(u_win)

    idx = u_win - start_dn + 1;
    daily(idx) = Q_win;

    idx_valid = find(~isnan(daily));

    if numel(idx_valid) >= 2

        i1 = idx_valid(1);
        i2 = idx_valid(end);
        xq = i1:i2;

        daily_seg = interp1(idx_valid, daily(idx_valid), xq, 'linear');

        daily(i1:i2) = daily_seg;
    end
end

dnq_merged = [grid_dn, daily];

end