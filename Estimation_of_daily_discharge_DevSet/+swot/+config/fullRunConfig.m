function cfg = fullRunConfig()
%FULLRUNCONFIG Return a config that runs every available basin/path.

cfg = swot.config.defaultConfig();
cfg.execution.basinIndices = [];
cfg.execution.pathIndices = [];
cfg.plots.enabled = true;
cfg.output.resultsFile = 'Q_results_refactored_full.mat';
end
