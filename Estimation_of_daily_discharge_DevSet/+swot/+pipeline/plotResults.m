function plotResults(Q_results, data_KF_out, cfg)
%PLOTRESULTS Run configured plots for Q estimation outputs.

arguments
    Q_results
    data_KF_out (1,:) struct
    cfg (1,1) struct
end

if cfg.plots.timeseries
    plot_timeseries(Q_results, data_KF_out, cfg.dates.startDate);
end
if cfg.plots.maps
    plot_all_metrics_on_map(data_KF_out, Q_results, cfg.data.filePrefix);
end
if cfg.plots.relativeErrorCdf
    plot_reach_relative_error_cdf(Q_results, data_KF_out, cfg.dates.startDate);
end
if cfg.plots.metricBarplot
    plot_reach_metric_barplot(Q_results, data_KF_out);
end
if cfg.plots.reachesMap
    plot_reaches_on_map(data_KF_out, cfg.data.filePrefix);
end
if cfg.plots.improvementBoxchart
    plot_metric_improvement_boxchart(Q_results);
end
end
