# SWOT-Data

This repository contains selected files from `Estimation of daily discharge (DevSet)`.

Included:

- MATLAB source files (`.m`)
- NetCDF files (`.nc`) from the DevSet folder

Refactored entry point:

- `Estimation_of_daily_discharge_DevSet/main_refactored.m`
- `Estimation_of_daily_discharge_DevSet/+swot/`
- `Estimation_of_daily_discharge_DevSet/legacy/`
- `Estimation_of_daily_discharge_DevSet/REFACTORING.md`

The original `main.m` is kept as the legacy research script, with only a path
bootstrap added so it can find the moved legacy helper functions. The refactored
entry point wraps the same numerical routines in a config-driven pipeline so runs
can be chunked, cached, and extended more safely.

Excluded:

- MATLAB data/result files (`.mat`)
- autosave files (`.asv`)
- large external data folders

The excluded folders include `Estimation of daily discharge (comb)`, `python_discharge`, `SoS Dataset v005`, `HydroData-master`, `Rhine Gauge Data*`, and `FLaPE-Byrd-main`.
