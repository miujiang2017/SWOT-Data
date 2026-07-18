function out = obs_percent_Qprior(basins, use_svs)
% out = obs_percent_Qprior(basins, use_svs)
%
% For Qprior-based observation uncertainty:
%   sigma_obs = percent * Qprior(reach)
%
% This function estimates percent as robust random observation noise:
%   diff_q   = Q_product - Q_ref
%   e_random = diff_q - median(diff_q)
%   sigma_i  = median(abs(e_random))
%   gamma_i  = sigma_i / Qprior(reach)
%
% It reports robust global percent values for each product and also low/mid/high
% Qprior groups split by the 15th and 85th percentiles. The percent is then
% used as sigma_obs = percent * Qprior(reach).
%
% use_svs:
%   false -> use USGS/WSC/MEFCCWP
%   true  -> use Q_SVS

if nargin < 2
    use_svs = true;
end

q_fields = {'Q_MOMMA','Q_SIC4DVar','Q_geoBAM','Q_SADS','Q_MetroMan'};

if use_svs
    gauge_fields = {'Q_SVS'};
else
    gauge_fields = {'USGS','WSC','MEFCCWP'};
end

reference_date = datetime(2000,1,1,0,0,0,'TimeZone','UTC');

min_nmatch = 2;
min_Q = 1e-6;
group_names = {'low','mid','high'};

out = struct();

for iq = 1:numel(q_fields)
    fld = q_fields{iq};

    gamma_all = [];
    qprior_all = [];
    nmatch_all = [];

    for ib = 1:numel(basins)
        if ~isfield(basins(ib), fld) || isempty(basins(ib).(fld))
            continue;
        end
        if ~isfield(basins(ib), 'mean_q_intpl') || isempty(basins(ib).mean_q_intpl)
            continue;
        end

        q_paths = basins(ib).(fld);
        if ~iscell(q_paths)
            continue;
        end

        for p = 1:numel(q_paths)
            path_reaches = q_paths{p};
            if isempty(path_reaches) || ~iscell(path_reaches)
                continue;
            end
            if numel(basins(ib).mean_q_intpl) < p || isempty(basins(ib).mean_q_intpl{p})
                continue;
            end

            Qprior_path = basins(ib).mean_q_intpl{p};
            if ~isnumeric(Qprior_path)
                continue;
            end
            Qprior_path = Qprior_path(:,1);

            nR = min(numel(path_reaches), numel(Qprior_path));

            for r = 1:nR
                Qprior_r = Qprior_path(r);
                if ~isfinite(Qprior_r) || Qprior_r <= 0
                    continue;
                end

                ts = path_reaches{r};
                if isempty(ts) || ~isnumeric(ts) || size(ts,2) < 2
                    continue;
                end

                [u_day, q_day] = product_to_daily(ts, reference_date);
                if isempty(q_day)
                    continue;
                end

                series_dnQ_list = collect_reference_series(basins(ib), gauge_fields, p, r);
                if isempty(series_dnQ_list)
                    continue;
                end

                dnq_g = merge_gauges_to_daily_full(series_dnQ_list);
                if isempty(dnq_g)
                    continue;
                end

                dn_g = dnq_g(:,1);
                q_g  = dnq_g(:,2);
                okg = isfinite(dn_g) & isfinite(q_g);
                dn_g = dn_g(okg);
                q_g = q_g(okg);

                if numel(q_g) < min_nmatch
                    continue;
                end

                [dn_common, ia, ibb] = intersect(u_day, dn_g); %#ok<ASGLU>
                if numel(dn_common) < min_nmatch
                    continue;
                end

                q_obs_m = q_day(ia);
                q_ref_m = q_g(ibb);
                okm = isfinite(q_obs_m) & isfinite(q_ref_m);
                q_obs_m = q_obs_m(okm);
                q_ref_m = q_ref_m(okm);

                if numel(q_ref_m) < min_nmatch
                    continue;
                end

                diff_q = q_obs_m - q_ref_m;
                diff_q = diff_q(isfinite(diff_q));
                if numel(diff_q) < min_nmatch
                    continue;
                end

                bias_q = median(diff_q, 'omitnan');
                e_random = diff_q - bias_q;
                sigma_i = median(abs(e_random), 'omitnan');
                denom = max(abs(Qprior_r), min_Q);
                gamma_i = sigma_i ./ denom;

                if ~isfinite(gamma_i) || isnan(gamma_i)
                    continue;
                end

                gamma_all = [gamma_all; gamma_i]; %#ok<AGROW>
                qprior_all = [qprior_all; Qprior_r]; %#ok<AGROW>
                nmatch_all = [nmatch_all; numel(q_ref_m)]; %#ok<AGROW>
            end
        end
    end

    out.(fld).gamma_all = gamma_all;
    out.(fld).Qprior_all = qprior_all;
    out.(fld).n_obs_used = numel(gamma_all);
    out.(fld).n_reach_product_matches = numel(nmatch_all);
    out.(fld).recommended_percent = median(gamma_all, 'omitnan');
    out.(fld).median_percent = median(gamma_all, 'omitnan');
    out.(fld).mean_percent = mean(gamma_all, 'omitnan');
    out.(fld).p50 = local_prctile(gamma_all, 50);
    out.(fld).p68 = local_prctile(gamma_all, 68);
    out.(fld).p75 = local_prctile(gamma_all, 75);
    out.(fld).p90 = local_prctile(gamma_all, 90);

    out.(fld).group = struct();
    if ~isempty(gamma_all)
        q_edges = quantile(qprior_all, [0.15 0.85]);
        group_id = nan(size(qprior_all));
        group_id(qprior_all <= q_edges(1)) = 1;
        group_id(qprior_all > q_edges(1) & qprior_all <= q_edges(2)) = 2;
        group_id(qprior_all > q_edges(2)) = 3;

        out.(fld).Qprior_group_edges = q_edges;

        for ig = 1:3
            gname = group_names{ig};
            vals = gamma_all(group_id == ig);
            out.(fld).group.(gname).gamma_all = vals;
            out.(fld).group.(gname).n_obs_used = numel(vals);
            out.(fld).group.(gname).recommended_percent = median(vals, 'omitnan');
            out.(fld).group.(gname).median_percent = median(vals, 'omitnan');
            out.(fld).group.(gname).mean_percent = mean(vals, 'omitnan');
            out.(fld).group.(gname).p50 = local_prctile(vals, 50);
            out.(fld).group.(gname).p68 = local_prctile(vals, 68);
            out.(fld).group.(gname).p75 = local_prctile(vals, 75);
            out.(fld).group.(gname).p90 = local_prctile(vals, 90);
        end
    else
        out.(fld).Qprior_group_edges = [NaN NaN];
        for ig = 1:3
            gname = group_names{ig};
            out.(fld).group.(gname).gamma_all = [];
            out.(fld).group.(gname).n_obs_used = 0;
            out.(fld).group.(gname).recommended_percent = NaN;
            out.(fld).group.(gname).median_percent = NaN;
            out.(fld).group.(gname).mean_percent = NaN;
            out.(fld).group.(gname).p50 = NaN;
            out.(fld).group.(gname).p68 = NaN;
            out.(fld).group.(gname).p75 = NaN;
            out.(fld).group.(gname).p90 = NaN;
        end
    end
end

summary_rows = {};
for iq = 1:numel(q_fields)
    fld = q_fields{iq};
    S = out.(fld);
    edge1 = NaN;
    edge2 = NaN;
    if isfield(S, 'Qprior_group_edges') && numel(S.Qprior_group_edges) >= 2
        edge1 = S.Qprior_group_edges(1);
        edge2 = S.Qprior_group_edges(2);
    end
    summary_rows(end+1,:) = {fld, "all", S.n_obs_used, S.recommended_percent, ...
        S.median_percent, S.mean_percent, S.p75, S.p90, edge1, edge2}; %#ok<AGROW>
    for ig = 1:3
        gname = group_names{ig};
        G = S.group.(gname);
        summary_rows(end+1,:) = {fld, string(gname), G.n_obs_used, ...
            G.recommended_percent, G.median_percent, G.mean_percent, G.p75, G.p90, edge1, edge2}; %#ok<AGROW>
    end
end

out.summary = cell2table(summary_rows, 'VariableNames', { ...
    'product', 'Qprior_group', 'n_obs_used', 'recommended_percent_median', ...
    'median_percent', 'mean_percent', 'p75', 'p90', ...
    'Qprior_low_mid_threshold', 'Qprior_mid_high_threshold'});

disp(out.summary);

end


function [u_day, q_day] = product_to_daily(ts, reference_date)

u_day = [];
q_day = [];

time_sec = ts(:,1);
q_val = ts(:,2);
ok = isfinite(time_sec) & isfinite(q_val);
time_sec = time_sec(ok);
q_val = q_val(ok);

if isempty(q_val)
    return;
end

dates = reference_date + seconds(time_sec);
dn_day = floor(datenum(dates));
[u_day, ~, ic] = unique(dn_day);
q_day = accumarray(ic, q_val, [], @mean);

end


function series_dnQ_list = collect_reference_series(basin, gauge_fields, p, r)

series_dnQ_list = {};

for gfi = 1:numel(gauge_fields)
    gf = gauge_fields{gfi};
    if ~isfield(basin, gf) || isempty(basin.(gf))
        continue;
    end

    gf_paths = basin.(gf);
    if ~iscell(gf_paths) || numel(gf_paths) < p || isempty(gf_paths{p})
        continue;
    end

    reach_cells = gf_paths{p};
    if ~iscell(reach_cells) || numel(reach_cells) < r || isempty(reach_cells{r})
        continue;
    end

    entry = reach_cells{r};
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

end


function dnq_merged = merge_gauges_to_daily_full(series_dnQ_list)

all_dn = [];
all_Q  = [];

for i = 1:numel(series_dnQ_list)
    dn = series_dnQ_list{i}(:,1);
    Q  = series_dnQ_list{i}(:,2);

    ok = isfinite(dn) & isfinite(Q);
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


function v = local_prctile(x, p)

x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = prctile(x, p);
end

end
