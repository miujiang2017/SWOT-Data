function cfg = defaultConfig()
%DEFAULTCONFIG Return the default legacy-compatible SWOT discharge config.

thisFile = mfilename('fullpath');
configDir = fileparts(thisFile);
packageDir = fileparts(configDir);
devSetDir = fileparts(packageDir);
repoDataDir = fileparts(devSetDir);

cfg = struct();

cfg.paths.devSetDir = devSetDir;
cfg.paths.riverSpDir = fullfile(repoDataDir, 'RiverSP');
cfg.paths.swordDir = fullfile(repoDataDir, 'SWORD V16');
cfg.paths.sosDir = fullfile(repoDataDir, 'SoS');
cfg.paths.sosDatasetDir = fullfile(cfg.paths.sosDir, 'SoS Dataset Oct');

cfg.data.filePrefix = 'na';
cfg.data.sosType = 'uncon';
cfg.data.irisFile = 'IRIS_2.9.nc';
cfg.data.useSvs = true;
cfg.data.filterBasinsOption = 2;

cfg.dates.startDate = '2023-03-29';
cfg.dates.endDate = '2025-05-02';

cfg.kf.stateEp = 22;
cfg.kf.observationProducts = 1; % 1=SIC4DVar, 2=MOMMA, 3=geoBAM, 4=MetroMan, 5=SADS.
cfg.kf.initialStateMode = 'zero_anomaly';
cfg.kf.buildMissingPhiQ = true;

% Match the active loop in legacy main.m by default. Set both to [] for all.
cfg.execution.basinIndices = 5;
cfg.execution.pathIndices = 1;

cfg.cache.preferBasinsOutCache = true;
cfg.cache.basinsOutFiles = arrayfun(@(i) sprintf('basinsv16_%d.mat', i), 1:6, 'UniformOutput', false);
cfg.cache.phiFile = 'Phi_save.mat';
cfg.cache.qFile = 'Q_save.mat';

cfg.validation.enabled = true;
cfg.validation.functionName = 'validation3';

cfg.plots.enabled = false;
cfg.plots.timeseries = true;
cfg.plots.maps = true;
cfg.plots.relativeErrorCdf = true;
cfg.plots.metricBarplot = true;
cfg.plots.reachesMap = true;
cfg.plots.improvementBoxchart = true;

cfg.output.saveResults = true;
cfg.output.resultsFile = 'Q_results_refactored.mat';
end
