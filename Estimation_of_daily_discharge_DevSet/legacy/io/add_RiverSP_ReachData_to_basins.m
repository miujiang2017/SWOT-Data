function basins = add_RiverSP_ReachData_to_basins(basins, start_date, end_date)
% add_RiverSP_ReachData_to_basins
% ============================================
% 功能：
%   使用 Hydrocron 接口函数 SWOT_RiverSP_TimeSeries，
%   按 basins(i).paths 的结构，对每个 reach 拉 RiverSP 时间序列，
%   并把结果按「path 结构」存回 basins。
%
% 输入：
%   basins      : 之前路径枚举好的 basins 结构数组
%                 需要包含字段 basins(i).paths
%                 其中 paths{j} 是第 j 条 path 的 reach_id 向量（上游→下游）
%   start_date  : 字符串，例如 '2024-01-01'
%   end_date    : 字符串，例如 '2024-12-30'
%
% 输出：
%   basins(i).RiverSP_ReachData :
%       cell(n_paths, 1)，与 basins(i).paths 平行
%       RiverSP_ReachData{j} 是一个 cell(nR, 1)
%       RiverSP_ReachData{j}{k} = SWOT_RiverSP_TimeSeries(该 reach, ...)
%
%   也就是说：
%       basins(i).paths{j}(k)             ← 第 i 个 basin，第 j 条 path，第 k 个 reach_id
%       basins(i).RiverSP_ReachData{j}{k} ← 对应的 RiverSP 时间序列结构

if nargin < 3
    error('Usage: basins = add_RiverSP_ReachData_to_basins(basins, start_date, end_date)');
end

reach_cache = containers.Map('KeyType','char','ValueType','any');


for ib = 2%:numel(basins)

    if ~isfield(basins(ib), 'paths') || isempty(basins(ib).paths)
        continue;
    end

    paths = basins(ib).paths;
    n_paths = numel(paths);

    % 如果以前没这个字段，先初始化，保证“随时可写回”
    if ~isfield(basins(ib), 'RiverSP_ReachData') || isempty(basins(ib).RiverSP_ReachData)
        basins(ib).RiverSP_ReachData = cell(n_paths, 1);
    end

    for ip = 1:n_paths
        reach_ids_path = paths{ip};
        nR = numel(reach_ids_path);

        RiverSP_path = cell(nR, 1);

        for ir =13%1:nR
            rid = reach_ids_path(ir);

            % cache key
            if isnumeric(rid)
                key = sprintf('%d', rid);
            elseif isstring(rid)
                key = char(rid);
            elseif ischar(rid)
                key = rid;
            else
                warning('Unsupported reach_id type: basin=%d path=%d ir=%d', ib, ip, ir);
                RiverSP_path{ir} = [];
                continue;
            end

            % 如果缓存里有（包括失败占位），直接用
            if isKey(reach_cache, key)
                RiverSP_path{ir} = reach_cache(key);
                continue;
            end

            % --- 关键：try/catch + 重试，失败也返回占位，保证不中断 ---
            [ts,idx] = SWOT_RiverSP_TimeSeries(rid, start_date, end_date);
            if idx == 2
                fprintf('RiverSP FAIL basin=%d path=%d ir=%d rid=%s | %s\n', ...
                    ib, ip, ir, key);
            end

            reach_cache(key) = ts;     % 失败也缓存，避免反复撞
            % ✅ 每条 path 做完就写回 basins（保证已有结果立刻进入输出）
            basins(ib).RiverSP_ReachData{ip}{ir,1} = ts;
            basins(ib).RiverSP_ReachData{ip}{ir,2} = idx;
        end


    end
end
end

