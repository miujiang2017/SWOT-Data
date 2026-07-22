function Q_results = runEstimator(data_KF_out, cfg)
%RUNESTIMATOR Run the configured Kalman estimator for selected basin paths.

arguments
    data_KF_out (1,:) struct
    cfg (1,1) struct
end

oldPwd = pwd;
cleanup = onCleanup(@() cd(oldPwd));
cd(cfg.paths.devSetDir);

[Phi_save, Q_save] = swot.cache.loadPhiQ(cfg);
nt = datenum(cfg.dates.endDate) - datenum(cfg.dates.startDate) + 1;
basinIdx = swot.utils.resolveIndices(cfg.execution.basinIndices, numel(data_KF_out));

Q_results = [];
for ib = basinIdx
    fprintf('Basin %d\n', ib);
    sg_basin = data_KF_out(ib);
    pathIdx = swot.utils.resolveIndices(cfg.execution.pathIndices, numel(sg_basin.paths));

    for ip = pathIdx
        sg_path = swot.utils.getPathStruct(sg_basin, ip);
        nR = length(sg_path.rch_len{1});
        [Phi_st, Q_st] = resolvePhiQ(sg_path, Phi_save, Q_save, ib, ip, cfg);

        Qest_med = swot.filter.runPathKalman(sg_path, Phi_st, Q_st, nR, nt, cfg);
        if cfg.validation.enabled
            validationOut = swot.pipeline.validatePath(Qest_med, sg_path, nR, cfg);
            Q_results = save_Qest(Q_results, ib, ip, Qest_med, ...
                validationOut.vali_estmed, ...
                validationOut.vali_SIC4DVar, validationOut.vali_MOMMA, ...
                validationOut.vali_geoBAM, validationOut.vali_SADS, ...
                validationOut.vali_MetroMan, validationOut.vali_SIC4DVar_interp, ...
                validationOut.vali_MOMMA_interp, validationOut.vali_geoBAM_interp, ...
                validationOut.vali_SADS_interp, validationOut.vali_MetroMan_interp);
        else
            Q_results = save_Qest(Q_results, ib, ip, Qest_med, ...
                struct(), struct(), struct(), struct(), struct(), struct(), ...
                struct(), struct(), struct(), struct(), struct());
        end
    end
end
end

function [Phi_st, Q_st] = resolvePhiQ(sg_path, Phi_save, Q_save, ib, ip, cfg)
hasCached = numel(Phi_save) >= ib && numel(Q_save) >= ib && ...
    numel(Phi_save{ib}) >= ip && numel(Q_save{ib}) >= ip && ...
    ~isempty(Phi_save{ib}{ip}) && ~isempty(Q_save{ib}{ip});

if hasCached
    Phi_st = Phi_save{ib}{ip};
    Q_st = Q_save{ib}{ip};
    return
end

if ~cfg.kf.buildMissingPhiQ
    error('Missing cached Phi/Q for basin %d path %d.', ib, ip);
end

[Phi_st, Q_st] = build_Phi_SWOT(sg_path, cfg.kf.stateEp);
end
