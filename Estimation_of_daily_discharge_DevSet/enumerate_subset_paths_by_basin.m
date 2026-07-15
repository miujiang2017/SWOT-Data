function basins = enumerate_subset_paths_by_basin(SoS_ResultsData, file_prefix)
% ============================================================
% 功能（按 basin 分治；贪心覆盖 subset）
%   - paths：n×1 cell，每条 m×1 double（上游→下游）
%   - name ：n×1 string，对应每条 path 的“多数河名”（分号拆分，忽略 NODATA）
%   - length：n×1 cell，每条 path 的长度（m×1 double）
%   - position：n×1 cell，每条 path 的 reach 的中心位置（m×1 double）
%   - width_sword: n×1 cell，每条 path 的 reach_width_sword（m×1 double）
%   - wse_sword: n×1 cell，每条 path 的 reach_wse_sword（m×1 double）
%   - widthvar_sword: n×1 cell，每条 path 的 reach_widthvar_sword（m×1 double）
%   - slope_sword: n×1 cell，每条 path 的 reach_slope_sword（m×1 double）
% 规则：
%   - subset < 2 的 basin 跳过
%   - path 长度 < 2 跳过
%   - basin 最终无有效 path 跳过
% ============================================================

% find reach ids with valid ML prior 
reach_id = [SoS_ResultsData.reach_id];
mean_q = [SoS_ResultsData.mean_q];
subset_ids = unique(reach_id(~isnan(mean_q) & ~isnan(reach_id)));

    % ---------- 1) 洲前缀 ----------
    allowedDigits = continent_digits(file_prefix);

    % ---------- 2) 读取该洲 nc ----------
    ncfile = sprintf('%s_sword_v16.nc', file_prefix);
    reach_id   = ncread(ncfile,'/reaches/reach_id');    % N×1
    rch_id_dn  = ncread(ncfile,'/reaches/rch_id_dn');  % N×K
    rch_id_up  = ncread(ncfile,'/reaches/rch_id_up');  % N×K
    river_name = ncread(ncfile,'/reaches/river_name');  % N×K
    rch_len    = ncread(ncfile,'/reaches/reach_length'); % N×K
    reach_width_sword = ncread(ncfile,'/reaches/width'); % N×K
    reach_wse_sword = ncread(ncfile,'/reaches/wse');     % N×K
    reach_widthvar_sword = ncread(ncfile,'/reaches/width_var'); % N×K
    reach_slope_sword = ncread(ncfile,'/reaches/slope'); % N×K
    if size(rch_id_up,1) ~= numel(reach_id), rch_id_up = rch_id_up.'; end
    if size(rch_id_dn,1) ~= numel(reach_id), rch_id_dn = rch_id_dn.'; end
    river_name = string(river_name(:));  % 长度 N
    rch_len = rch_len(:);  % 长度 N

    % ---------- 3) 标准化 subset ----------
    SID_ALL = to11(reach_id);            % 全部 reach -> 11位字符串
    SUBSET  = unique(to11(subset_ids));  % JSON 全部 reach -> 11位字符串

    % 洲前缀过滤 + 仅保留 nc 中存在的
    mask = false(size(SUBSET));
    for d = allowedDigits
        mask = mask | startsWith(SUBSET, d);
    end
    SUBSET = SUBSET(mask);
    SUBSET = intersect(SID_ALL, SUBSET, 'stable');

    if isempty(SUBSET)
        basins = struct('basin_id',{},'paths',{},'n_paths',{},'subset',{},'name',{},'length',{},'position',{},'width_sword',{},'wse_sword',{},'widthvar_sword',{},'slope_sword',{});
        warning('在 %s 数据集中没有匹配的 JSON reach。', file_prefix);
        return
    end

    % ---------- 4) 构建映射 ----------
    BASIN6 = extractBetween(SID_ALL,1,6);
    N = numel(SID_ALL);

    % id -> 下游列表
    keys_char = cellstr(SID_ALL);
    dn_map = containers.Map('KeyType','char','ValueType','any');
    for i = 1:N
        dn_map(keys_char{i}) = clean_ids_row(rch_id_dn(i,:), SID_ALL(i));
    end
    % id -> 全局索引（为路径映射到 river_name 和 reach_length 准备）
    id2idx = containers.Map('KeyType','char','ValueType','int32');
    for i = 1:N
        id2idx(char(SID_ALL(i))) = int32(i);
    end

    % ---------- 5) 按 basin 分组 ----------
    [G, basin_keys] = findgroups(BASIN6);
    basins = struct('basin_id',{},'paths',{},'n_paths',{},'subset',{},'name',{},'length',{},'position',{},'width_sword',{},'wse_sword',{},'widthvar_sword',{},'slope_sword',{});

    for b = 1:numel(basin_keys)
        basin_id = basin_keys(b);
        idxs_in_basin = find(G==b);
        ids_in_basin  = SID_ALL(idxs_in_basin);
        if isempty(ids_in_basin), continue; end

        sub_nodes = intersect(ids_in_basin, SUBSET, 'stable');
        if numel(sub_nodes) < 2, continue; end

        % —— 只在本 basin 内游走的下游邻接 —— %
        ids_char = cellstr(ids_in_basin);
        set_inB = containers.Map('KeyType','char','ValueType','logical');
        for i = 1:numel(ids_char), set_inB(ids_char{i}) = true; end
        inB = @(v) arrayfun(@(x) isKey(set_inB, char(x)), v);

        dn_local = containers.Map('KeyType','char','ValueType','any');
        for i = 1:numel(ids_char)
            u = ids_char{i};
            dns = dn_map(u);
            dns = dns(inB(dns));
            dn_local(u) = dns;
        end

        % ====== 真实拓扑序 ======
        topo_asc_idx = compute_topo_asc(ids_in_basin, dn_local); % 下游→上游
        idnum = str2double(ids_in_basin);

        uncovered = ismember(ids_in_basin, sub_nodes);
        all_paths = {};             % n×1 cell（每条 m×1 double）
        names_per_path = strings(0,1); % n×1 string（每条 1 个名字）
        lengths_per_path = {};       % n×1 cell（每条 m×1 double，路径上每个 reach 的长度）
        positions_per_path = {};     % n×1 cell（每条 m×1 double，路径上每个 reach 的中心位置）
        width_sword_per_path = {};   % n×1 cell（每条 m×1 double，路径上每个 reach 的 width_sword）
        wse_sword_per_path = {};     % n×1 cell（每条 m×1 double，路径上每个 reach 的 wse_sword）
        widthvar_sword_per_path = {}; % n×1 cell（每条 m×1 double，路径上每个 reach 的 widthvar_sword）
        slope_sword_per_path = {};   % n×1 cell（每条 m×1 double，路径上每个 reach 的 slope_sword）

        % —— 贪心生成路径 —— %
        while any(uncovered)
            cand_idx = find(uncovered & ismember(ids_in_basin, sub_nodes));
            [~, ord]  = sort(idnum(cand_idx), 'descend');
            start_idx = cand_idx(ord(1));
            cur = ids_in_basin(start_idx);

            score = downstream_subset_score(ids_in_basin, dn_local, topo_asc_idx, uncovered);

            path = string(cur);
            visited = containers.Map('KeyType','char','ValueType','logical');
            visited(char(cur)) = true;
            last_subset_pos = 1;

            path_lengths = rch_len(id2idx(char(cur)));  % 初始路径长度
            path_positions = [0];  % 初始位置

            path_width_sword = reach_width_sword(id2idx(char(cur))); % 初始 width_sword
            path_wse_sword = reach_wse_sword(id2idx(char(cur))); % 初始 wse_sword
            path_widthvar_sword = reach_widthvar_sword(id2idx(char(cur))); % 初始 widthvar_sword
            path_slope_sword = reach_slope_sword(id2idx(char(cur))); % 初始 slope_sword

            while true
                nexts = string(dn_local(char(cur)));
                if isempty(nexts)
                    path = path(1:last_subset_pos);
                    path_lengths = path_lengths(1:last_subset_pos);
                    path_positions = path_positions(1:last_subset_pos);
                    path_width_sword = path_width_sword(1:last_subset_pos);
                    path_wse_sword = path_wse_sword(1:last_subset_pos);
                    path_widthvar_sword = path_widthvar_sword(1:last_subset_pos);
                    path_slope_sword = path_slope_sword(1:last_subset_pos);
                    break
                end
                sc = zeros(numel(nexts),1);
                for t = 1:numel(nexts)
                    sc(t) = score(char(nexts(t)));
                end
                if max(sc) <= 0
                    path = path(1:last_subset_pos);
                    path_lengths = path_lengths(1:last_subset_pos);
                    path_positions = path_positions(1:last_subset_pos);
                    path_width_sword = path_width_sword(1:last_subset_pos);
                    path_wse_sword = path_wse_sword(1:last_subset_pos);
                    path_widthvar_sword = path_widthvar_sword(1:last_subset_pos);
                    path_slope_sword = path_slope_sword(1:last_subset_pos);
                    break
                end
                next_num = str2double(nexts);
                [~, idxSort] = sortrows([ -sc(:), next_num(:) ], [1,2]);
                chosen = nexts(idxSort(1));

                if isKey(visited, char(chosen)), break; end
                visited(char(chosen)) = true;
                path = [path; chosen]; %#ok<AGROW>
                path_lengths = [path_lengths; rch_len(id2idx(char(chosen)))];  % 累加路径长度

                % 计算中心位置
                new_position = [0; cumsum(path_lengths(1:end-1))] + path_lengths / 2 - path_lengths(1) / 2;
                path_positions = [path_positions; new_position(end)]; % 只保留新加的一个位置

                % 存储 reach 对应的额外数据
                path_width_sword = [path_width_sword; reach_width_sword(id2idx(char(chosen)))];
                path_wse_sword = [path_wse_sword; reach_wse_sword(id2idx(char(chosen)))];
                path_widthvar_sword = [path_widthvar_sword; reach_widthvar_sword(id2idx(char(chosen)))];
                path_slope_sword = [path_slope_sword; reach_slope_sword(id2idx(char(chosen)))];

                cur  = chosen;

                ii = find(ids_in_basin == cur, 1, 'first');
                if ~isempty(ii) && uncovered(ii) && ismember(cur, sub_nodes)
                    last_subset_pos = numel(path);
                end
            end

            % 标记覆盖
            on_path_mask   = ismember(ids_in_basin, path);
            subset_on_path = on_path_mask & ismember(ids_in_basin, sub_nodes);
            uncovered(subset_on_path) = false;

            % 仅保留长度 >= 2 的路径（m×1 double）并生成 1 个名字
            if numel(path) >= 2
                % 保存路径
                all_paths{end+1,1} = str2double(path(:)); %#ok<AGROW>
                lengths_per_path{end+1,1} = path_lengths;   % 对应长度
                positions_per_path{end+1,1} = path_positions; % 对应位置
                width_sword_per_path{end+1,1} = path_width_sword;
                wse_sword_per_path{end+1,1} = path_wse_sword;
                widthvar_sword_per_path{end+1,1} = path_widthvar_sword;
                slope_sword_per_path{end+1,1} = path_slope_sword;

                % 生成该路径的多数河名：
                tokens = strings(0,1);
                firstPos = containers.Map('KeyType','char','ValueType','int32');
                counts   = containers.Map('KeyType','char','ValueType','int32');

                for t = 1:numel(path)
                    rid = char(path(t));
                    idx = id2idx(rid);
                    rn  = river_name(double(idx));
                    parts = strtrim(split(rn, ';'));
                    parts(parts=="") = [];
                    for pp = 1:numel(parts)
                        s = parts(pp);
                        if upper(s)=="NODATA", continue; end
                        k = char(s);
                        if ~isKey(counts, k)
                            counts(k) = int32(0);
                            firstPos(k) = int32(t);
                        end
                        counts(k) = counts(k) + 1;
                    end
                end

                if counts.Count == 0
                    names_per_path(end+1,1) = "NODATA"; %#ok<AGROW>
                else
                    ks = counts.keys;
                    best_key = ks{1};
                    best_cnt = counts(best_key);
                    best_pos = firstPos(best_key);
                    for ii = 2:numel(ks)
                        k = ks{ii};
                        c = counts(k);
                        p = firstPos(k);
                        if c > best_cnt || (c == best_cnt && p < best_pos)
                            best_key = k; best_cnt = c; best_pos = p;
                        end
                    end
                    names_per_path(end+1,1) = string(best_key); %#ok<AGROW>
                end
            end
        end

        % 若该 basin 最终没有任何有效 path，则跳过
        if isempty(all_paths), continue; end

        % —— 汇总 —— %
        basins(end+1).basin_id = basin_id; %#ok<AGROW>
        basins(end).paths   = all_paths;             % n×1 cell（m×1 double）
        basins(end).n_paths = numel(all_paths);
        basins(end).subset  = sub_nodes;             % 保留以便参考
        basins(end).name    = names_per_path;        % n×1 string（每条一个名字）
        basins(end).length  = lengths_per_path;      % n×1 cell（每条路径的长度 m×1 double）
        basins(end).position = positions_per_path;   % n×1 cell（每条路径的中心位置 m×1 double）
        basins(end).width_sword = width_sword_per_path; % n×1 cell（每条路径的 width_sword 数据）
        basins(end).wse_sword = wse_sword_per_path;   % n×1 cell（每条路径的 wse_sword 数据）
        basins(end).widthvar_sword = widthvar_sword_per_path; % n×1 cell（每条路径的 widthvar_sword 数据）
        basins(end).slope_sword = slope_sword_per_path; % n×1 cell（每条路径的 slope_sword 数据）
    end
end


% ===================== 局部函数 =====================

function topo_asc_idx = compute_topo_asc(ids_in_basin, dn_local)
    M = numel(ids_in_basin);
    idx_map = containers.Map('KeyType','char','ValueType','int32');
    for i = 1:M
        idx_map(char(ids_in_basin(i))) = int32(i);
    end
    outdeg   = zeros(M,1,'int32');
    up_lists = cell(M,1);
    for i = 1:M
        u = char(ids_in_basin(i));
        ns = string(dn_local(u));
        ns = ns(ismember(ns, ids_in_basin));
        outdeg(i) = int32(numel(ns));
        for t = 1:numel(ns)
            j = idx_map(char(ns(t)));
            up_lists{j}(end+1) = int32(i); %#ok<AGROW>
        end
    end
    q = find(outdeg==0);
    head = 1; k = 0;
    topo_asc_idx = zeros(M,1,'int32');
    while head <= numel(q)
        v = q(head); head = head + 1;
        k = k + 1; topo_asc_idx(k) = v;
        pars = up_lists{v};
        for t = 1:numel(pars)
            p = pars(t);
            outdeg(p) = outdeg(p) - 1;
            if outdeg(p) == 0
                q(end+1) = p; %#ok<AGROW>
            end
        end
    end
    topo_asc_idx = topo_asc_idx(1:k);
end

function score = downstream_subset_score(ids_in_basin, dn_local, topo_asc_idx, uncovered)
    score = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(ids_in_basin)
        score(char(ids_in_basin(i))) = 0.0;
    end
    for kk = 1:numel(topo_asc_idx)
        i = topo_asc_idx(kk);
        u = char(ids_in_basin(i));
        s = double(uncovered(i));
        ns = string(dn_local(u));
        for t = 1:numel(ns)
            s = s + score(char(ns(t)));
        end
        score(u) = s;
    end
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
    s = string(ids);
    s = strip(replace(s, '"', ''));
    s(s=="" | s=="NaN") = [];
    s = arrayfun(@(x) pad(x, 11, 'left', '0'), s);
end

function v = clean_ids_row(row, self_id)
    if isnumeric(row)
        row = row(:)'; 
        row = row(row > 0 & ~isnan(row));
        v = string(row);
    else
        v = string(row(:)');
    end
    v = strip(replace(v, '"', ''));
    v(v=="" | v=="0" | v=="NaN") = [];
    if ~isempty(v), v = arrayfun(@(x) pad(x, 11, 'left', '0'), v); end
    if nargin >= 2 && ~isempty(self_id)
        v = v(v ~= self_id);
    end
end

