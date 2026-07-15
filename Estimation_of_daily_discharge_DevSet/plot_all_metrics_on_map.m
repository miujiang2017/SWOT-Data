function plot_all_metrics_on_map(data_KF_out, Q_results, file_prefix)
% plot_all_metrics_on_map
% =========================================================
% 画所有 reach 的 4 个指标：corr / NSE / rRMSE / rBias
%
% 特点：
%   1) reach-wise：不做 mean，不做 unique 合并
%   2) 每个 subplot 用分段离散颜色
%   3) 用 tiledlayout 压缩子图间距
%
% 假设：
%   data_KF_out(b).paths{p} 是 m×1 reach_id
%   Q_results(b).vali_estmed{1,p} 是 struct，含 fields:
%       .corr .NSE .rRMSE .rB
%   并且这四个字段长度都等于 m
% =========================================================

% ---------- 1) 洲前缀 ----------
allowedDigits = continent_digits(file_prefix);

% ---------- 2) 读取 nc ----------
ncfile = sprintf('%s_sword_v16.nc', file_prefix);
reach_id_nc = ncread(ncfile, '/reaches/reach_id');
lon         = ncread(ncfile, '/reaches/x');
lat         = ncread(ncfile, '/reaches/y');

reach_id_nc = reach_id_nc(:);
lon = lon(:);
lat = lat(:);

SID_ALL = to11(reach_id_nc);

% ---------- 3) 收集全部 reach-wise metric ----------
all_ids   = [];
all_corr  = [];
all_nse   = [];
all_rrmse = [];
all_rb    = [];

for b = 1:numel(data_KF_out)

    if ~isfield(data_KF_out(b), 'paths') || isempty(data_KF_out(b).paths)
        continue
    end

    P = data_KF_out(b).paths;

    for p = 1:numel(P)

        if isempty(P{p})
            continue
        end

        path_ids = P{p}(:);
        m = numel(path_ids);

        if b > numel(Q_results) || ~isfield(Q_results(b), 'vali_estmed') || isempty(Q_results(b).vali_estmed)
            continue
        end

        try
            S = Q_results(b).vali_estmed{1,p};
        catch
            continue
        end

        if ~isstruct(S) || ~all(isfield(S, {'corr','NSE','rRMSE','rB'}))
            continue
        end

        c  = S.corr(:);
        n  = S.NSE(:);
        r  = S.rRMSE(:);
        b0 = S.rB(:);

        if any([numel(c), numel(n), numel(r), numel(b0)] ~= m)
            fprintf(['Skip b=%d p=%d: metric length not match m ' ...
                     '(m=%d, corr=%d, NSE=%d, rRMSE=%d, rB=%d)\n'], ...
                     b, p, m, numel(c), numel(n), numel(r), numel(b0));
            continue
        end

        all_ids   = [all_ids;   path_ids];
        all_corr  = [all_corr;  c];
        all_nse   = [all_nse;   n];
        all_rrmse = [all_rrmse; r];
        all_rb    = [all_rb;    b0];
    end
end

% ---------- 4) 基础过滤 ----------
ok_id = ~isnan(all_ids) & all_ids > 0;

all_ids   = all_ids(ok_id);
all_corr  = all_corr(ok_id);
all_nse   = all_nse(ok_id);
all_rrmse = all_rrmse(ok_id);
all_rb    = all_rb(ok_id);

if isempty(all_ids)
    warning('No per-reach metrics collected. (Maybe your metrics are empty or indexing mismatch.)');
    return
end

% ---------- 5) reach-wise 对齐 nc，不做平均 ----------
key_all = to11(all_ids);

keep_prefix = false(size(key_all));
for d = allowedDigits
    keep_prefix = keep_prefix | startsWith(key_all, d);
end

[tf_nc, loc_nc] = ismember(key_all, SID_ALL);
keep = keep_prefix & tf_nc;

if ~any(keep)
    warning('After prefix filter, nothing left to plot for %s.', file_prefix);
    return
end

lon_p = lon(loc_nc(keep));
lat_p = lat(loc_nc(keep));

V = struct();
V.corr  = all_corr(keep);
V.NSE   = all_nse(keep);
V.rRMSE = all_rrmse(keep);
V.rB    = all_rb(keep);

% ---------- 6) 统一地图范围 ----------
goodLonLat = ~isnan(lon_p) & ~isnan(lat_p);
lon_use_all = lon_p(goodLonLat);
lat_use_all = lat_p(goodLonLat);

if isempty(lon_use_all) || isempty(lat_use_all)
    warning('No valid lon/lat to plot.');
    return
end

lonLim = [min(lon_use_all)-1, max(lon_use_all)+1];
latLim = [25, 60];   % 你原来的固定纬度范围

% ---------- 7) 画 2×2 ----------
markerSize = 18;
fontSize   = 14;
padDeg     = 1;

fig = figure('Color', 'w', 'Position', [100, 80, 1350, 950]);

% 四张图的位置 [left bottom width height]，单位 normalized
pos1 = [0.06, 0.58, 0.33, 0.32];
pos2 = [0.50, 0.58, 0.33, 0.32];
pos3 = [0.06, 0.17, 0.33, 0.32];
pos4 = [0.50, 0.17, 0.33, 0.32];

plot_one_geoaxes_manual(fig, pos1, "(a). Correlation [-]", lat_p, lon_p, V.corr, markerSize, fontSize, padDeg);
plot_one_geoaxes_manual(fig, pos2, "(b). NSE [-]",         lat_p, lon_p, V.NSE,  markerSize, fontSize, padDeg);
plot_one_geoaxes_manual(fig, pos3, "(c). rRMSE [%]",       lat_p, lon_p, V.rRMSE,markerSize, fontSize, padDeg);
plot_one_geoaxes_manual(fig, pos4, "(d). rBias [%]",       lat_p, lon_p, V.rB,   markerSize, fontSize, padDeg);

end


% =========================================================
% 单张 subplot：离散分段色标
% =========================================================
function plot_one_geoaxes_manual(fig, pos, name, lat_p, lon_p, val, markerSize, fontSize, padDeg)

good = ~isnan(val) & ~isnan(lat_p) & ~isnan(lon_p);
if ~any(good)
    ax = axes(fig, 'Position', pos);
    axis(ax, 'off');
    title(ax, sprintf('%s (no data)', name), ...
        'FontSize', fontSize+4, 'FontWeight', 'bold');
    return
end

% 地图轴位置
axPos = pos;

% 给 colorbar 单独留出右边空间
cbGap = 0.008;
cbW   = 0.012;

axPos(3) = axPos(3) - cbW - cbGap;

ax = geoaxes(fig, 'Position', axPos);
geobasemap(ax, 'streets-light');
hold(ax, 'on');

[edges, tickLabels, cmap] = get_metric_bins_and_colors(name);
nBin = size(cmap, 1);

vg = val(good);
binID = discretize(vg, edges);

binID(vg <= edges(1)) = 1;
binID(vg >= edges(end)) = nBin;

okb = ~isnan(binID);

latg = lat_p(good);
long = lon_p(good);

latg  = latg(okb);
long  = long(okb);
binID = binID(okb);

geoscatter(ax, latg, long, markerSize, double(binID), ...
    'filled', 'MarkerEdgeColor', 'none');

colormap(ax, cmap);
caxis(ax, [0.5, nBin + 0.5]);

title(ax, char(name), 'FontSize', fontSize+5, 'FontWeight', 'bold');

ax.LatitudeLabel.String  = '';
ax.LongitudeLabel.String = '';

geolimits(ax, [20, 75], [min(long)-padDeg, max(long)+padDeg]);

% 单独放 colorbar，避免挤地图
cb = colorbar(ax);
cb.FontSize = fontSize - 1;
cb.Ticks = 1:nBin;
cb.TickLabels = tickLabels;
cb.Label.FontSize = fontSize;

cb.Position = [
    axPos(1) + axPos(3) + cbGap, ...
    axPos(2), ...
    cbW, ...
    axPos(4)
];
set(gca,'FontSize',fontSize);
end


% =========================================================
% 每个 metric 的分段 + 配色
% =========================================================
function [edges, tickLabels, cmap] = get_metric_bins_and_colors(name)

cmap = [
    0.15 0.15 0.15   % black
    0.27 0.35 0.83   % blue
    0.18 0.72 0.92   % cyan
    0.20 0.78 0.22   % green
    0.74 0.86 0.12   % yellow-green
    0.98 0.66 0.12   % orange
    0.95 0.10 0.10   % red
];

switch string(name)

    case "(a). Correlation [-]"
        edges = [-Inf, -0.4, -0.2, 0, 0.2, 0.4, 0.6, Inf];
        tickLabels = {'< -0.4', '[-0.4,-0.2)', '[-0.2,0)', '[0,0.2)', ...
                      '[0.2,0.4)', '[0.4,0.6)', '≥ 0.6'};

    case "(b). NSE [-]"
        edges = [-Inf, -1.6, -1.2, -0.8, -0.4, 0, 0.4, Inf];
        tickLabels = {'< -1.6', '[-1.6,-1.2)', '[-1.2,-0.8)', '[-0.8,-0.4)', ...
                      '[-0.4,0)', '[0,0.4)', '≥ 0.4'};

    case "(c). rRMSE [%]"
        edges = [-Inf, 50, 100, 150, 200, 250, 300, Inf];
        tickLabels = {'< 50', '[50,100)', '[100,150)', '[150,200)', ...
                      '[200,250)', '[250,300)', '≥ 300'};

    case "(d). rBias [%]"
        edges = [-Inf, 50, 100, 150, 200, 250, 300, Inf];
        tickLabels = {'< 50', '[50,100)', '[100,150)', '[150,200)', ...
                      '[200,250)', '[250,300)', '≥ 300'};

    otherwise
        edges = [-Inf, 0, 1, 2, 3, 4, 5, Inf];
        tickLabels = {'1','2','3','4','5','6','7'};
        unit = '[-]';
end

end


% =========================================================
% helpers
% =========================================================
function digits = continent_digits(prefix)
switch lower(string(prefix))
    case "af"
        digits = ["1"];
    case "eu"
        digits = ["2"];
    case "as"
        digits = ["3","4"];
    case "na"
        digits = ["7","8","9"];
    case "oc"
        digits = ["5"];
    case "sa"
        digits = ["6"];
    otherwise
        error('未知 file_prefix: %s', string(prefix));
end
end

function s = to11(ids)
s = string(ids(:));
s = strip(replace(s, '"', ''));
bad = (s == "" | lower(s) == "nan");
s(bad) = [];
s = arrayfun(@(x) pad(x, 11, 'left', '0'), s);
end