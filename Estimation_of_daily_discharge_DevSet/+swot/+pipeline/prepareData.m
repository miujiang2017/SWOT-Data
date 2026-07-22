function prepared = prepareData(cfg)
%PREPAREDATA Load or build the basin/path data used by the Kalman filter.

arguments
    cfg (1,1) struct
end

oldPwd = pwd;
cleanup = onCleanup(@() cd(oldPwd));
cd(cfg.paths.devSetDir);

basins = [];
SoS_PriorsData_v16 = [];
SoS_ResultsData = [];
obsPercent = [];
k = [];

if cfg.cache.preferBasinsOutCache && swot.cache.hasBasinsOutCache(cfg)
    basins_out = swot.cache.loadBasinsOutCache(cfg);
else
    [basins, SoS_PriorsData_v16, SoS_ResultsData, obsPercent, k] = buildBasinsFromSource(cfg);
    basins_out = filter_basins(basins, cfg.data.filterBasinsOption);
    if swot.cache.hasBasinsOutCache(cfg)
        basins_old = swot.cache.loadBasinsOutCache(cfg);
        basins_out = add_RiverSP_ReachData_to_basins_with_old( ...
            basins_out, basins_old, cfg.dates.startDate, cfg.dates.endDate);
    else
        basins_out = add_RiverSP_ReachData_to_basins( ...
            basins_out, cfg.dates.startDate, cfg.dates.endDate);
    end
end

data_KF = data_for_KF(basins_out, cfg.dates.startDate, cfg.dates.endDate, cfg.kf.stateEp);
data_KF_out = filter_KF(data_KF);
data_KF_out = build_cDtau(data_KF_out);

prepared = struct();
prepared.basins = basins;
prepared.basins_out = basins_out;
prepared.data_KF_out = data_KF_out;
prepared.SoS_PriorsData_v16 = SoS_PriorsData_v16;
prepared.SoS_ResultsData = SoS_ResultsData;
prepared.obsPercent = obsPercent;
prepared.k = k;
end

function [basins, priorsData, resultsData, obsPercent, k] = buildBasinsFromSource(cfg)
priorsData = read_SoS_Priorsv005(cfg.paths.sosDatasetDir, cfg.data.filePrefix, 16);
basins = enumerate_subset_paths_by_basin(priorsData, cfg.data.filePrefix);
basins = add_SoS_priors_to_basins(basins, priorsData);
basins = add_SVS_gauge_to_basins(basins, cfg.data.svsFile);

resultsData = read_SoS_Resultsv005(cfg.paths.sosDatasetDir, cfg.data.filePrefix, cfg.data.sosType);
basins = add_SoS_results_to_basins(basins, resultsData, cfg.data.irisFile);

obsPercent = obs_percent(basins, cfg.data.useSvs);
[k, ~] = compute_k(basins);
end
