function SoS_PriorsData_v16 = SoS_PriorsData_map_v17b_to_v16(SoS_PriorsData, file_prefix)
%！！！！ 改改改
% SoS_PriorsData_map_v17b_to_v16
% 将 SoS_PriorsData.reach_id (v17b) 转换为 v16
%
% 逻辑：
%   1) 先调用 SWORD_translate 做 v17b → v16 映射
%   2) 若映射失败 (NaN)
%        - 若该 ID 本身存在于 v16 的 nc 文件中 → 保留原 ID
%        - 否则 → 设为 NaN
%
% 输入:
%   SoS_PriorsData : struct，含 reach_id
%   file_prefix    : 如 'na','eu','af' 等（用于读取 v16 nc 文件）
%
% 输出:
%   SoS_PriorsData_v16 : 同结构，reach_id 已转换

    if ~isstruct(SoS_PriorsData) || ~isfield(SoS_PriorsData,'reach_id')
        error('Input must be SoS_PriorsData struct with field reach_id.');
    end

    %% ---------- 读取 v16 nc 文件 ----------
    addpath(fullfile(pwd, '..', 'SWORD V16'));
    baseDir = 'SWORD V16';
    ncfile = fullfile(pwd, '..', baseDir, sprintf('%s_sword_v16.nc', file_prefix));

    if ~isfile(ncfile)
        error('v16 nc file not found: %s', ncfile);
    end

    fprintf('Reading v16 reach IDs from %s ...\n', ncfile);
    reach_id_v16_all = ncread(ncfile,'/reaches/reach_id');
    reach_id_v16_all = double(reach_id_v16_all(:));  % 确保是 double 列向量

    %% ---------- 开始转换 ----------
    SoS_PriorsData_v16 = SoS_PriorsData;
    n = numel(SoS_PriorsData);

    fprintf('Translating %d reach IDs (v17b → v16)...\n', n);

    n_fallback = 0;
    n_missing  = 0;
    for i = 1:n

        id17 = SoS_PriorsData(i).reach_id;

        if isnan(id17)
            SoS_PriorsData_v16(i).reach_id = NaN;
            continue;
        end

        try
            out = SWORD_translate(id17, 'v17b');
            id16 = out.v16_id;

            if ~isnan(id16)
                % 正常映射成功
                SoS_PriorsData_v16(i).reach_id = id16;

            else
                % 映射失败 → 检查是否本身存在于 v16 文件中
                if any(reach_id_v16_all == id17)
                    SoS_PriorsData_v16(i).reach_id = id17;
                    n_fallback = n_fallback + 1;
                else
                    SoS_PriorsData_v16(i).reach_id = NaN;
                    n_missing = n_missing + 1;
                end
            end

        catch ME
            warning('Failed at index %d (ID=%g): %s', i, id17, ME.message);
            SoS_PriorsData_v16(i).reach_id = NaN;
            n_missing = n_missing + 1;
        end

        if mod(i,1000)==0
            fprintf('  %d / %d done\n', i, n);
        end

    end

    fprintf('Done.\n');
    fprintf('Fallback used (ID already in v16): %d\n', n_fallback);
    fprintf('Still missing (set to NaN): %d\n', n_missing);

end