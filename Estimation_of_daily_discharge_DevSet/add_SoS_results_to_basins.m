function basins = add_SoS_results_to_basins(basins, SoS_ResultsData, iris_file)
% 将 SoS_ResultsData 中的 Q_MOMMA, Q_SIC4DVar, Q_geoBAM, Q_SADS, Q_MetroMan
% 提取并映射到 basins 中的每条路径。
% 另外根据 IRIS nc 中的 reach_id 和 avg_combined_slope 数据，为每条 path 添加坡度信息，并插值填补缺失值。
%
% === IRIS slope 填补规则（按你最新要求）===
% 1) slope 插值用 linear；
% 2) slope 外推用 nearest neighbor（两端常数延拓）；
% 3) slope==0 视为缺失值，也要被填补；
% 4) 返回 slope_IRIS{p} 为 R×2：
%    - 第1列：填补后的 slope
%    - 第2列：is_raw（1=原始有效值；0=插值/外推/填补得到）
%
% 注意：is_raw 按“原始有效点”定义：~isnan & slope~=0 & pos有效

    if isempty(basins) || isempty(SoS_ResultsData), return; end

    %% -------- IRIS：读取并建映射 reach_id -> slope --------
    if nargin < 3 || isempty(iris_file)
        error('需要提供 IRIS nc 文件名作为第三个参数 iris_file');
    end

    reach_id_IRIS = double(ncread(iris_file, 'reach_id'));
    S_IRIS_raw    = double(ncread(iris_file, 'avg_combined_slope'));

    % 单位换算
    S_IRIS_raw    = S_IRIS_raw * 1e-6;

    % 过滤掉 NaN reach_id，避免 Map 报错
    good_iris = ~isnan(reach_id_IRIS);
    iris_map  = containers.Map(reach_id_IRIS(good_iris), num2cell(S_IRIS_raw(good_iris)));

    %% -------- SoS：reach_id -> 行号 的映射 --------
    reach_ids = double(cell2mat(SoS_ResultsData(:,1)));   % [N×1 double]
    good_sos  = ~isnan(reach_ids);

    row_map   = containers.Map(reach_ids(good_sos), num2cell(find(good_sos)));
    info_col  = SoS_ResultsData(:,2);                     % {N×1 cell}，每个 cell 是一个 struct

    %% -------- 逐 basin 处理 --------
    for b = 1:numel(basins)
        P = numel(basins(b).paths);

        basins(b).Q_MOMMA     = cell(size(basins(b).paths));
        basins(b).Q_SIC4DVar  = cell(size(basins(b).paths));
        basins(b).Q_geoBAM    = cell(size(basins(b).paths));
        basins(b).Q_SADS       = cell(size(basins(b).paths));
        basins(b).Q_MetroMan  = cell(size(basins(b).paths));
        basins(b).slope_IRIS  = cell(size(basins(b).paths));


        basins(b).v_MOMMA     = cell(size(basins(b).paths));
        basins(b).Y_MOMMA     = cell(size(basins(b).paths));

        for p = 1:P
            path_ids = to_double_vec(basins(b).paths{p});
            R        = numel(path_ids);

            momma_cells     = cell(R,1);
            sic4dvar_cells  = cell(R,1);
            geobam_cells    = cell(R,1);
            sads_cells       = cell(R,1);
            metroman_cells  = cell(R,1);

            slope_vec = nan(R,1);

            v_cells         = cell(R,1);
            Y_cells         = cell(R,1);

            for r = 1:R
                rid = path_ids(r);

                %% ---- SoS 结果：Q_* ----
                if ~isnan(rid) && isKey(row_map, rid)
                    s = info_col{ row_map(rid) };

                    if isfield(s,'Q_MOMMA') && ~isempty(s.Q_MOMMA)
                        momma_cells{r} = s.Q_MOMMA;
                    end
                    if isfield(s,'Q_SIC4DVar') && ~isempty(s.Q_SIC4DVar)
                        sic4dvar_cells{r} = s.Q_SIC4DVar;
                    end
                    if isfield(s,'Q_geoBAM') && ~isempty(s.Q_geoBAM)
                        geobam_cells{r} = s.Q_geoBAM;
                    end
                    if isfield(s,'Q_SADS') && ~isempty(s.Q_SADS)
                        sads_cells{r} = s.Q_SADS;
                    end
                    if isfield(s,'Q_MetroMan') && ~isempty(s.Q_MetroMan)
                        metroman_cells{r} = s.Q_MetroMan;
                    end
                    % MOMMA velocity
                    if isfield(s,'v') && ~isempty(s.v)
                        v_cells{r} = s.v;
                    elseif isfield(s,'v_MOMMA') && ~isempty(s.v_MOMMA)
                        v_cells{r} = s.v_MOMMA;
                    end

                    % MOMMA depth
                    if isfield(s,'Y') && ~isempty(s.Y)
                        Y_cells{r} = s.Y;
                    elseif isfield(s,'Y_MOMMA') && ~isempty(s.Y_MOMMA)
                        Y_cells{r} = s.Y_MOMMA;
                    end
                end

                %% ---- IRIS slope ----
                if ~isnan(rid) && isKey(iris_map, rid)
                    slope_vec(r) = iris_map(rid);
                end
            end

            % ---- path 级：如果这一条 path 上该方法完全没有数据，就压成 [] ----
            if all(cellfun(@isempty, momma_cells)),     momma_cells    = []; end
            if all(cellfun(@isempty, sic4dvar_cells)),  sic4dvar_cells = []; end
            if all(cellfun(@isempty, geobam_cells)),    geobam_cells   = []; end
            if all(cellfun(@isempty, sads_cells)),      sads_cells      = []; end
            if all(cellfun(@isempty, metroman_cells)),  metroman_cells = []; end


            if all(cellfun(@isempty, v_cells)),         v_cells        = []; end
            if all(cellfun(@isempty, Y_cells)),         Y_cells        = []; end

            basins(b).Q_MOMMA{p}     = momma_cells;
            basins(b).Q_SIC4DVar{p}  = sic4dvar_cells;
            basins(b).Q_geoBAM{p}    = geobam_cells;
            basins(b).Q_SADS{p}       = sads_cells;
            basins(b).Q_MetroMan{p}  = metroman_cells;

            basins(b).v_MOMMA{p}     = v_cells;
            basins(b).Y_MOMMA{p}     = Y_cells;

            %% ---- IRIS slope：linear 插值，nearest 外推；且 slope==0 当作缺失 ----
            if ~isfield(basins(b),'position') || numel(basins(b).position) < p
                error('basins(%d) 缺少 position{%d} 字段。', b, p);
            end
            pos = to_double_vec(basins(b).position{p});
            if numel(pos) ~= R
                error('basins(%d).paths{%d} 与 position{%d} 长度不一致。', b, p, p);
            end

            slope_vec(slope_vec == 0) = NaN;
            is_raw = ~isnan(slope_vec) & ~isnan(pos);

            if nnz(is_raw) == 0
                basins(b).slope_IRIS{p} = [];
            elseif nnz(is_raw) == 1
                c = slope_vec(find(is_raw,1,'first'));
                slope_filled = repmat(c, R, 1);
                basins(b).slope_IRIS{p} = [slope_filled, double(is_raw)];
            else
                slope_filled = interp1(pos(is_raw), slope_vec(is_raw), pos, 'linear', NaN);

                first_idx = find(is_raw, 1, 'first');
                last_idx  = find(is_raw, 1, 'last');

                left_of  = pos < pos(first_idx);
                right_of = pos > pos(last_idx);

                slope_filled(left_of)  = slope_vec(first_idx);
                slope_filled(right_of) = slope_vec(last_idx);

                basins(b).slope_IRIS{p} = [slope_filled, double(is_raw)];
            end
        end

        % ---- 字段级：如果所有 path 都是空，直接设为 [] ----
        basins(b).Q_MOMMA     = squash_cell_if_all_empty(basins(b).Q_MOMMA);
        basins(b).Q_SIC4DVar  = squash_cell_if_all_empty(basins(b).Q_SIC4DVar);
        basins(b).Q_geoBAM    = squash_cell_if_all_empty(basins(b).Q_geoBAM);
        basins(b).Q_SADS       = squash_cell_if_all_empty(basins(b).Q_SADS);
        basins(b).Q_MetroMan  = squash_cell_if_all_empty(basins(b).Q_MetroMan);
        basins(b).slope_IRIS  = squash_cell_if_all_empty(basins(b).slope_IRIS);
        basins(b).v_MOMMA     = squash_cell_if_all_empty(basins(b).v_MOMMA);
        basins(b).Y_MOMMA     = squash_cell_if_all_empty(basins(b).Y_MOMMA);
    end
end

%% --------- 工具函数 ---------
function v = to_double_vec(x)
    if isnumeric(x)
        v = double(x(:));
    elseif isstring(x)
        v = double(str2double(x(:)));
    elseif iscell(x)
        v = nan(numel(x),1);
        for k = 1:numel(x)
            v(k) = str2double(string(x{k}));
        end
    elseif ischar(x)
        v = double(str2double(string(x)));
    else
        v = double(str2double(string(x(:))));
    end
end

function out = squash_cell_if_all_empty(c)
    if ~iscell(c), out = c; return; end
    if isempty(c), out = []; return; end
    if numel(c) == 1 && isempty(c{1}), out = []; return; end
    if all(cellfun(@isempty, c(:))), out = []; return; end
    out = c;
end