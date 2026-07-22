function plot_reaches_on_map(data_KF_out, file_prefix)
% data_KF_out : basin struct array
%   - data_KF_out(b).paths   : nPaths×1 cell，每个是 m×1 double reach_id
%   - data_KF_out(b).Gauge_Q : 与 paths 同尺寸（或可索引到每条 path）
%       若 Gauge_Q 对应到每条 path 内部也是 cell（长度=m），则其中非空元素表示该 reach 有 gauge
%
% file_prefix : "na","eu","as","sa","af","oc"

    % ---------- 0) 检查 ----------
    if ~isstruct(data_KF_out) || ~isfield(data_KF_out,"paths")
        error('data_KF_out 必须是 struct array，并包含字段 .paths');
    end
    if ~isfield(data_KF_out,"Gauge_Q")
        error('data_KF_out 里找不到 Gauge_Q 字段');
    end

    % ---------- 1) 洲前缀 ----------
    allowedDigits = continent_digits(file_prefix);

    % ---------- 2) 读取 nc ----------
    ncfile = sprintf('%s_sword_v16.nc', file_prefix);
    reach_id = ncread(ncfile,'/reaches/reach_id');  % N×1
    lon      = ncread(ncfile,'/reaches/x');         % N×1
    lat      = ncread(ncfile,'/reaches/y');         % N×1
    reach_id = reach_id(:); lon = lon(:); lat = lat(:);

    SID_ALL = to11(reach_id);

    % ---------- 3) 从所有 basin/path 收集：全部 reach + gauge reach + path 数量 ----------
    all_reach_ids   = [];
    gauge_reach_ids = [];

    total_paths = 0;      % 所有 path 数量，包括空 path
    nonempty_paths = 0;   % 非空 path 数量，也就是实际有 reach 的 path

    for b = 1:numel(data_KF_out)
        P = data_KF_out(b).paths;
        if isempty(P), continue; end

        GQ = data_KF_out(b).Gauge_Q; % 可能是 cell array（与 paths 对应）

        for p = 1:numel(P)

            % 统计 path 数量
            total_paths = total_paths + 1;

            % 空 path 不进入 reach 统计
            if isempty(P{p})
                continue;
            end

            % 非空 path 数量
            nonempty_paths = nonempty_paths + 1;

            path_ids = P{p}(:);

            % 收集全部 reach
            all_reach_ids = [all_reach_ids; path_ids]; %#ok<AGROW>

            % --------- 收集 gauge reach ----------
            % 目标：得到一个与 path_ids 同长度的 “每个 reach 的 Gauge cell”
            g = [];  % g 最终希望是 cell(m,1)

            % 情况1：Gauge_Q 本身是 cell，且可用 {p} 取出对应 path 的 gauge 信息
            if iscell(GQ) && numel(GQ) >= p
                try
                    g = GQ{p};
                catch
                    g = [];
                end
            end

            % 情况2：Gauge_Q 是 cell matrix，大小与 paths 对应，用 {p,1} 取
            if isempty(g) && iscell(GQ) && ~isscalar(GQ)
                try
                    g = GQ{p,1};
                catch
                    % do nothing
                end
            end

            % 解释：
            % - 如果 g 是 cell(m,1) 或 cell(1,m)：逐个判断非空 => gauge 在对应 reach
            % - 如果 g 不是 cell，但非空：无法定位到具体哪个 reach，只能认为这条 path 有 gauge 信息
            if iscell(g)
                g = g(:);
                m = numel(path_ids);

                if numel(g) == m
                    hasGauge = false(m,1);
                    for k = 1:m
                        hasGauge(k) = ~isempty(g{k});
                    end
                    gauge_reach_ids = [gauge_reach_ids; path_ids(hasGauge)]; %#ok<AGROW>
                else
                    % 长度对不上：保守策略 -> 只要 g 里面出现非空，就把整条 path 记为含 gauge
                    anyNonEmpty = any(cellfun(@(x) ~isempty(x), g));
                    if anyNonEmpty
                        gauge_reach_ids = [gauge_reach_ids; path_ids]; %#ok<AGROW>
                    end
                end
            else
                % g 不是 cell
                if ~isempty(g)
                    gauge_reach_ids = [gauge_reach_ids; path_ids]; %#ok<AGROW>
                end
            end
        end
    end

    % 去 NaN / 去重
    all_reach_ids   = unique(all_reach_ids(~isnan(all_reach_ids) & all_reach_ids>0), 'stable');
    gauge_reach_ids = unique(gauge_reach_ids(~isnan(gauge_reach_ids) & gauge_reach_ids>0), 'stable');

    % ---------- 4) 标准化 + 洲前缀过滤 + 只保留 nc 中存在 ----------
    SUB_ALL   = intersect(SID_ALL, filter_by_prefix(to11(all_reach_ids),   allowedDigits), 'stable');
    SUB_GAUGE = intersect(SID_ALL, filter_by_prefix(to11(gauge_reach_ids), allowedDigits), 'stable');

    if isempty(SUB_ALL)
        warning('在 %s 数据集中没有匹配的 reach（SUB_ALL 为空）。', file_prefix);

        fprintf('[%s] total paths:           %d\n', file_prefix, total_paths);
        fprintf('[%s] non-empty paths:       %d\n', file_prefix, nonempty_paths);
        fprintf('[%s] matched reaches (all): 0\n', file_prefix);
        fprintf('[%s] matched reaches (gauge): 0\n', file_prefix);

        return
    end

    % ---------- 5) 映射到 lon/lat ----------
    [~, locAll]   = ismember(SUB_ALL,   SID_ALL);
    [~, locGauge] = ismember(SUB_GAUGE, SID_ALL);

    locAll   = locAll(locAll>0);
    locGauge = locGauge(locGauge>0);

    lon_all = lon(locAll);   lat_all = lat(locAll);
    lon_g   = lon(locGauge); lat_g   = lat(locGauge);

    % ---------- 6) 输出统计 ----------
    fprintf('[%s] total paths:             %d\n', file_prefix, total_paths);
    fprintf('[%s] non-empty paths:         %d\n', file_prefix, nonempty_paths);
    fprintf('[%s] matched reaches (all):   %d\n', file_prefix, numel(lon_all));
    fprintf('[%s] matched reaches (gauge): %d\n', file_prefix, numel(lon_g));

    % ---------- 7) 画在地图底图上 ----------
    figure;
    ax = geoaxes;
    geobasemap(ax, 'street');  
    % 你想换底图就在这里改：
    % 'streets' / 'street' / 'terrain' / 'satellite' / 'topographic'

    hold(ax, 'on');

    % 先画全部 reach
    geoscatter(ax, lat_all, lon_all, 30, '.', 'DisplayName', 'Reaches');

    % 再画 gauge reach
    if ~isempty(lon_g)
        geoscatter(ax, lat_g, lon_g, 40, '.', 'DisplayName', 'Gauge stations');
    end

    set(gca,'FontSize',15);

    title(ax, sprintf(['Reaches and gauge stations in %s \n' ...
        '(Path number=%d, Reach number=%d, gauge station number=%d)'], ...
        upper(string(file_prefix)), nonempty_paths, numel(lon_all), numel(lon_g)));

    legend(ax, 'Location', 'best');

    % 缩放范围
    pad = 1;
    geolimits(ax, [min(lat_all)-pad, max(lat_all)+pad], ...
                  [min(lon_all)-pad, max(lon_all)+pad]);
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
    s(s=="" | s=="NaN") = [];
    s = arrayfun(@(x) pad(x, 11, 'left', '0'), s);
end