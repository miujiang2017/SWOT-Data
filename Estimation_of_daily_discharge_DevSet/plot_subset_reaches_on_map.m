function plot_subset_reaches_on_map(subset_ids, file_prefix)
% subset_ids : n×1 reach_id (double/int/string 都行，NaN 会被忽略)
% file_prefix: "na","eu","as","sa","af","oc"

    % ---------- 0) 检查 ----------
    if nargin < 2
        error('用法: plot_subset_reaches_on_map(subset_ids, file_prefix)');
    end
    if isempty(subset_ids)
        warning('subset_ids 为空，没法画。');
        return
    end

    % 转列向量
    subset_ids = subset_ids(:);

    % ---------- 1) 洲前缀 ----------
    allowedDigits = continent_digits(file_prefix);

    % ---------- 2) 读取 nc ----------
    ncfile = sprintf('%s_sword_v16.nc', file_prefix);
    reach_id_nc = ncread(ncfile,'/reaches/reach_id');  % N×1
    lon         = ncread(ncfile,'/reaches/x');         % N×1
    lat         = ncread(ncfile,'/reaches/y');         % N×1
    reach_id_nc = reach_id_nc(:); lon = lon(:); lat = lat(:);

    SID_ALL = to11(reach_id_nc);

    % ---------- 3) 清理 subset_ids（去 NaN / <=0） ----------
    if isnumeric(subset_ids)
        subset_ids = subset_ids(~isnan(subset_ids) & subset_ids > 0);
    else
        % string/cellstr: 去掉空
        subset_ids = subset_ids(string(subset_ids)~="");
    end

    if isempty(subset_ids)
        warning('subset_ids 清理后为空（全是 NaN/空/<=0）。');
        return
    end

    % ---------- 4) 标准化 + 洲前缀过滤 + 只保留 nc 中存在 ----------
    SUB = intersect(SID_ALL, filter_by_prefix(to11(subset_ids), allowedDigits), 'stable');

    if isempty(SUB)
        warning('在 %s 数据集中没有匹配到 subset_ids（SUB 为空）。', file_prefix);
        return
    end

    % ---------- 5) 映射到 lon/lat ----------
    [~, loc] = ismember(SUB, SID_ALL);
    loc = loc(loc>0);

    lon_sub = lon(loc);
    lat_sub = lat(loc);

    fprintf('[%s] subset reaches matched: %d\n', file_prefix, numel(lon_sub));

    % ---------- 6) 画图 ----------
    figure;
    ax = geoaxes;
    geobasemap(ax, 'street');
    hold(ax, 'on');

    geoscatter(ax, lat_sub, lon_sub, 35, '.', 'DisplayName', 'subset\_ids');
    set(gca,'FontSize',15);

    title(ax, sprintf('Subset reaches in %s (count=%d)', ...
        upper(string(file_prefix)), numel(lon_sub)));
    legend(ax, 'Location', 'best');

    pad = 1;
    geolimits(ax, [min(lat_sub)-pad, max(lat_sub)+pad], ...
                 [min(lon_sub)-pad, max(lon_sub)+pad]);
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
