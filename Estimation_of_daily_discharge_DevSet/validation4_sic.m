function [vali_estmed, ...
          vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
          vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
          vali_SADS_interp, vali_MetroMan_interp] = ...
          validation4_sic(Qest_med, sg_path, nR, use_svs)
% VALIDATION4_SIC: SIC4DVar-only path-start validation.
%
% 逻辑：
%   1. 只用 day_index_SIC4DVar 判断 validation 起始日期；
%   2. 起始日期按整个 path 统一判断，即 path 内最早 SIC4DVar measurement；
%   3. 只输出 SIC4DVar / SIC4DVar_interp 的产品 validation；
%   4. MOMMA / geoBAM / SADS / MetroMan 的 validation 结果全部为 NaN。
%
% 说明：
%   这里复用 validation4 的计算逻辑，但调用前临时移除非 SIC 产品字段，
%   因此 validation4 只能看到 SIC4DVar。

non_sic_fields = { ...
    'Q_MOMMA', 'day_index_MOMMA', ...
    'Q_geoBAM', 'day_index_geoBAM', ...
    'Q_SADS', 'day_index_SADS', ...
    'Q_MetroMan', 'day_index_MetroMan'};

sg_path_sic = rmfield_if_exists(sg_path, non_sic_fields);

[vali_estmed, ...
    vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
    vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
    vali_SADS_interp, vali_MetroMan_interp] = ...
    validation4(Qest_med, sg_path_sic, nR, use_svs);

end


function s = rmfield_if_exists(s, fields_to_remove)

for i = 1:numel(fields_to_remove)
    fld = fields_to_remove{i};
    if isfield(s, fld)
        s = rmfield(s, fld);
    end
end

end
