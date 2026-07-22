function basins = add_SVS_gauge_to_basins2(basins, file_prefix, svs_ncfile)
% add_SVS_gauge_to_basins2
%
% 逻辑：
%   1) 读取 SVS_v1_0_1.nc
%   2) SVS 里的 reach id 默认当作全球 v17b reach id
%   3) 读取 ../SWORD V16/<file_prefix>_ReachIDs_v17b_vs_v16.csv
%   4) 只使用该区域的 CSV 映射，比如 NA:
%        v17_reach_id -> v16_reach_id
%   5) 若 CSV 找不到，但该 ID 本身存在于该区域 SWORD v16 nc 中，
%        则 fallback 保留原 ID
%   6) 其他大洲 ID 直接跳过
%   7) 用转换后的区域 v16 id 去匹配 basins.paths 里的 v16 id
%
% 输入：
%   basins      : struct，包含 n_paths 和 paths
%   file_prefix : 区域前缀，例如 'na'。默认 'na'
%
% 输出：
%   basins(i).Q_SVS{p}{r} = [time_datenum, Q(:, idx)]
%   找不到则为 []

    if nargin < 2 || isempty(file_prefix)
        file_prefix = 'na';
    end

    %% ---------- 路径设置 ----------
    addpath(fullfile(pwd, '..', 'SWORD V16'));
    baseDir = 'SWORD V16';

    %% ---------- 读取 SVS 文件 ----------
    if nargin < 3 || isempty(svs_ncfile)
        svs_ncfile = default_svs_file();
    end

    if ~isfile(svs_ncfile)
        error('SVS nc file not found: %s', svs_ncfile);
    end

    time = ncread(svs_ncfile, 'time');
    Q = ncread(svs_ncfile, 'Q');

    % 注意：
    % 虽然 SVS 文件里的变量名可能叫 reach_id_v16，
    % 但这里按你的判断，把它当作 v17b reach id 使用。
    reach_id_svs_raw = ncread(svs_ncfile, 'reach_id_v16');
    reach_id_svs_raw = double(reach_id_svs_raw(:));

    time_origin = datenum(2023, 1, 1);
    time_datenum = time_origin + double(time(:));

    %% ---------- 读取区域 SWORD v16 reach_id，用于 fallback ----------
    sword_v16_nc = fullfile(pwd, '..', baseDir, sprintf('%s_sword_v16.nc', file_prefix));

    if ~isfile(sword_v16_nc)
        error('v16 nc file not found: %s', sword_v16_nc);
    end

    fprintf('Reading %s v16 reach IDs from %s ...\n', upper(file_prefix), sword_v16_nc);
    reach_id_v16_all = ncread(sword_v16_nc, '/reaches/reach_id');
    reach_id_v16_all = double(reach_id_v16_all(:));

    %% ---------- 读取区域 v17b -> v16 映射表 ----------
    mapfile = fullfile(pwd, '..', baseDir, sprintf('%s_ReachIDs_v17b_vs_v16.csv', file_prefix));

    if ~isfile(mapfile)
        error('Mapping csv file not found: %s', mapfile);
    end

    fprintf('Reading %s v17b-v16 mapping from %s ...\n', upper(file_prefix), mapfile);

    % 使用 preserve 避免 MATLAB 自动改列名产生 warning。
    % 但后面直接用第 1、2 列，不依赖列名。
    T = readtable(mapfile, 'VariableNamingRule', 'preserve');

    if width(T) < 2
        error('Mapping CSV must have at least two columns: v17_reach_id and v16_reach_id.');
    end

    % 根据你的 CSV：
    %   第 1 列是 v17_reach_id
    %   第 2 列是 v16_reach_id
    reach_id_map_v17b = double(T{:, 1});
    reach_id_map_v16  = double(T{:, 2});

    reach_id_map_v17b = reach_id_map_v17b(:);
    reach_id_map_v16  = reach_id_map_v16(:);

    %% ---------- 将 SVS 全球 reach id 映射到该区域 v16 ----------
    fprintf('Mapping global SVS reach IDs to %s v16 using regional CSV...\n', upper(file_prefix));

    reach_id_svs_v16 = NaN(size(reach_id_svs_raw));

    n_mapped = 0;
    n_fallback_v16 = 0;
    n_outside_region = 0;
    n_multi = 0;

    for k = 1:numel(reach_id_svs_raw)

        id_raw = reach_id_svs_raw(k);

        if isnan(id_raw)
            n_outside_region = n_outside_region + 1;
            continue;
        end

        % 1) 先查区域 v17b -> v16 CSV
        idx = find(reach_id_map_v17b == id_raw);

        if ~isempty(idx)

            if numel(idx) > 1
                n_multi = n_multi + 1;
            end

            id16 = reach_id_map_v16(idx(1));

            if ~isnan(id16)
                reach_id_svs_v16(k) = id16;
                n_mapped = n_mapped + 1;
            else
                reach_id_svs_v16(k) = NaN;
                n_outside_region = n_outside_region + 1;
            end

        else
            % 2) 如果 CSV 找不到，检查是否本身就是该区域 v16 ID
            if any(reach_id_v16_all == id_raw)
                reach_id_svs_v16(k) = id_raw;
                n_fallback_v16 = n_fallback_v16 + 1;
            else
                % 3) 既不在区域 CSV，也不在区域 v16，视为其他大洲或无效 ID
                reach_id_svs_v16(k) = NaN;
                n_outside_region = n_outside_region + 1;
            end
        end

        if mod(k, 1000) == 0
            fprintf('  checked %d / %d SVS reach IDs\n', k, numel(reach_id_svs_raw));
        end
    end

    fprintf('SVS regional ID mapping done.\n');
    fprintf('Mapped %s v17b -> v16 from CSV: %d\n', upper(file_prefix), n_mapped);
    fprintf('Fallback already %s v16: %d\n', upper(file_prefix), n_fallback_v16);
    fprintf('Outside %s / not usable for these basins: %d\n', upper(file_prefix), n_outside_region);
    fprintf('Multiple matches in CSV, first used: %d\n', n_multi);

    %% ---------- 建立 SVS v16 reach id 到 Q 列的索引 ----------
    valid = ~isnan(reach_id_svs_v16);

    reach_id_svs_v16_valid = reach_id_svs_v16(valid);
    svs_col_idx_valid = find(valid);

    % 多个 SVS gauge 映射到同一个 v16 reach 时，先取第一个
    [reach_id_svs_v16_unique, ia] = unique(reach_id_svs_v16_valid, 'stable');
    first_svs_col_idx = svs_col_idx_valid(ia);

    fprintf('Valid regional SVS IDs after mapping/fallback: %d\n', numel(reach_id_svs_v16_valid));
    fprintf('Unique regional SVS v16 IDs: %d\n', numel(reach_id_svs_v16_unique));

    %% ---------- 给 basins 添加 Q_SVS ----------
    n_found_svs = 0;
    n_missing_svs = 0;

    for i = 1:length(basins)

        basins(i).Q_SVS = cell(basins(i).n_paths, 1);

        for p = 1:basins(i).n_paths

            path_reaches = basins(i).paths{p};

            if iscell(path_reaches)
                path_reaches = cellfun(@str2double, path_reaches);

            elseif isstring(path_reaches)
                path_reaches = str2double(path_reaches);

            elseif ischar(path_reaches)
                path_reaches = str2double(string(path_reaches));

            else
                path_reaches = double(path_reaches);
            end

            path_reaches = double(path_reaches(:));

            n_reaches = length(path_reaches);
            basins(i).Q_SVS{p, 1} = cell(n_reaches, 1);

            for r = 1:n_reaches

                % 假设 basins.paths 里的 reach id 是该区域 v16 ID
                reach_id_v16 = path_reaches(r);

                if isnan(reach_id_v16)
                    basins(i).Q_SVS{p, 1}{r, 1} = [];
                    continue;
                end

                [tf, loc] = ismember(reach_id_v16, reach_id_svs_v16_unique);

                if ~tf
                    basins(i).Q_SVS{p, 1}{r, 1} = [];
                    n_missing_svs = n_missing_svs + 1;
                else
                    idx = first_svs_col_idx(loc);
                    basins(i).Q_SVS{p, 1}{r, 1} = [time_datenum, Q(:, idx)];
                    n_found_svs = n_found_svs + 1;
                end

            end
        end
    end

    fprintf('Done adding SVS Q to basins.\n');
    fprintf('Basin reaches found in mapped regional SVS v16 IDs: %d\n', n_found_svs);
    fprintf('Basin reaches not found in mapped regional SVS v16 IDs: %d\n', n_missing_svs);

end

function ncfile = default_svs_file()
devSetDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
candidate = fullfile(devSetDir, 'data', 'static_nc', 'SVS_v1_0_1.nc');
if isfile(candidate)
    ncfile = candidate;
else
    ncfile = 'SVS_v1_0_1.nc';
end
end
