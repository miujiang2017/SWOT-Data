function [basins, n2_before, n2_after] = rerun_riversp(basins, start_date, end_date)
% rerun_riversp_idx2_and_report
% 1) 统计 basins 里 index==2 的个数
% 2) 对所有 index==2 的 reach 重新调用 SWOT_RiverSP_TimeSeries 再写回
% 3) 再统计一次 index==2 的个数
%
% basins(ib).RiverSP_ReachData{ip}{ir,1} = ts
% basins(ib).RiverSP_ReachData{ip}{ir,2} = idx

maxRetry = 1;
% ---- (A) 重算前统计 ----
n2_before = count_riversp_idx2(basins);
fprintf('[RiverSP] Before rerun: index==2 count = %d\n', n2_before);

% ---- (B) 重算所有 idx==2 ----
for ib = 1:numel(basins)

    if ~isfield(basins(ib),'RiverSP_ReachData') || isempty(basins(ib).RiverSP_ReachData)
        continue;
    end
    if ~iscell(basins(ib).RiverSP_ReachData)
        continue;
    end

    n_paths = numel(basins(ib).RiverSP_ReachData);

    for ip = 1:n_paths
        if isempty(basins(ib).RiverSP_ReachData{ip})
            continue;
        end

        rsp_path = basins(ib).RiverSP_ReachData{ip};

        % 期望 rsp_path{ir,1}=ts, rsp_path{ir,2}=idx
        if ~iscell(rsp_path) || size(rsp_path,2) < 2
            continue;
        end

        nR = size(rsp_path,1);

        % 如果 basins(ib).paths 存在，用它拿 rid；否则尝试从 ts 里取 rid（取不到就跳过）
        has_paths = isfield(basins(ib),'paths') && numel(basins(ib).paths) >= ip && ~isempty(basins(ib).paths{ip});
        if has_paths
            reach_ids_path = basins(ib).paths{ip};
        else
            reach_ids_path = [];
        end

        for ir = 1:nR
            idx = rsp_path{ir,2};
            if isempty(idx) || ~isnumeric(idx) || idx ~= 2
                continue;
            end

            % 拿 rid
            if has_paths && numel(reach_ids_path) >= ir
                rid = reach_ids_path(ir);
            else
                % 没有 rid 就没法重算，跳过
                continue;
            end

            % ---- 重算（带重试）----
            ts_new = [];
            idx_new = 2;

            for attempt = 1:maxRetry
                try
                    [ts_tmp, idx_tmp] = SWOT_RiverSP_TimeSeries(rid, start_date, end_date);
                    ts_new  = ts_tmp;
                    idx_new = idx_tmp;
                    % 一旦不是“其它错误(2)”就停止重试
                    if idx_new ~= 2
                        break;
                    end
                catch
                    % 异常也按 idx=2 处理，继续重试
                    ts_new  = [];
                    idx_new = 2;
                    fprintf('RiverSP FAIL basin=%d path=%d ir=%d \n', ...
                    ib, ip, ir);
                end
            end

            % 写回
            basins(ib).RiverSP_ReachData{ip}{ir,1} = ts_new;
            basins(ib).RiverSP_ReachData{ip}{ir,2} = idx_new;
        end
    end
end

% ---- (C) 重算后统计 ----
n2_after = count_riversp_idx2(basins);
fprintf('[RiverSP] After  rerun: index==2 count = %d\n', n2_after);

end


function n2 = count_riversp_idx2(basins)
% 统计所有 basins 中 RiverSP_ReachData 的 idx==2 数量

n2 = 0;

for ib = 1:numel(basins)
    if ~isfield(basins(ib),'RiverSP_ReachData') || isempty(basins(ib).RiverSP_ReachData)
        continue;
    end
    R = basins(ib).RiverSP_ReachData;
    if ~iscell(R), continue; end

    for ip = 1:numel(R)
        if isempty(R{ip}), continue; end
        rsp_path = R{ip};
        if ~iscell(rsp_path) || size(rsp_path,2) < 2
            continue;
        end

        idx_col = rsp_path(:,2);
        for ir = 1:numel(idx_col)
            v = idx_col{ir};
            if isnumeric(v) && ~isempty(v) && isfinite(v) && v == 2
                n2 = n2 + 1;
            end
        end
    end
end

end