function basins = add_RiverSP_ReachData_to_basins_with_old(basins, basins_old, start_date, end_date, copy_old_only)
% add_RiverSP_ReachData_to_basins_with_old
% ============================================
% 功能：
%   在拉取 Hydrocron (SWOT_RiverSP_TimeSeries) 前，优先从 basins_old 复用已有 reach 的 ts；
%   但如果 basins_old 对应 reach 的 ts 是空/无效，则改为调用 Hydrocron 重新拉取。
%   copy_old_only = false: 保持上述逻辑；
%   copy_old_only = true : 只从 basins_old 按 reach_id 复制 RiverSP，不调用 Hydrocron。
%   在RiverSP data旁标识:index = 0: return River time seriesindex = 1: bad request, index = 2: other errors

if nargin < 4
    error('Usage: basins = add_RiverSP_ReachData_to_basins_with_old(basins, basins_old, start_date, end_date, copy_old_only)');
end

if nargin < 5 || isempty(copy_old_only)
    copy_old_only = false;
end

% -------- 0) 从 basins_old 建立一个 reach -> RiverSP pack 的索引 --------
old_map = containers.Map('KeyType','char','ValueType','any');
old_map = build_old_riversp_map(basins_old, old_map, copy_old_only);

% -------- 1) 新请求缓存（避免同一次运行重复撞 Hydrocron）--------
reach_cache = containers.Map('KeyType','char','ValueType','any');


for ib =1:numel(basins)

    if ~isfield(basins(ib), 'paths') || isempty(basins(ib).paths)
        continue;
    end

    paths   = basins(ib).paths;
    n_paths = numel(paths);

    % 初始化输出字段（随时可写回）
    if ~isfield(basins(ib), 'RiverSP_ReachData') || isempty(basins(ib).RiverSP_ReachData)
        basins(ib).RiverSP_ReachData = cell(n_paths, 1);
    elseif numel(basins(ib).RiverSP_ReachData) < n_paths
        tmp = basins(ib).RiverSP_ReachData;
        basins(ib).RiverSP_ReachData = cell(n_paths, 1);
        basins(ib).RiverSP_ReachData(1:numel(tmp)) = tmp;
    end

    for ip = 1:n_paths
        reach_ids_path = paths{ip};
        nR = numel(reach_ids_path);

        RiverSP_path = cell(nR, 1); %#ok<NASGU>  % 你原来就有，但当前逻辑主要是逐 reach 写回

        for ir = 1:nR
            rid = reach_ids_path(ir);
            key = rid2key(rid);

            if key == ""
                warning('Unsupported reach_id type: basin=%d path=%d ir=%d', ib, ip, ir);
                RiverSP_path{ir} = [];
                continue;
            end

            % -------- A) 优先复用 basins_old --------
            if isKey(old_map, key)
                pack_old = old_map(key);
                if copy_old_only || ~is_ts_empty(pack_old.ts)
                    RiverSP_path{ir} = pack_old.ts;
                    basins(ib).RiverSP_ReachData{ip}{ir,1} = pack_old.ts;
                    basins(ib).RiverSP_ReachData{ip}{ir,2} = pack_old.idx;
                    continue;
                end
                % 如果 old 里是空，就当没缓存，继续往下走 Hydrocron
            end

            if copy_old_only
                RiverSP_path{ir} = [];
                basins(ib).RiverSP_ReachData{ip}{ir,1} = [];
                basins(ib).RiverSP_ReachData{ip}{ir,2} = [];
                continue;
            end

            % -------- B) 再看本次运行 cache --------
            if isKey(reach_cache, key)
                pack = reach_cache(key);
                basins(ib).RiverSP_ReachData{ip}{ir,1} = pack.ts;
                basins(ib).RiverSP_ReachData{ip}{ir,2} = pack.idx;
                continue;
            end

            % -------- C) 最后才打 Hydrocron（带重试）--------

            [ts,idx] = SWOT_RiverSP_TimeSeries(rid, start_date, end_date);
            if idx == 2
                ts = [];
                fprintf('RiverSP FAIL basin=%d path=%d ir=%d rid=%s \n', ...
                    ib, ip, ir, key);
            end

            % 成功/失败都缓存，避免重复撞
            reach_cache(key) = struct('ts', {ts}, 'idx', {idx});

            basins(ib).RiverSP_ReachData{ip}{ir,1} = ts;
            basins(ib).RiverSP_ReachData{ip}{ir,2} = idx;
        end
    end
end
end

% ================= helpers =================

function old_map = build_old_riversp_map(basins_old, old_map, include_empty)
% 扫描 basins_old，把 (reach_id -> struct('ts', ts, 'idx', idx)) 放进 old_map
% include_empty=false 时只写入非空 ts；include_empty=true 时尽量原样复制 old。

if isempty(basins_old) || ~isstruct(basins_old)
    return;
end

for ib = 1:numel(basins_old)
    if ~isfield(basins_old(ib),'paths') || isempty(basins_old(ib).paths)
        continue;
    end
    if ~isfield(basins_old(ib),'RiverSP_ReachData') || isempty(basins_old(ib).RiverSP_ReachData)
        continue;
    end

    paths = basins_old(ib).paths;
    RSP   = basins_old(ib).RiverSP_ReachData;

    n_paths = min(numel(paths), numel(RSP));

    for ip = 1:n_paths
        if isempty(paths{ip}) || isempty(RSP{ip})
            continue;
        end

        reach_ids_path = paths{ip};
        ts_cell = RSP{ip};

        nR = min(numel(reach_ids_path), size(ts_cell, 1));

        for ir = 1:nR
            rid = reach_ids_path(ir);
            key = rid2key(rid);
            if key == ""
                continue;
            end

            ts = ts_cell{ir, 1};
            idx = [];
            if size(ts_cell, 2) >= 2
                idx = ts_cell{ir, 2};
            end
            if isempty(idx) && ~is_ts_empty(ts)
                idx = 0;
            end

            % ---- 默认只收集非空 ts；copy_old_only 时空值也复制 ----
            if ~include_empty && is_ts_empty(ts)
                continue;
            end

            % 只要 old_map 还没有该 key，就写入（避免覆盖）
            if ~isKey(old_map, key)
                old_map(key) = struct('ts', {ts}, 'idx', {idx});
            end
        end
    end
end
end

function key = rid2key(rid)
% 把 reach_id 统一成字符串 key
if isnumeric(rid)
    if isnan(rid)
        key = "";
    else
        key = sprintf('%.0f', rid);
    end
elseif isstring(rid)
    key = char(rid);
elseif ischar(rid)
    key = rid;
else
    key = "";
end
end

function tf = is_ts_empty(ts)
% 判断 RiverSP 的 time series 是否“空/无效”
% 你可以按你 SWOT_RiverSP_TimeSeries 的返回类型再加规则

if isempty(ts)
    tf = true;
    return;
end

% table / timetable
if istable(ts) || istimetable(ts)
    tf = (height(ts) == 0);
    return;
end

% struct：没字段 或 所有字段都空/NaN 也当空
if isstruct(ts)
    fn = fieldnames(ts);
    if isempty(fn)
        tf = true;
        return;
    end
    allEmpty = true;
    for k = 1:numel(fn)
        v = ts.(fn{k});
        if iscell(v)
            if any(~cellfun(@isempty, v))
                allEmpty = false; break;
            end
        elseif isnumeric(v)
            if any(~isnan(v(:)))
                allEmpty = false; break;
            end
        else
            if ~isempty(v)
                allEmpty = false; break;
            end
        end
    end
    tf = allEmpty;
    return;
end

% 其它类型（比如 string/cell 等）：按 isempty 判（你原注释这样写，但这里保持 false）
tf = false;
end
