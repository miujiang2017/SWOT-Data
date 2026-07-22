function basins = add_SoS_priors_to_basins(basins, SoS_PriorsData)
% 将 SoS_PriorsData 映射到 basins：
% - mean_q_subset : 与 subset 对齐的 cell
% - USGS/WSC/MEFCCWP : 与 paths 同尺寸；每个 path 是 R×1 cell；每格为 [T×2]=[qt,q] 或 []
% - mean_q_intpl : 与 paths 对齐的数值向量（按 position 线性插值并外推，保证无 NaN）

if isempty(basins) || isempty(SoS_PriorsData), return; end

% ---- reach_id -> SoS 索引 ----
rid_all = [SoS_PriorsData.reach_id];
valid  = ~isnan(rid_all);
SoS_PriorsData = SoS_PriorsData(valid);
rid_all = double(rid_all(valid));
idx_map = containers.Map(rid_all, num2cell(1:numel(rid_all)));

for b = 1:numel(basins)
    %% 1) subset → mean_q_subset（cell）
    sub_ids = to_double_vec(basins(b).subset);
    K = numel(sub_ids);
    mq_cells = cell(K,1);
    for k = 1:K
        rid = sub_ids(k);
        if ~isnan(rid) && isKey(idx_map, rid)
            v = SoS_PriorsData(idx_map(rid)).mean_q;
            if ~isempty(v) && size(v,2)>1, v = v(:); end
            mq_cells{k} = v;
        else
            mq_cells{k} = [];
        end
    end
    basins(b).mean_q_subset = mq_cells;

    %% 2) paths → USGS/WSC/MEFCCWP（[qt,q]）
    P = numel(basins(b).paths);
    basins(b).USGS    = cell(size(basins(b).paths));
    basins(b).WSC     = cell(size(basins(b).paths));
    basins(b).MEFCCWP = cell(size(basins(b).paths));

    for p = 1:P
        path_ids = to_double_vec(basins(b).paths{p});

        USGS_cells    = pack_source_cells(path_ids, SoS_PriorsData, idx_map, 'USGS');
        WSC_cells     = pack_source_cells(path_ids, SoS_PriorsData, idx_map, 'WSC');
        MEFCCWP_cells = pack_source_cells(path_ids, SoS_PriorsData, idx_map, 'MEFCCWP');

        USGS_cells    = clean_reach_cells(USGS_cells);
        WSC_cells     = clean_reach_cells(WSC_cells);
        MEFCCWP_cells = clean_reach_cells(MEFCCWP_cells);

        if all(cellfun(@isempty, USGS_cells)),    USGS_cells    = []; end
        if all(cellfun(@isempty, WSC_cells)),     WSC_cells     = []; end
        if all(cellfun(@isempty, MEFCCWP_cells)), MEFCCWP_cells = []; end

        basins(b).USGS{p}    = USGS_cells;
        basins(b).WSC{p}     = WSC_cells;
        basins(b).MEFCCWP{p} = MEFCCWP_cells;
    end

    basins(b).USGS    = squash_cell_if_all_empty(basins(b).USGS);
    basins(b).WSC     = squash_cell_if_all_empty(basins(b).WSC);
    basins(b).MEFCCWP = squash_cell_if_all_empty(basins(b).MEFCCWP);

    %% 3) mean_q_intpl：按 position 插值 + 外推，保证无 NaN
    % 3.1 subset → 标量 mean_q（每 reach 一个）
    mq_scalar = nan(K,1);
    for k = 1:K
        v = mq_cells{k};
        if isempty(v)
            mq_scalar(k) = NaN;
        elseif isscalar(v)
            mq_scalar(k) = v;
        else
            mq_scalar(k) = nmean(v(:)); % 忽略 NaN
        end
    end

    % basin 级回退值（用于某 path 完全没有已知点时）
    basin_fallback = nmean(mq_scalar);
    if isnan(basin_fallback), basin_fallback = 0; end

    % reach_id -> mean_q 标量映射（重复取首次）
    [~, firstIdx] = unique(sub_ids, 'stable');
    id_keys = double(sub_ids(firstIdx));
    id_vals = num2cell(mq_scalar(firstIdx));
    id2mq = containers.Map(id_keys, id_vals);

    % 3.2 逐 path 映射 + 安全插值（带外推）
    basins(b).mean_q_intpl = cell(size(basins(b).paths));
    basins(b).min_q_intpl  = cell(size(basins(b).paths));
    basins(b).max_q_intpl  = cell(size(basins(b).paths));

    for p = 1:P
        path_ids = to_double_vec(basins(b).paths{p});

        if ~isfield(basins(b),'position') || numel(basins(b).position) < p
            error('basins(%d) 缺少 position{%d}。', b, p);
        end
        pos = to_double_vec(basins(b).position{p});

        R = numel(path_ids);
        if numel(pos) ~= R
            error('basins(%d).paths{%d} 与 position{%d} 长度不一致。', b, p, p);
        end

        % Map 到当前 path：mean_q / min_q / max_q（先全 NaN）
        mq_path     = nan(R,1);
        min_q_path  = nan(R,1);
        max_q_path  = nan(R,1);

        for r = 1:R
            rid = path_ids(r);

            if isnan(rid)
                continue;
            end

            % mean_q：用前面算好的 id2mq
            if isKey(id2mq, rid)
                mq_path(r) = id2mq(rid);
            end

            % min_q / max_q：直接从 SoS_PriorsData 中读字段 min_q / max_q
            if isKey(idx_map, rid)
                s = SoS_PriorsData(idx_map(rid));

                if isfield(s, 'min_q') && ~isempty(s.min_q)
                    % 如果是时间序列，就取均值（你也可以改成 min/max 等）
                    min_q_path(r) = nmean(s.min_q(:));
                end
                if isfield(s, 'max_q') && ~isempty(s.max_q)
                    max_q_path(r) = nmean(s.max_q(:));
                end
            end
        end

        % 过滤掉 <1 的值（你原来的逻辑）
        mq_path(mq_path < 1)       = NaN;
        min_q_path(min_q_path < 1) = NaN;
        max_q_path(max_q_path < 1) = NaN;

        % 已知点（决定 flag）
        known = ~isnan(mq_path) & ~isnan(pos);
        flag  = double(known);

        % 插值 + 外推（避免 NaN）
        yi_mq     = safe_interp_no_nan(pos, mq_path,    basin_fallback);
        yi_min_q  = safe_interp_no_nan(pos, min_q_path, basin_fallback);
        yi_max_q  = safe_interp_no_nan(pos, max_q_path, basin_fallback);

        basins(b).mean_q_intpl{p} = [yi_mq,    flag];
        basins(b).min_q_intpl{p}  = [yi_min_q, flag];
        basins(b).max_q_intpl{p}  = [yi_max_q, flag];
    end


end
end

%% ====================== 工具函数们 ======================

% 将一个 path 的某来源打包为 R×1 cell；每格 [T×2]=[qt,q] 或 []
function cells = pack_source_cells(path_ids, SoS, idx_map, src)
q_name  = [src '_q'];
qt_name = [src '_qt'];
R = numel(path_ids);
cells = cell(R,1);
for r = 1:R
    rid = path_ids(r);
    if isnan(rid) || ~isKey(idx_map, rid)
        cells{r} = []; continue;
    end
    s = SoS(idx_map(rid));
    vq  = []; vqt = [];
    if isfield(s, q_name)  && ~isempty(s.(q_name)),  vq  = s.(q_name);  end
    if isfield(s, qt_name) && ~isempty(s.(qt_name)), vqt = s.(qt_name); end
    if ~isempty(vq)  && size(vq,2)>1,  vq  = vq(:);  end
    if ~isempty(vqt) && size(vqt,2)>1, vqt = vqt(:); end
    if isempty(vq) && isempty(vqt)
        cells{r} = [];
    else
        Tq  = numel(vq); Tqt = numel(vqt);
        if isempty(vq), T = Tqt; elseif isempty(vqt), T = Tq; else, T = min(Tq,Tqt); end
        M = nan(T,2);                 % 第一列=qt，第二列=q
        if ~isempty(vqt), M(1:min(T,Tqt),1) = vqt(1:min(T,Tqt)); end
        if ~isempty(vq),  M(1:min(T,Tq), 2) = vq(1:min(T,Tq));   end
        cells{r} = M;
    end
end
end

% reach 级清理：若时间序列全 NaN 或空 → []
function cells = clean_reach_cells(cells)
for i = 1:numel(cells)
    if isempty(cells{i}), continue; end
    m = cells{i};
    if isempty(m) || all(isnan(m(:)))
        cells{i} = [];
    end
end
end

% 字段级压缩：外层 cell 全空 或 1x1 且内容空 → []
function out = squash_cell_if_all_empty(c)
if ~iscell(c), out = c; return; end
if isempty(c), out = []; return; end
if numel(c) == 1 && isempty(c{1}), out = []; return; end
if all(cellfun(@isempty, c(:))), out = []; return; end
out = c;
end

% 平均值（兼容无 'omitnan' 的环境）
function m = nmean(x)
try, m = mean(x,'omitnan'); catch, m = nanmean(x); end
end

% 把各种容器里的 id/序列转为 double 列向量
function v = to_double_vec(x)
if isnumeric(x)
    v = double(x(:));
elseif isstring(x)
    v = double(str2double(x(:)));
elseif iscell(x)
    v = nan(numel(x),1);
    for k = 1:numel(x), v(k) = str2double(string(x{k})); end
elseif ischar(x)
    v = double(str2double(string(x)));
else
    v = double(str2double(string(x(:))));
end
end

% —— 关键：安全插值 + 外推，保证输出无 NaN ——
function yi = safe_interp_no_nan(x, y, fallback_val)
% x: position (R×1), y: values with NaN (R×1)
R = numel(x);
xi = x(:); yi = y(:);

% 只用有位置且有值的点
known = ~isnan(yi) & ~isnan(xi);

if nnz(known) == 0
    % 完全没已知点：全填回退值
    yi = repmat(fallback_val, R, 1);
    return;
elseif nnz(known) == 1
    % 只有一个已知点：常数填充
    yi = repmat(yi(find(known,1,'first')), R, 1);
    return;
end

% 排序并处理重复位置（对重复 x 取均值）
[xs, ord] = sort(xi, 'ascend');
ys = yi(ord);
ks = ~isnan(ys) & ~isnan(xs);

xs_k = xs(ks); ys_k = ys(ks);
[xu,~,ic] = unique(xs_k, 'stable');        % 去重 x
if numel(xu) < 2
    % 虽然已知点不少，但 x 全相同 → 常数
    c = nmean(ys_k);
    yi = repmat(c, R, 1);
    return;
end
% 对重复 x 聚合均值
yu = accumarray(ic, ys_k, [], @(v) nmean(v));

% 线性插值 + 外推
ys_full_sorted = interp1(xu, yu, xs, 'linear', 'extrap');

% 还原原顺序
invord = zeros(R,1); invord(ord) = 1:R;
yi = ys_full_sorted(invord);

% 最后保险：仍有 NaN（极端数值）→ 用回退值替换
mask = isnan(yi);
if any(mask)
    yi(mask) = fallback_val;
end
end



% count = 0;
% locs = []; % 保存位置 [basin_index, subset_index]
%
% for b = 1:numel(basins)
%     mq_cells = basins(b).mean_q_subset;
%     for k = 1:numel(mq_cells)
%         v = mq_cells{k};
%         if ~isempty(v) && any(v <0)
%             count = count + 1;
%             locs = [locs; b, k]; %#ok<AGROW>
%             fprintf('发现 0 值于 basins(%d).mean_q_subset{%d}\n', b, k);
%         end
%     end
% end
%
% fprintf('\n共有 %d 个 mean_q_subset 含有 0。\n', count);
%
% if ~isempty(locs)
%     disp('位置列表 [basin_index, subset_index]:');
%     disp(locs);
% end