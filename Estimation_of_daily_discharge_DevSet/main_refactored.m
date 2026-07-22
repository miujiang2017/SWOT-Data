clearvars
close all
clc

cfg = swot.config.defaultConfig();
runOut = swot.pipeline.runExperiment(cfg);

Q_results = runOut.Q_results;
data_KF_out = runOut.data_KF_out;
start_date = cfg.dates.startDate;
file_prefix = cfg.data.filePrefix;

if cfg.output.saveResults
    save(cfg.output.resultsFile, 'Q_results', 'data_KF_out', 'start_date', 'file_prefix', 'cfg', '-v7.3');
end
