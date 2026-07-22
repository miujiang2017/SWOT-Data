function out = obs_percent(basins, use_svs)
% out = obs_percent(basins)
%
% 对每个产品(Q_*)，在与 gauge 的共同日期上计算 residual：
%   r_obs  = Q_prod - mean(Q_prod)
%   r_true = Q_g    - mean(Q_g)
%   eps    = r_obs - r_true
%
% reach 级相对误差指标（你当前用法）：
%   gamma_i = median( abs(eps) ./ Q_true )
% 并对所有有 gauge 的 reach 汇总：
%   gamma_median / gamma_mean / gamma_all / n_reach_used
%
% 说明：
% - 不做时间截断；
% - 产品按天聚合(同一天取均值)；
% - gauge 合并后按天聚合，再在自身(min~max)范围内逐日线性插值（两端不外推）；
% - 为避免除零/极小流量爆炸：分母使用 max(Q_true, min_Q)
%
% 支持产品字段：
%   Q_MOMMA, Q_SIC4DVar, Q_geoBAM, Q_SADS, Q_MetroMan
%
% gauge 字段（按你的数据结构）：
%   USGS, WSC, MEFCCWP or Q_SVS
% use_svs:
%   false -> 使用 USGS/WSC/MEFCCWP
%   true  -> 使用 Q_SVS

if nargin < 2
    use_svs = false;
end

q_fields = {'Q_MOMMA','Q_SIC4DVar','Q_geoBAM','Q_SADS','Q_MetroMan'};

if use_svs
    gauge_fields = {'Q_SVS'};
else
    gauge_fields = {'USGS','WSC','MEFCCWP'};
end

reference_date = datetime(2000,1,1,0,0,0,'TimeZone','UTC');

% 参数
min_nmatch = 2;      % 最少共同天数
min_Q      = 1e-6;   % 分母下限（m3/s 量级按你习惯自己调）

out = struct();

for iq = 1:numel(q_fields)
    fld = q_fields{iq};
    gamma_list = []; % 每个 reach 的 gamma_i

    for ib = 1:numel(basins)
        if ~isfield(basins(ib), fld) || isempty(basins(ib).(fld))
            continue;
        end

        q_paths = basins(ib).(fld);
        if ~iscell(q_paths), continue; end

        for p = 1:numel(q_paths)
            path_reaches = q_paths{p};
            if isempty(path_reaches) || ~iscell(path_reaches), continue; end

            nR = numel(path_reaches);

            for r = 1:nR
                ts = path_reaches{r};
                if isempty(ts) || ~isnumeric(ts) || size(ts,2) < 2
                    continue;
                end

                %% ---- 1) 产品 Q：按天聚合 ----
                time_sec = ts(:,1);
                q_val    = ts(:,2);

                ok = isfinite(time_sec) & isfinite(q_val) & ~isnan(q_val);
                time_sec = time_sec(ok);
                q_val    = q_val(ok);
                if isempty(q_val)
                    continue;
                end

                dates  = reference_date + seconds(time_sec);
                dn_day = floor(datenum(dates));     % 产品日序号（datenum 的 day）
                [u_day, ~, ic] = unique(dn_day);
                q_day = accumarray(ic, q_val, [], @mean);

                %% ---- 2) gauge：收集(可能多个来源/多个 cell)，合并->逐日插值 ----
                series_dnQ_list = {};

                for gfi = 1:numel(gauge_fields)
                    gf = gauge_fields{gfi};
                    if ~isfield(basins(ib), gf) || isempty(basins(ib).(gf))
                        continue;
                    end

                    gf_paths = basins(ib).(gf);
                    if ~iscell(gf_paths) || numel(gf_paths) < p || isempty(gf_paths{p})
                        continue;
                    end

                    reach_cells = gf_paths{p};
                    if ~iscell(reach_cells) || numel(reach_cells) < r || isempty(reach_cells{r})
                        continue;
                    end

                    entry = reach_cells{r};

                    % entry 可能是 Nx2 数组，也可能是 {Nx2, Nx2, ...}
                    if isnumeric(entry) && size(entry,2) >= 2
                        series_dnQ_list{end+1} = entry(:,1:2); %#ok<AGROW>
                    elseif iscell(entry)
                        for cc = 1:numel(entry)
                            if ~isempty(entry{cc}) && isnumeric(entry{cc}) && size(entry{cc},2) >= 2
                                series_dnQ_list{end+1} = entry{cc}(:,1:2); %#ok<AGROW>
                            end
                        end
                    end
                end

                if isempty(series_dnQ_list)
                    continue;
                end

                dnq_g = merge_gauges_to_daily_full(series_dnQ_list);
                if isempty(dnq_g)
                    continue;
                end

                dn_g = dnq_g(:,1);
                q_g  = dnq_g(:,2);

                okg = isfinite(dn_g) & isfinite(q_g) & ~isnan(q_g);
                dn_g = dn_g(okg);
                q_g  = q_g(okg);

                if numel(q_g) < 2
                    continue;
                end

                %% ---- 3) 匹配共同日期 ----
                [dn_common, ia, ibb] = intersect(u_day, dn_g); %#ok<ASGLU>
                if numel(dn_common) < min_nmatch
                    continue;
                end

                q_obs_m  = q_day(ia);
                q_true_m = q_g(ibb);

                okm = isfinite(q_obs_m) & isfinite(q_true_m) & ~isnan(q_obs_m) & ~isnan(q_true_m);
                q_obs_m  = q_obs_m(okm);
                q_true_m = q_true_m(okm);

                if numel(q_true_m) < min_nmatch
                    continue;
                end

                %% ---- 4) residual eps ----
                r_obs  = q_obs_m  - mean(q_obs_m,  'omitnan');
                r_true = q_true_m - mean(q_true_m, 'omitnan');
                eps    = r_obs - r_true;

                %% ---- 5) gamma_i：median(|eps|/Q_true)，分母做下限 ----
                denom = max(q_true_m, min_Q);
                gamma_i = median(abs(eps) ./ (abs(q_obs_m)), 'omitnan');

                if isfinite(gamma_i) && ~isnan(gamma_i)
                    gamma_list(end+1,1) = gamma_i; %#ok<AGROW>
                end
            end
        end
    end

    out.(fld).gamma_all      = gamma_list;
    out.(fld).n_reach_used   = numel(gamma_list);

    if isempty(gamma_list)
        out.(fld).gamma_median         = NaN;
        out.(fld).gamma_mean           = NaN;
        out.(fld).gamma_median_percent = NaN;
        out.(fld).gamma_mean_percent   = NaN;
    else
        out.(fld).gamma_median         = median(gamma_list, 'omitnan');
        out.(fld).gamma_mean           = mean(gamma_list, 'omitnan');
        out.(fld).gamma_median_percent = 100 * out.(fld).gamma_median;
        out.(fld).gamma_mean_percent   = 100 * out.(fld).gamma_mean;
    end
end
end


function dnq_merged = merge_gauges_to_daily_full(series_dnQ_list)
% 合并多个 gauge 序列 -> 按天平均 -> 在自身(min~max)范围逐日线性插值（两端不外推）
all_dn = [];
all_Q  = [];

for i = 1:numel(series_dnQ_list)
    dn = series_dnQ_list{i}(:,1);
    Q  = series_dnQ_list{i}(:,2);

    ok = isfinite(dn) & isfinite(Q) & ~isnan(dn) & ~isnan(Q);
    dn = dn(ok);
    Q  = Q(ok);

    all_dn = [all_dn; dn]; %#ok<AGROW>
    all_Q  = [all_Q;  Q ]; %#ok<AGROW>
end

if isempty(all_dn)
    dnq_merged = [];
    return;
end

dn_day = floor(all_dn);
[u_day, ~, ic] = unique(dn_day);
Q_day = accumarray(ic, all_Q, [], @mean);

d1 = min(u_day);
d2 = max(u_day);
grid_dn = (d1:d2)';

daily = nan(numel(grid_dn),1);
idx = u_day - d1 + 1;
daily(idx) = Q_day;

idx_valid = find(~isnan(daily));
if numel(idx_valid) >= 2
    i1 = idx_valid(1);
    i2 = idx_valid(end);
    xq = i1:i2;
    daily(i1:i2) = interp1(idx_valid, daily(idx_valid), xq, 'linear');
end

dnq_merged = [grid_dn, daily];
end