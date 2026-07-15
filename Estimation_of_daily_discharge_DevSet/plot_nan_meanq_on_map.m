function plot_nan_meanq_on_map(SoS_PriorsData, file_prefix)
% plot_nan_meanq_on_map
% 画出 SoS_PriorsData 中 mean_q 为 NaN 的 reaches 在地图上的位置
%
% SoS_PriorsData : 1×N struct array (如图), 至少包含字段:
%   - .reach_id
%   - .mean_q
%
% file_prefix : "na","eu","as","sa","af","oc"
% 对应读取: <file_prefix>_sword_v16.nc

    % ---------- 0) 检查 ----------
    if ~isstruct(SoS_PriorsData) || ~isfield(SoS_PriorsData,"reach_id")
        error('SoS_PriorsData 必须是 struct array，并包含字段 .reach_id');
    end
    if ~isfield(SoS_PriorsData,"mean_q")
        error('SoS_PriorsData 里找不到 mean_q 字段');
    end

    % ---------- 1) 洲前缀 ----------
    allowedDigits = continent_digits(file_prefix);

    % ---------- 2) 读取 nc ----------
    ncfile = sprintf('%s_sword_v17.nc', file_prefix);
    reach_id_nc = ncread(ncfile,'/reaches/reach_id');  % N×1
    lon         = ncread(ncfile,'/reaches/x');         % N×1
    lat         = ncread(ncfile,'/reaches/y');         % N×1
    reach_id_nc = reach_id_nc(:); lon = lon(:); lat = lat(:);

    SID_ALL = to11(reach_id_nc);

    % ---------- 3) 从 SoS_PriorsData 取出 mean_q 与 reach_id ----------
    mean_q_all  = [SoS_PriorsData.mean_q];
    reach_id_all = [SoS_PriorsData.reach_id];

    % 找 NaN
    maskNaN = isnan(mean_q_all) & ~isnan(reach_id_all) & (reach_id_all > 0);
    nan_reach_ids = reach_id_all(maskNaN);

    % 去重
    nan_reach_ids = unique(nan_reach_ids(:), 'stable');

    if isempty(nan_reach_ids)
        warning('SoS_PriorsData 中 mean_q 为 NaN 的 reach 为空。');
        return
    end

    % ---------- 4) 标准化 + 洲前缀过滤 + 只保留 nc 中存在 ----------
    SUB_NAN = intersect(SID_ALL, filter_by_prefix(to11(nan_reach_ids), allowedDigits), 'stable');

    if isempty(SUB_NAN)
        warning('在 %s 数据集中没有匹配到 mean_q=NaN 的 reach（SUB_NAN 为空）。', file_prefix);
        return
    end

    % ---------- 5) 映射到 lon/lat ----------
    [~, locNan] = ismember(SUB_NAN, SID_ALL);
    locNan = locNan(locNan>0);

    lon_nan = lon(locNan);
    lat_nan = lat(locNan);

    fprintf('[%s] NaN(mean_q) reaches matched: %d\n', file_prefix, numel(lon_nan));

    % ---------- 6) 画在地图底图上 ----------
    figure;
    ax = geoaxes;
    geobasemap(ax, 'street');
    hold(ax, 'on');

    geoscatter(ax, lat_nan, lon_nan, 35, '.', 'DisplayName', 'mean\_q = NaN');
    set(gca,'FontSize',15);

    title(ax, sprintf('mean_q = NaN reaches in %s (count=%d)', ...
        upper(string(file_prefix)), numel(lon_nan)));

    legend(ax, 'Location', 'best');

    % 缩放范围
    pad = 1;
    geolimits(ax, [min(lat_nan)-pad, max(lat_nan)+pad], ...
                 [min(lon_nan)-pad, max(lon_nan)+pad]);
end

% ================= helpers =================

function out = filter_by_prefix(S, allowedDigits)
    mask = false(size(S));
    for d = allowedDigits
        mask = mask | startsWith(S, d);
    end
    out = S(mask);
end

function digits = continent_digits(prefix)
    switch lower(string(prefix))
        case "af", digits = ["1"];
        case "eu", digits = ["2"];
        case "as", digits = ["3","4"];
        case "na", digits = ["7","8","9"];
        case "oc", digits = ["5"];
        case "sa", digits = ["6"];
        otherwise
            error('未知 file_prefix: %s', string(prefix));
    end
end

function s = to11(ids)
    s = string(ids(:));
    s = strip(replace(s, '"', ''));
    s(s=="" | s=="NaN") = [];
    s = arrayfun(@(x) pad(x, 11, 'left', '0'), s);
end
