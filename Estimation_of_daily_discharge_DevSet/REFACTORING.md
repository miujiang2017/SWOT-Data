# SWOT Discharge Refactor Notes

This branch keeps the legacy numerical functions intact and adds a configuration-driven
pipeline under the `+swot` MATLAB package. The goal is to make later Python/HPC
translation and method expansion easier without changing current numerical results.

## Entry Points

- `main.m`: original research script, left unchanged for reference.
- `main_refactored.m`: refactored entry point using the new pipeline.
- `swot.config.defaultConfig`: legacy-compatible smoke config. By default it runs
  basin `5`, path `1`, matching the active loop in `main.m`.
- `swot.config.fullRunConfig`: full basin/path config. Use this only when a full run
  is intended.

## Pipeline Layers

```text
config
  Defines paths, SoS region/type, date range, state window length, products,
  cache policy, validation, plotting, and output files.

pipeline
  Orchestrates setup, data preparation, estimator execution, validation, and plots.

cache
  Loads existing basinsv16_*.mat and Phi_save/Q_save caches. This avoids repeated
  netCDF reads and Hydrocron/RiverSP calls when cached data already exists.

filter
  Contains the path-level legacy Kalman filter. It calls the original
  build_H_obs_SWOT_Q, append_Qobs, calc_sigma0, and combine_xnn_SWOT functions.

utils
  Small helpers such as extracting one path from a basin and resolving configured
  basin/path indices.
```

## Exactness Policy

The refactor intentionally does not rewrite these numerical functions:

- `build_Phi_SWOT`
- `build_H_obs_SWOT_Q`
- `append_Qobs`
- `calc_sigma0`
- `combine_xnn_SWOT`
- `validation3`
- `validation4`
- plotting functions

The path-level filter in `swot.filter.runPathKalman` mirrors the active KF loop in
`main.m`: zero-anomaly initial state, the same covariance initialization, the same
Kalman gain/update equations, and the same window-combine function.

## Cache Policy

By default, the refactored pipeline prefers existing `basinsv16_*.mat` files and
loads `Phi_save.mat` / `Q_save.mat` when available. If basin caches are absent, it
falls back to reading SoS prior/result netCDF files and then filling RiverSP data.

For reproducible HPC runs, prebuild and version the lightweight intermediate cache
rather than letting every job re-read netCDF files or call external services.

## Extension Points

Future method changes should be added through config switches rather than editing
`main.m`:

- multiple discharge products: `cfg.kf.observationProducts`
- RTS on/off: add an option at the filter layer and keep KF output unchanged when off
- different state windows: `cfg.kf.stateEp`
- basin/path chunks: `cfg.execution.basinIndices`, `cfg.execution.pathIndices`
- product fusion: add a `+swot/+fusion` package and keep validation outside fusion
- additional reach observations: add observation builders that return compatible
  `H`, `z`, and `R` blocks, then combine them before the KF update

## Recommended HPC Shape

Use config files or small runner scripts to submit independent chunks:

```matlab
cfg = swot.config.fullRunConfig();
cfg.execution.basinIndices = 1:80;
cfg.output.resultsFile = 'Q_results_chunk_001_080.mat';
runOut = swot.pipeline.runExperiment(cfg);
```

Merge chunk result files in a separate post-processing step. Keep evaluation and
plotting as separate jobs so estimator jobs do not depend on gauge/reference data
unless explicitly requested.
