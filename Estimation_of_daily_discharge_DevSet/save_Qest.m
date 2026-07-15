function Q_results = save_Qest(Q_results, ib, p, ...
    Qest_med, ...
    vali_estmed, ...
    vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
    vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
    vali_SADS_interp, vali_MetroMan_interp)
% SAVE_QEST  按 basin/path 保存 Q 估计结果和所有 validation 结构（扩展到 5 个产品）
%
% 输入：
%   Q_results  : 之前的结果（初次可传 []）
%   ib, p      : basin index、path index
%   Qest_med   : KF 中位数估计
%
%   vali_* 系列：全是结构体，包含 corr/nRMSE/NSE/rB（nR×1）
%
% 输出：
%   Q_results(ib).FIELD{p}，其中 FIELD 包含：
%      Qest_med
%      vali_estmed
%      vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan
%      以及对应的 *_interp

    %% ===== 1. 确保 Q_results 至少有 ib 个元素 =====
    if isempty(Q_results)
        Q_results = struct();
    end

    if numel(Q_results) < ib
        for k = numel(Q_results)+1 : ib
            Q_results(k).Qest_med               = {};
            Q_results(k).vali_estmed            = {};

            Q_results(k).vali_SIC4DVar          = {};
            Q_results(k).vali_MOMMA             = {};
            Q_results(k).vali_geoBAM            = {};
            Q_results(k).vali_SADS              = {};
            Q_results(k).vali_MetroMan          = {};

            Q_results(k).vali_SIC4DVar_interp   = {};
            Q_results(k).vali_MOMMA_interp      = {};
            Q_results(k).vali_geoBAM_interp     = {};
            Q_results(k).vali_SADS_interp       = {};
            Q_results(k).vali_MetroMan_interp   = {};
        end
    end

    %% ===== 2. 确保所有字段都存在（兼容旧版本） =====
    all_fields = {
        'Qest_med', ...
        'vali_estmed', ...
        'vali_SIC4DVar','vali_MOMMA','vali_geoBAM','vali_SADS','vali_MetroMan', ...
        'vali_SIC4DVar_interp','vali_MOMMA_interp','vali_geoBAM_interp','vali_SADS_interp','vali_MetroMan_interp'
    };

    for f = 1:numel(all_fields)
        fld = all_fields{f};
        if ~isfield(Q_results, fld)
            for k = 1:numel(Q_results)
                Q_results(k).(fld) = {};
            end
        end
    end

    %% ===== 3. 确保 ib 的字段 cell 长度至少到 p =====
    for f = 1:numel(all_fields)
        fld = all_fields{f};
        cur = Q_results(ib).(fld);

        if isempty(cur)
            Q_results(ib).(fld) = cell(1,p);
        elseif numel(cur) < p
            Q_results(ib).(fld){p} = [];
        end
    end

    %% ===== 4. 赋值（按 basin/path） =====
    Q_results(ib).Qest_med{p} = Qest_med;

    Q_results(ib).vali_estmed{p}          = vali_estmed;

    Q_results(ib).vali_SIC4DVar{p}        = vali_SIC4DVar;
    Q_results(ib).vali_MOMMA{p}           = vali_MOMMA;
    Q_results(ib).vali_geoBAM{p}          = vali_geoBAM;
    Q_results(ib).vali_SADS{p}            = vali_SADS;
    Q_results(ib).vali_MetroMan{p}        = vali_MetroMan;

    Q_results(ib).vali_SIC4DVar_interp{p} = vali_SIC4DVar_interp;
    Q_results(ib).vali_MOMMA_interp{p}    = vali_MOMMA_interp;
    Q_results(ib).vali_geoBAM_interp{p}   = vali_geoBAM_interp;
    Q_results(ib).vali_SADS_interp{p}     = vali_SADS_interp;
    Q_results(ib).vali_MetroMan_interp{p} = vali_MetroMan_interp;

end