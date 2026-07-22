function runOut = runExperiment(cfg)
%RUNEXPERIMENT Run the configured SWOT discharge pipeline.

arguments
    cfg (1,1) struct
end

swot.pipeline.setupPaths(cfg);
prepared = swot.pipeline.prepareData(cfg);
Q_results = swot.pipeline.runEstimator(prepared.data_KF_out, cfg);

if cfg.plots.enabled
    swot.pipeline.plotResults(Q_results, prepared.data_KF_out, cfg);
end

runOut = prepared;
runOut.Q_results = Q_results;
end
