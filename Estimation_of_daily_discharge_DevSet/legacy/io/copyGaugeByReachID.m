function SoS_PriorsData_v16 = copyGaugeByReachID(SoS_PriorsData_v16, SoS_PriorsData_v17,file_prefix)
% copyGaugeByReachID
%
% 按 reach_id 匹配，将 v17 中的水文相关字段复制到 v16。
%
% 注意：
%   SoS_PriorsData_v17.reach_id 是 v17b / v17
%   SoS_PriorsData_v16.reach_id 是 v16
%
% 所以要先读取 NA_ReachIDs_v17b_vs_v16.csv：
%   v17_reach_id -> v16_reach_id
%
% 再用映射后的 v16 id 去匹配 SoS_PriorsData_v16.reach_id。

    fieldsToCopy = {'USGS_q','USGS_qt','WSC_q','WSC_qt','MEFCCWP_q','MEFCCWP_qt'};

    %% ---------- 基本检查 ----------
    if ~isstruct(SoS_PriorsData_v16) || ~isstruct(SoS_PriorsData_v17)
        error('输入必须是 struct array。');
    end

    if ~isfield(SoS_PriorsData_v16, 'reach_id') || ~isfield(SoS_PriorsData_v17, 'reach_id')
        error('v16 和 v17 都必须包含 reach_id 字段。');
    end

    %% ---------- 读取 SWORD v16，确认 v16 ID ----------
    addpath(fullfile(pwd, '..', 'SWORD V16'));
    baseDir = 'SWORD V16';
    ncfile = fullfile(pwd, '..', baseDir, 'na_sword_v16.nc');

    if ~isfile(ncfile)
        error('v16 nc file not found: %s', ncfile);
    end

   % fprintf('Reading v16 reach IDs from %s ...\n', ncfile);
    reach_id_v16_all = ncread(ncfile, '/reaches/reach_id');
    reach_id_v16_all = double(reach_id_v16_all(:));

    %% ---------- 读取 v17 -> v16 映射表 ----------
    addpath(fullfile(pwd, '..', 'SWORD V16'));
    baseDir = 'SWORD V16';
    mapfile = fullfile(pwd, '..', baseDir, sprintf('%s_ReachIDs_v17b_vs_v16.csv', file_prefix));
    if ~isfile(mapfile)
        error('Mapping csv file not found: %s', mapfile);
    end

    fprintf('Reading mapping table from %s ...\n', mapfile);
    T = readtable(mapfile,'VariableNamingRule','preserve');

    % 你的表里列名就是这两个
    if ~ismember('v17_reach_id', T.Properties.VariableNames) || ...
       ~ismember('v16_reach_id', T.Properties.VariableNames)
        error('CSV must contain columns: v17_reach_id and v16_reach_id');
    end

    map_v17 = double(T.v17_reach_id(:));
    map_v16 = double(T.v16_reach_id(:));

    %% ---------- 将 SoS_PriorsData_v17.reach_id 映射到 v16 ----------
    reach17_raw = double([SoS_PriorsData_v17.reach_id]);
    reach17_as_v16 = NaN(size(reach17_raw));

    n_mapped = 0;
    n_fallback_v16 = 0;
    n_missing = 0;
    n_multi = 0;

   % fprintf('Mapping v17 reach_id to v16 using CSV...\n');

    for i = 1:numel(reach17_raw)

        id17 = reach17_raw(i);

        if isnan(id17)
            n_missing = n_missing + 1;
            continue;
        end

        idx = find(map_v17 == id17);

        if ~isempty(idx)

            if numel(idx) > 1
                n_multi = n_multi + 1;
            end

            id16 = map_v16(idx(1));

            if ~isnan(id16)
                reach17_as_v16(i) = id16;
                n_mapped = n_mapped + 1;
            else
                n_missing = n_missing + 1;
            end

        else
            % 如果在映射表找不到，检查它是不是本来就是 v16
            if any(reach_id_v16_all == id17)
                reach17_as_v16(i) = id17;
                n_fallback_v16 = n_fallback_v16 + 1;
            else
                reach17_as_v16(i) = NaN;
                n_missing = n_missing + 1;
            end
        end

        % if mod(i, 1000) == 0
        %     fprintf('  mapped %d / %d records\n', i, numel(reach17_raw));
        % end
    end

    %fprintf('Mapping done.\n');
   % fprintf('Mapped from CSV: %d\n', n_mapped);
   % fprintf('Fallback already v16: %d\n', n_fallback_v16);
   % fprintf('Missing after mapping: %d\n', n_missing);
  %  fprintf('Multiple CSV matches, first used: %d\n', n_multi);

    %% ---------- 检查 v17 是否有要复制的字段 ----------
    existingFields = fields(SoS_PriorsData_v17);
    missingFields = fieldsToCopy(~ismember(fieldsToCopy, existingFields));

    if ~isempty(missingFields)
        warning('v17 中缺少这些字段，已跳过: %s', strjoin(missingFields, ', '));
    end

    validFields = fieldsToCopy(ismember(fieldsToCopy, existingFields));

    %% ---------- 用映射后的 v16 ID 匹配并复制 ----------
    reach16 = double([SoS_PriorsData_v16.reach_id]);

    validMap = ~isnan(reach17_as_v16);
    reach17_mapped_valid = reach17_as_v16(validMap);
    idx17_valid = find(validMap);

    [commonReach, idx16, idx17_local] = intersect(reach16, reach17_mapped_valid, 'stable');
    idx17 = idx17_valid(idx17_local);
%
    fprintf('Matched %d reach_id values after v17 -> v16 mapping.\n', numel(commonReach));

    for k = 1:numel(idx16)

        i16 = idx16(k);
        i17 = idx17(k);

        for f = 1:numel(validFields)
            fname = validFields{f};
            SoS_PriorsData_v16(i16).(fname) = SoS_PriorsData_v17(i17).(fname);
        end
    end

    fprintf('Copied %d fields to %d matched records.\n', numel(validFields), numel(idx16));
fprintf('Mapped from CSV: %d\n', n_mapped);
fprintf('Fallback already v16: %d\n', n_fallback_v16);
fprintf('Missing after mapping: %d\n', n_missing);
fprintf('Multiple CSV matches, first used: %d\n', n_multi);

fprintf('Total v17 records: %d\n', numel(reach17_raw));
fprintf('Valid mapped/fallback v16 IDs: %d\n', sum(~isnan(reach17_as_v16)));
fprintf('Unique mapped/fallback v16 IDs: %d\n', numel(unique(reach17_as_v16(~isnan(reach17_as_v16)))));
fprintf('Total v16 records: %d\n', numel(reach16));
fprintf('Matched copied records: %d\n', numel(idx16));
end