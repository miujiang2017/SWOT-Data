function results = optimize_sic22_experiments(varargin)
%OPTIMIZE_SIC22_EXPERIMENTS Tune the SIC-only 22-day window KF.
%
% This runner follows main_sic.m's method family:
%   - state_ep = 22
%   - Phi_save/Q_save window transition and process covariance
%   - raw Q_SIC4DVar observations only
%   - validation4_sic for SIC-only validation
% It does not use Q_SIC4DVar_interp, SVS, or Gauge_Q inside the state update.

opts = parse_options(varargin{:});

root = pwd;
addpath(fullfile(root, '..', 'RiverSP'));
addpath(fullfile(root, '..', 'SWORD V16'));
addpath(fullfile(root, '..', 'SoS'));

start_date = '2023-03-29';
end_date = '2025-05-02';
state_ep = 22;
use_svs = true;
nt = datenum(end_date) - datenum(start_date) + 1;

fprintf('Loading/building SIC-only data_KF_out...\n');
[data_KF_out, obs_percent_qprior] = load_or_build_sic_data(start_date, end_date, state_ep, use_svs);
global OBS_PERCENT_QPRIOR
OBS_PERCENT_QPRIOR = obs_percent_qprior;

tasks_all = enumerate_tasks(data_KF_out);
tasks = select_tasks(tasks_all, opts);
fprintf('Selected %d / %d paths for SIC22 experiments.\n', size(tasks, 1), size(tasks_all, 1));

fprintf('Loading Phi_save/Q_save...\n');
load('Phi_save.mat', 'Phi_save');
load('Q_save.mat', 'Q_save');

configs = build_configs(opts.ConfigSet);
results = table();
outfile = fullfile(root, sprintf('sic22_experiment_results_%s_%s.mat', ...
    opts.ConfigSet, datestr(now, 'yyyymmdd_HHMMSS')));

for ic = 1:numel(configs)
    cfg = configs(ic);
    fprintf('\n[%s] Config %d/%d: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
        ic, numel(configs), cfg.Name);
    [stats, detail] = run_config(tasks, data_KF_out, Phi_save, Q_save, nt, state_ep, use_svs, cfg, opts.SaveDetail);
    if opts.SaveDetail
        [comparison_summary, group_comparison_summary, detail_files] = ...
            save_detail_outputs(detail, stats, cfg, opts, root);
        stats.DetailMat = string(detail_files.mat);
        stats.CdfPng = string(detail_files.png);
        stats.CdfFig = string(detail_files.fig);
        stats.SummaryCsv = string(detail_files.summary_csv);
        stats.GroupSummaryCsv = string(detail_files.group_summary_csv);
    end
    row = struct2table(stats, 'AsArray', true);
    results = [results; row]; %#ok<AGROW>
    disp(row(:, {'Name','N_common','corr_kf','corr_interp','NSE_kf','NSE_interp', ...
        'rRMSE_kf','rRMSE_interp','rB_kf','rB_interp','score'}));
    if opts.SaveDetail
        save(outfile, 'results', 'configs', 'tasks', 'opts', ...
            'comparison_summary', 'group_comparison_summary', '-v7.3');
    else
        save(outfile, 'results', 'configs', 'tasks', 'opts', '-v7.3');
    end
end

results = sortrows(results, 'score', 'descend');
save(outfile, 'results', 'configs', 'tasks', 'opts', '-v7.3');
fprintf('\nSaved SIC22 experiment results: %s\n', outfile);
disp(results(:, {'Name','N_common','corr_kf','corr_interp','NSE_kf','NSE_interp', ...
    'rRMSE_kf','rRMSE_interp','rB_kf','rB_interp','score'}));
end

function opts = parse_options(varargin)
parser = inputParser;
parser.addParameter('ConfigSet', 'sic22_quick', @(s) ischar(s) || isstring(s));
parser.addParameter('MaxPaths', 80, @(x) isnumeric(x) && isscalar(x) && x > 0);
parser.addParameter('StartTask', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parser.addParameter('Stride', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parser.addParameter('Fold', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parser.addParameter('RebuildData', false, @(x) islogical(x) && isscalar(x));
parser.addParameter('SaveDetail', false, @(x) islogical(x) && isscalar(x));
parser.addParameter('DetailTag', '', @(s) ischar(s) || isstring(s));
parser.parse(varargin{:});
opts = parser.Results;
opts.ConfigSet = char(opts.ConfigSet);
opts.DetailTag = char(opts.DetailTag);
end

function [data_KF_out, obs_percent_qprior] = load_or_build_sic_data(start_date, end_date, state_ep, use_svs)
cache_file = 'data_KF_out_sic22_slim.mat';
if isfile(cache_file)
    S = load(cache_file, 'data_KF_out', 'obs_percent_qprior');
    data_KF_out = S.data_KF_out;
    obs_percent_qprior = S.obs_percent_qprior;
    return;
end

folder_path = fullfile(pwd, '..', 'SoS', 'SoS Dataset Oct');
file_prefix = 'na';
sos_type = 'uncon';

SoS_PriorsData_v16 = read_SoS_Priorsv005(folder_path, file_prefix, 16);
basins = enumerate_subset_paths_by_basin(SoS_PriorsData_v16, file_prefix);
basins = add_SoS_priors_to_basins(basins, SoS_PriorsData_v16);
basins = add_SVS_gauge_to_basins(basins);
SoS_ResultsData = read_SoS_Resultsv005(folder_path, file_prefix, sos_type);
basins = add_SoS_results_to_basins(basins, SoS_ResultsData, 'IRIS_2.9.nc');

split_opts.jump_threshold = 3;
split_opts.max_segment_ratio = 5;
split_opts.min_segment_length = 1;
split_opts.allow_singleton_at_hard_break = true;
basins = split_basins_paths_by_Qprior(basins, split_opts);

obs_percent_qprior = obs_percent_Qprior(basins, use_svs);
basins_out = filter_basins(basins, 2);

load('basinsv16_1.mat');
load('basinsv16_2.mat');
load('basinsv16_3.mat');
load('basinsv16_4.mat');
load('basinsv16_5.mat');
load('basinsv16_6.mat');
basins_out_old = [basinsv16_1, basinsv16_2, basinsv16_3, ...
    basinsv16_4, basinsv16_5, basinsv16_6];
basins_out = add_RiverSP_ReachData_to_basins_with_old(basins_out, basins_out_old, ...
    start_date, end_date, true);

data_KF = data_for_KF(basins_out, start_date, end_date, state_ep);
data_KF_out_full = filter_KF(data_KF);
data_KF_out_full = build_cDtau(data_KF_out_full);
data_KF_out = slim_data_kf_out(data_KF_out_full);
save(cache_file, 'data_KF_out', 'obs_percent_qprior', '-v7.3');
end

function data_slim = slim_data_kf_out(data_full)
keep_fields = { ...
    'paths', 'rch_len', 'Q_prior', 'minQ_prior', 'maxQ_prior', ...
    'center_pos', 'c', 'D', 'tau', ...
    'Q_SIC4DVar', 'day_index_SIC4DVar', 'mean_SIC4DVar', ...
    'SVS_Q', 'Gauge_Q'};

data_slim = struct([]);
for ib = 1:numel(data_full)
    for k = 1:numel(keep_fields)
        fld = keep_fields{k};
        if isfield(data_full(ib), fld)
            data_slim(ib).(fld) = data_full(ib).(fld);
        end
    end
end
end

function tasks = enumerate_tasks(data_KF_out)
tasks = zeros(0, 3);
task_idx = 0;
for ib = 1:numel(data_KF_out)
    if ~isfield(data_KF_out(ib), 'paths') || isempty(data_KF_out(ib).paths)
        continue;
    end
    for ip = 1:numel(data_KF_out(ib).paths)
        task_idx = task_idx + 1;
        tasks(end + 1, :) = [task_idx, ib, ip]; %#ok<AGROW>
    end
end
end

function tasks = select_tasks(tasks_all, opts)
mask = tasks_all(:, 1) >= opts.StartTask;
if opts.Stride > 1
    mask = mask & (mod(tasks_all(:, 1), opts.Stride) == opts.Fold);
end
tasks = tasks_all(mask, :);
tasks = tasks(1:min(opts.MaxPaths, size(tasks, 1)), :);
end

function configs = build_configs(config_set)
base = struct('Name', "", 'ObsUncMode', "mean_percent", 'ObsUncScale', 1.0, ...
    'QScale', 1.0, 'P0Scale', 1.0, 'InitMode', "sic_linear", ...
    'StateEp', 22, 'RidgeFrac', 0.0, 'OutputAnomScale', 1.0, ...
    'OutputGroupScales', [], 'QGroupScales', [], ...
    'AutoGainMode', "none", 'AutoGainBounds', [0.7 2.2], ...
    'InnovGateSigma', Inf, 'InnovRMaxScale', 1.0, 'InnovRPower', 2.0, ...
    'CombineMode', "median", 'SmoothMode', "forward", ...
    'ObsTemporalCorrMode', "none", 'OutputBoundsMode', "none", ...
    'QScaleMode', "fixed", 'QScaleBounds', [0.03 1.0], ...
    'OutputSmoothDays', 0);

switch config_set
    case 'sic22_quick'
        specs = {
            "main_sic_mean_s1_Q1",       "mean_percent", 1.00, 1.00, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q1",            "mean_percent", 0.50, 1.00, 1.0, "sic_linear", 0.0
            "mean_s0p75_Q1",            "mean_percent", 0.75, 1.00, 1.0, "sic_linear", 0.0
            "mean_s1p50_Q1",            "mean_percent", 1.50, 1.00, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p25",            "mean_percent", 1.00, 0.25, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p15",            "mean_percent", 1.00, 0.15, 1.0, "sic_linear", 0.0
            "mean_s0p75_Q0p25",         "mean_percent", 0.75, 0.25, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q0p25",         "mean_percent", 0.50, 0.25, 1.0, "sic_linear", 0.0
            "group_s1_Q1",              "qprior_group", 1.00, 1.00, 1.0, "sic_linear", 0.0
            "group_s0p75_Q0p25",        "qprior_group", 0.75, 0.25, 1.0, "sic_linear", 0.0
            "mean_zero_Q0p25",          "mean_percent", 1.00, 0.25, 1.0, "zero",       0.0
            "mean_rawx0_Q0p25",         "mean_percent", 1.00, 0.25, 1.0, "sic_rawx0",  0.0
            };
    case 'sic22_fine'
        specs = {
            "mean_s0p35_Q0p20", "mean_percent", 0.35, 0.20, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q0p20", "mean_percent", 0.50, 0.20, 1.0, "sic_linear", 0.0
            "mean_s0p65_Q0p20", "mean_percent", 0.65, 0.20, 1.0, "sic_linear", 0.0
            "mean_s0p35_Q0p30", "mean_percent", 0.35, 0.30, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q0p30", "mean_percent", 0.50, 0.30, 1.0, "sic_linear", 0.0
            "mean_s0p65_Q0p30", "mean_percent", 0.65, 0.30, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q0p40", "mean_percent", 0.50, 0.40, 1.0, "sic_linear", 0.0
            "mean_s0p75_Q0p40", "mean_percent", 0.75, 0.40, 1.0, "sic_linear", 0.0
            "mean_s1p00_Q0p40", "mean_percent", 1.00, 0.40, 1.0, "sic_linear", 0.0
            "group_s0p50_Q0p25","qprior_group", 0.50, 0.25, 1.0, "sic_linear", 0.0
            "group_s0p50_Q0p40","qprior_group", 0.50, 0.40, 1.0, "sic_linear", 0.0
            "mean_s0p50_Q0p25_P4","mean_percent", 0.50, 0.25, 4.0, "sic_linear", 0.0
            };
    case 'sic22_q_refine'
        specs = {
            "mean_s1_Q0p08",       "mean_percent", 1.00, 0.08, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p10",       "mean_percent", 1.00, 0.10, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p12",       "mean_percent", 1.00, 0.12, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p14",       "mean_percent", 1.00, 0.14, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p16",       "mean_percent", 1.00, 0.16, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p18",       "mean_percent", 1.00, 0.18, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p20",       "mean_percent", 1.00, 0.20, 1.0, "sic_linear", 0.0
            "mean_zero_Q0p12",     "mean_percent", 1.00, 0.12, 1.0, "zero",       0.0
            "mean_zero_Q0p15",     "mean_percent", 1.00, 0.15, 1.0, "zero",       0.0
            "mean_zero_Q0p20",     "mean_percent", 1.00, 0.20, 1.0, "zero",       0.0
            "mean_rawx0_Q0p12",    "mean_percent", 1.00, 0.12, 1.0, "sic_rawx0",  0.0
            "mean_rawx0_Q0p15",    "mean_percent", 1.00, 0.15, 1.0, "sic_rawx0",  0.0
            };
    case 'sic22_top'
        specs = {
            "mean_zero_Q0p10", "mean_percent", 1.00, 0.10, 1.0, "zero",       0.0
            "mean_zero_Q0p12", "mean_percent", 1.00, 0.12, 1.0, "zero",       0.0
            "mean_zero_Q0p14", "mean_percent", 1.00, 0.14, 1.0, "zero",       0.0
            "mean_s1_Q0p14",   "mean_percent", 1.00, 0.14, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p16",   "mean_percent", 1.00, 0.16, 1.0, "sic_linear", 0.0
            "mean_s1_Q0p18",   "mean_percent", 1.00, 0.18, 1.0, "sic_linear", 0.0
            };
    case 'sic22_amp'
        specs = {
            "zero_Q0p10_a0p70", "mean_percent", 1.00, 0.10, 1.0, "zero",       0.0, 0.70
            "zero_Q0p10_a0p85", "mean_percent", 1.00, 0.10, 1.0, "zero",       0.0, 0.85
            "zero_Q0p10_a1p00", "mean_percent", 1.00, 0.10, 1.0, "zero",       0.0, 1.00
            "zero_Q0p10_a1p15", "mean_percent", 1.00, 0.10, 1.0, "zero",       0.0, 1.15
            "zero_Q0p12_a0p70", "mean_percent", 1.00, 0.12, 1.0, "zero",       0.0, 0.70
            "zero_Q0p12_a0p85", "mean_percent", 1.00, 0.12, 1.0, "zero",       0.0, 0.85
            "s1_Q0p18_a0p70",   "mean_percent", 1.00, 0.18, 1.0, "sic_linear", 0.0, 0.70
            "s1_Q0p18_a0p85",   "mean_percent", 1.00, 0.18, 1.0, "sic_linear", 0.0, 0.85
            "s1_Q0p18_a1p15",   "mean_percent", 1.00, 0.18, 1.0, "sic_linear", 0.0, 1.15
            };
    case 'sic22_zero_q'
        specs = {
            "zero_Q0p04_a1p15", "mean_percent", 1.00, 0.04, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_a1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p08_a1p15", "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.15
            "zero_Q0p10_a1p15", "mean_percent", 1.00, 0.10, 1.0, "zero", 0.0, 1.15
            "zero_Q0p12_a1p15", "mean_percent", 1.00, 0.12, 1.0, "zero", 0.0, 1.15
            "zero_Q0p14_a1p15", "mean_percent", 1.00, 0.14, 1.0, "zero", 0.0, 1.15
            "zero_Q0p16_a1p15", "mean_percent", 1.00, 0.16, 1.0, "zero", 0.0, 1.15
            };
    case 'sic22_zero_top'
        specs = {
            "zero_Q0p03_a1p15", "mean_percent", 1.00, 0.03, 1.0, "zero", 0.0, 1.15
            "zero_Q0p04_a1p15", "mean_percent", 1.00, 0.04, 1.0, "zero", 0.0, 1.15
            "zero_Q0p05_a1p15", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_a1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15
            };
    case 'sic22_best80_diag'
        specs = {
            "zero_Q0p06_a1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15
            };
    case 'sic22_amp_refine'
        specs = {
            "zero_Q0p05_a1p15", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.15
            "zero_Q0p05_a1p30", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.30
            "zero_Q0p05_a1p45", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.45
            "zero_Q0p05_a1p60", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.60
            "zero_Q0p06_a1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_a1p30", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.30
            "zero_Q0p06_a1p45", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.45
            "zero_Q0p06_a1p60", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.60
            };
    case 'sic22_group_amp'
        specs = {
            "zero_Q0p06_g1", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.15 1.15]
            "zero_Q0p06_g2", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [0.90 1.15 1.30]
            "zero_Q0p06_g3", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [0.75 1.15 1.45]
            "zero_Q0p06_g4", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.30 1.15 0.90]
            "zero_Q0p06_g5", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.45 1.15 0.75]
            "zero_Q0p05_g2", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.00, [0.90 1.15 1.30]
            "zero_Q0p05_g4", "mean_percent", 1.00, 0.05, 1.0, "zero", 0.0, 1.00, [1.30 1.15 0.90]
            };
    case 'sic22_mid_amp80'
        specs = {
            "zero_Q0p06_gmid0p70", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 0.70 1.15]
            "zero_Q0p06_gmid0p85", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 0.85 1.15]
            "zero_Q0p06_gmid1p00", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.00 1.15]
            "zero_Q0p06_gmid1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.15 1.15]
            "zero_Q0p06_gmid1p30", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.30 1.15]
            };
    case 'sic22_mid_amp80_high'
        specs = {
            "zero_Q0p06_gmid1p45", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.45 1.15]
            "zero_Q0p06_gmid1p60", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.60 1.15]
            "zero_Q0p06_gmid1p75", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [1.15 1.75 1.15]
            };
    case 'sic22_qscale_mid80'
        specs = {
            "zero_Q0p07_gmid1p60", "mean_percent", 1.00, 0.07, 1.0, "zero", 0.0, 1.00, [1.15 1.60 1.15]
            "zero_Q0p08_gmid1p60", "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.00, [1.15 1.60 1.15]
            "zero_Q0p09_gmid1p60", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [1.15 1.60 1.15]
            };
    case 'sic22_q09_midgain80'
        specs = {
            "zero_Q0p09_gmid1p50", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [1.15 1.50 1.15]
            "zero_Q0p09_gmid1p70", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [1.15 1.70 1.15]
            "zero_Q0p09_gmid1p85", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [1.15 1.85 1.15]
            };
    case 'sic22_best_full'
        specs = {
            "zero_Q0p09_gmid1p85", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [1.15 1.85 1.15]
            };
    case 'sic22_obs_amp'
        specs = {
            "zero_Q0p06_obsamp_group", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_group"
            "zero_Q0p08_obsamp_group", "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_group"
            "zero_Q0p09_obsamp_group", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_group"
            "zero_Q0p10_obsamp_group", "mean_percent", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_group"
            "zero_Q0p08_obsamp_reach", "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_reach"
            "zero_Q0p09_obsamp_reach", "mean_percent", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "obs_std_reach"
            };
    case 'sic22_uncertainty'
        specs = {
            "zero_Q0p06_meanR0p75",      "mean_percent",       0.75, 0.06, 1.0, "zero", 0.0
            "zero_Q0p06_meanR1p00",      "mean_percent",       1.00, 0.06, 1.0, "zero", 0.0
            "zero_Q0p06_meanR1p25",      "mean_percent",       1.25, 0.06, 1.0, "zero", 0.0
            "zero_Q0p06_groupR1p00",     "qprior_group",       1.00, 0.06, 1.0, "zero", 0.0
            "zero_Q0p06_pow0p75",        "qprior_power_0p75",  1.00, 0.06, 1.0, "zero", 0.0
            "zero_Q0p06_pow0p50",        "qprior_power_0p50",  1.00, 0.06, 1.0, "zero", 0.0
            "zero_Q0p08_pow0p75",        "qprior_power_0p75",  1.00, 0.08, 1.0, "zero", 0.0
            "zero_Q0p08_pow0p50",        "qprior_power_0p50",  1.00, 0.08, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p75",        "qprior_power_0p75",  1.00, 0.10, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p50",        "qprior_power_0p50",  1.00, 0.10, 1.0, "zero", 0.0
            };
    case 'sic22_uncertainty_top80'
        specs = {
            "zero_Q0p09_pow0p75",        "qprior_power_0p75",  1.00, 0.09, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p75",        "qprior_power_0p75",  1.00, 0.10, 1.0, "zero", 0.0
            "zero_Q0p11_pow0p75",        "qprior_power_0p75",  1.00, 0.11, 1.0, "zero", 0.0
            "zero_Q0p12_pow0p75",        "qprior_power_0p75",  1.00, 0.12, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p50",        "qprior_power_0p50",  1.00, 0.10, 1.0, "zero", 0.0
            "zero_Q0p06_meanR0p75",      "mean_percent",       0.75, 0.06, 1.0, "zero", 0.0
            };
    case 'sic22_uncertainty_rscale80'
        specs = {
            "zero_Q0p10_pow0p75_R0p40",  "qprior_power_0p75",  0.40, 0.10, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p75_R0p60",  "qprior_power_0p75",  0.60, 0.10, 1.0, "zero", 0.0
            "zero_Q0p10_pow0p75_R0p80",  "qprior_power_0p75",  0.80, 0.10, 1.0, "zero", 0.0
            "zero_Q0p11_pow0p75_R0p40",  "qprior_power_0p75",  0.40, 0.11, 1.0, "zero", 0.0
            "zero_Q0p11_pow0p75_R0p60",  "qprior_power_0p75",  0.60, 0.11, 1.0, "zero", 0.0
            "zero_Q0p11_pow0p75_R0p80",  "qprior_power_0p75",  0.80, 0.11, 1.0, "zero", 0.0
            };
    case 'sic22_innov_gate80'
        specs = {
            "zero_Q0p10_pow0p75_R0p60_gate2p0",  "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 2.0, 9.0, 2.0
            "zero_Q0p10_pow0p75_R0p60_gate2p5",  "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 2.5, 9.0, 2.0
            "zero_Q0p10_pow0p75_R0p60_gate3p0",  "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 3.0, 9.0, 2.0
            "zero_Q0p10_pow0p75_R0p60_gate2p5m4","qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 2.5, 4.0, 2.0
            "zero_Q0p11_pow0p75_R0p60_gate2p5",  "qprior_power_0p75", 0.60, 0.11, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 2.5, 9.0, 2.0
            "zero_Q0p06_meanR0p75_gate2p5",      "mean_percent",      0.75, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], 2.5, 9.0, 2.0
            };
    case 'sic22_varcombine20'
        specs = {
            "zero_Q0p10_pow0p75_R0p60_varw", "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p11_pow0p75_R0p60_varw", "qprior_power_0p75", 0.60, 0.11, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p06_meanR0p75_varw",     "mean_percent",      0.75, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R0p60_arith","qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "arith"
            };
    case 'sic22_varcombine_fine20'
        specs = {
            "zero_Q0p10_pow0p75_R0p80_varw", "qprior_power_0p75", 0.80, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R0p90_varw", "qprior_power_0p75", 0.90, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p10_varw", "qprior_power_0p75", 1.10, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p25_varw", "qprior_power_0p75", 1.25, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p50_varw", "qprior_power_0p75", 1.50, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            };
    case 'sic22_varcombine_qfine20'
        specs = {
            "zero_Q0p06_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p08_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.08, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p09_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p10_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p12_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.12, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p15_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.15, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            };
    case 'sic22_varcombine_top80'
        specs = {
            "zero_Q0p10_pow0p75_R0p80_varw", "qprior_power_0p75", 0.80, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p09_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            "zero_Q0p15_pow0p75_R1p00_varw", "qprior_power_0p75", 1.00, 0.15, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight"
            };
    case 'sic22_rts20'
        specs = {
            "rts_zero_Q0p06_meanR0p75",       "mean_percent",      0.75, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median",     "rts"
            "rts_zero_Q0p10_pow0p75_R0p60",   "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median",     "rts"
            "rts_zero_Q0p10_pow0p75_R1p00",   "qprior_power_0p75", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median",     "rts"
            "rts_zero_Q0p09_pow0p75_R1p00",   "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median",     "rts"
            "rts_zero_Q0p10_pow0p75_R0p80_vw","qprior_power_0p75", 0.80, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts"
            "fwd_zero_Q0p10_pow0p75_R0p60",   "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median",     "forward"
            };
    case 'sic22_rts_top80'
        specs = {
            "rts_zero_Q0p09_pow0p75_R1p00",  "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts"
            "rts_zero_Q0p10_pow0p75_R1p00",  "qprior_power_0p75", 1.00, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts"
            "rts_zero_Q0p06_meanR0p75",      "mean_percent",      0.75, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts"
            "rts_zero_Q0p10_pow0p75_R0p60",  "qprior_power_0p75", 0.60, 0.10, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts"
            };
    case 'sic22_rts_best'
        specs = {
            "rts_zero_Q0p09_pow0p75_R1p00",  "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts"
            };
    case 'sic22_rts_tempcorr80'
        specs = {
            "rts_zero_Q0p09_pow0p75_R1p00_tauR", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "same_reach_tau"
            "rts_zero_Q0p09_group_R1p00_tauR",   "qprior_group",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "same_reach_tau"
            "rts_zero_Q0p09_mean_R1p00_tauR",    "mean_percent",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "same_reach_tau"
            "rts_zero_Q0p09_pow0p75_R1p00_diag", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none"
            };
    case 'sic22_rts_bounds80'
        specs = {
            "rts_zero_Q0p09_pow0p75_R1p00_nonneg",   "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative"
            "rts_zero_Q0p09_pow0p75_R1p00_priorbox", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "prior_minmax"
            "rts_zero_Q0p09_group_R1p00_priorbox",   "qprior_group",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "prior_minmax"
            "rts_zero_Q0p09_mean_R1p00_priorbox",    "mean_percent",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "prior_minmax"
            };
    case 'sic22_rts_qmatch80'
        specs = {
            "rts_qmatch_pow0p75_nonneg", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative", "match_obs_qdiag", [0.03 1.0]
            "rts_qmatch_group_nonneg",   "qprior_group",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative", "match_obs_qdiag", [0.03 1.0]
            "rts_qmatch_mean_nonneg",    "mean_percent",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative", "match_obs_qdiag", [0.03 1.0]
            };
    case 'sic22_rts_varw_bounds80'
        specs = {
            "rts_varw_pow0p75_nonneg", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts", "none", "nonnegative"
            "rts_varw_group_nonneg",   "qprior_group",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts", "none", "nonnegative"
            "rts_varw_mean_nonneg",    "mean_percent",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_center_bounds80'
        specs = {
            "rts_center_pow0p75_nonneg", "qprior_power_0p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_center_group_nonneg",   "qprior_group",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_center_mean_nonneg",    "mean_percent",      1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_uncweight80'
        specs = {
            "rts_uncsqrt_group_median_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative"
            "rts_uncsqrt_group_center_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncinv_group_median_nonneg",  "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.527 1.000 1.886], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative"
            "rts_uncinv_group_center_nonneg",  "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.527 1.000 1.886], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_uncweight_top80'
        specs = {
            "rts_uncsqrt_group_center_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncsqrt_group_median_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_centerweight20'
        specs = {
            "rts_uncsqrt_group_centerw_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center_weight", "rts", "none", "nonnegative"
            "rts_group_centerw_nonneg",         "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center_weight", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_obsweight20'
        specs = {
            "rts_uncsqrt_group_obscount_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "obs_count_center", "rts", "none", "nonnegative"
            "rts_group_obscount_nonneg",         "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "obs_count_center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_obsprox20'
        specs = {
            "rts_uncsqrt_group_obsprox_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "obs_prox_center", "rts", "none", "nonnegative"
            "rts_group_obsprox_nonneg",         "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "obs_prox_center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_uncfloor20'
        specs = {
            "rts_uncfloor_uncsqrt_center_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncfloor_center_nonneg",         "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncfloor_uncsqrt_median_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "median", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_uncfloor_top80'
        specs = {
            "rts_uncfloor_uncsqrt_center_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_uncquant20'
        specs = {
            "rts_uncp68_uncsqrt_center_nonneg", "qprior_group_p68", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncp75_uncsqrt_center_nonneg", "qprior_group_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_uncp68_center_nonneg",         "qprior_group_p68", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_highunc20'
        specs = {
            "rts_highp75_uncsqrt_center_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_highp90_uncsqrt_center_nonneg", "qprior_group_high_p90", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            "rts_highp75_center_nonneg",         "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [],                    [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative"
            };
    case 'sic22_rts_postsmooth20'
        specs = {
            "rts_uncsqrt_center_smooth3_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 3
            "rts_uncsqrt_center_smooth5_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_uncfloor_uncsqrt_smooth3_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 3
            };
    case 'sic22_rts_postsmooth_top80'
        specs = {
            "rts_uncsqrt_center_smooth5_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_postsmooth_gap20'
        specs = {
            "rts_uncsqrt_center_smooth7_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 7
            "rts_uncsqrt_center_smooth9_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 9
            "rts_uncfloor_uncsqrt_smooth5_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_uncfloor_smooth_top80'
        specs = {
            "rts_uncfloor_uncsqrt_smooth5_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_highunc_smooth20'
        specs = {
            "rts_highp75_uncsqrt_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp90_uncsqrt_smooth5_nonneg", "qprior_group_high_p90", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale20'
        specs = {
            "rts_highp75_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_center_smooth5_nonneg",   "qprior_group",          1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_uncfloor_center_smooth5_nonneg", "qprior_group_floor_mean", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_top80'
        specs = {
            "rts_highp75_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_group_top80'
        specs = {
            "rts_group_center_smooth5_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_qgrid20'
        specs = {
            "rts_group_Q0p06_center_smooth5_nonneg", "qprior_group", 1.00, 0.06, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_Q0p12_center_smooth5_nonneg", "qprior_group", 1.00, 0.12, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_Q0p18_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp75_Q0p12_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.12, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp75_Q0p18_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_q018_top80'
        specs = {
            "rts_group_Q0p18_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_highp75_q018_top80'
        specs = {
            "rts_highp75_Q0p18_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_highp68_q018_top80'
        specs = {
            "rts_highp68_Q0p18_center_smooth5_nonneg", "qprior_group_high_p68", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_varweight20'
        specs = {
            "rts_highp75_Q0p18_varw_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp68_Q0p18_varw_smooth5_nonneg", "qprior_group_high_p68", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "var_weight", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_qmatch_center20'
        specs = {
            "rts_highp75_qmatch_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "match_obs_qdiag", [0.03 1.0], 5
            "rts_highp68_qmatch_center_smooth5_nonneg", "qprior_group_high_p68", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "match_obs_qdiag", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_uncfloor_q01820'
        specs = {
            "rts_uncfloor_Q0p18_center_smooth5_nonneg", "qprior_group_floor_mean", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_highp90_20'
        specs = {
            "rts_highp90_Q0p09_center_smooth5_nonneg", "qprior_group_high_p90", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp90_Q0p18_center_smooth5_nonneg", "qprior_group_high_p90", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_qgroup20'
        specs = {
            "rts_group_Q0p18_Qg_1_1_1p9_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 1.9], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_Q0p18_Qg_1_1_2p5_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 2.5], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_Q0p18_Qg_1_1_3_center_smooth5_nonneg",   "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 3.0], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_qgroup_down20'
        specs = {
            "rts_group_Q0p18_Qg_1_1_0p5_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 0.5], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_highp75_Q0p18_Qg_1_1_0p5_center_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 0.5], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            "rts_group_Q0p18_Qg_1_1_0p7_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 0.7], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_norescale_qgroup_down_top80'
        specs = {
            "rts_group_Q0p18_Qg_1_1_0p5_center_smooth5_nonneg", "qprior_group", 1.00, 0.18, 1.0, "zero", 0.0, 1.00, [], [1.0 1.0 0.5], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_highunc_smooth_top80'
        specs = {
            "rts_highp75_uncsqrt_smooth5_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], 5
            };
    case 'sic22_rts_groupsmooth20'
        specs = {
            "rts_uncsqrt_center_smooth559_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], [5 5 9]
            "rts_highp75_uncsqrt_smooth559_nonneg", "qprior_group_high_p75", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], [5 5 9]
            "rts_uncsqrt_center_smooth557_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], [5 5 7]
            };
    case 'sic22_rts_groupsmooth_top80'
        specs = {
            "rts_uncsqrt_center_smooth559_nonneg", "qprior_group", 1.00, 0.09, 1.0, "zero", 0.0, 1.00, [0.735 1.013 1.391], [], "none", [0.7 2.2], Inf, 1.0, 2.0, "center", "rts", "none", "nonnegative", "fixed", [0.03 1.0], [5 5 9]
            };
    case 'sic22_r_refine'
        specs = {
            "zero_Q0p06_R0p35_a1p15", "mean_percent", 0.35, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R0p50_a1p15", "mean_percent", 0.50, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R0p75_a1p15", "mean_percent", 0.75, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R1p00_a1p15", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R1p25_a1p15", "mean_percent", 1.25, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R1p50_a1p15", "mean_percent", 1.50, 0.06, 1.0, "zero", 0.0, 1.15
            "zero_Q0p06_R2p00_a1p15", "mean_percent", 2.00, 0.06, 1.0, "zero", 0.0, 1.15
            };
    case 'sic22_qgroup'
        specs = {
            "zero_Q0p06_qg_1_1_1",       "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [1.0 1.0 1.0]
            "zero_Q0p06_qg_1_1p5_2",     "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [1.0 1.5 2.0]
            "zero_Q0p06_qg_1_2_3",       "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [1.0 2.0 3.0]
            "zero_Q0p06_qg_0p7_1p5_2p5", "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [0.7 1.5 2.5]
            "zero_Q0p06_qg_1p5_1_1",     "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [1.5 1.0 1.0]
            "zero_Q0p06_qg_2_1_1",       "mean_percent", 1.00, 0.06, 1.0, "zero", 0.0, 1.15, [], [2.0 1.0 1.0]
            "zero_Q0p08_qg_0p7_1p5_2p5", "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.15, [], [0.7 1.5 2.5]
            "zero_Q0p08_qg_1_1p5_2",     "mean_percent", 1.00, 0.08, 1.0, "zero", 0.0, 1.15, [], [1.0 1.5 2.0]
            };
    otherwise
        error('Unknown ConfigSet: %s', config_set);
end

configs = repmat(base, 1, size(specs, 1));
for i = 1:size(specs, 1)
    configs(i).Name = specs{i, 1};
    configs(i).ObsUncMode = specs{i, 2};
    configs(i).ObsUncScale = specs{i, 3};
    configs(i).QScale = specs{i, 4};
    configs(i).P0Scale = specs{i, 5};
    configs(i).InitMode = specs{i, 6};
    configs(i).RidgeFrac = specs{i, 7};
    if size(specs, 2) >= 8
        configs(i).OutputAnomScale = specs{i, 8};
    end
    if size(specs, 2) >= 9
        configs(i).OutputGroupScales = specs{i, 9};
    end
    if size(specs, 2) >= 10
        configs(i).QGroupScales = specs{i, 10};
    end
    if size(specs, 2) >= 11
        configs(i).AutoGainMode = specs{i, 11};
    end
    if size(specs, 2) >= 12
        configs(i).AutoGainBounds = specs{i, 12};
    end
    if size(specs, 2) >= 13
        configs(i).InnovGateSigma = specs{i, 13};
    end
    if size(specs, 2) >= 14
        configs(i).InnovRMaxScale = specs{i, 14};
    end
    if size(specs, 2) >= 15
        configs(i).InnovRPower = specs{i, 15};
    end
    if size(specs, 2) >= 16
        configs(i).CombineMode = specs{i, 16};
    end
    if size(specs, 2) >= 17
        configs(i).SmoothMode = specs{i, 17};
    end
    if size(specs, 2) >= 18
        configs(i).ObsTemporalCorrMode = specs{i, 18};
    end
    if size(specs, 2) >= 19
        configs(i).OutputBoundsMode = specs{i, 19};
    end
    if size(specs, 2) >= 20
        configs(i).QScaleMode = specs{i, 20};
    end
    if size(specs, 2) >= 21
        configs(i).QScaleBounds = specs{i, 21};
    end
    if size(specs, 2) >= 22
        configs(i).OutputSmoothDays = specs{i, 22};
    end
end
end

function [stats, detail] = run_config(tasks, data_KF_out, Phi_save, Q_save, nt, state_ep, use_svs, cfg, save_detail)
all_kf = init_metric_arrays();
all_interp = init_metric_arrays();
errors = 0;

for it = 1:size(tasks, 1)
    task_idx = tasks(it, 1);
    ib = tasks(it, 2);
    ip = tasks(it, 3);
    if mod(it, 10) == 1
        fprintf('  path %d/%d (task %d, ib=%d ip=%d)\n', it, size(tasks, 1), task_idx, ib, ip);
    end
    try
        sg_path = get_path_struct_local(data_KF_out(ib), ip);
        nR = length(sg_path.rch_len{1});
        [Phi_st, Q_st_base] = get_or_build_phi_q(sg_path, Phi_save, Q_save, ib, ip, state_ep);
        qscale_eff = effective_qscale(sg_path, Q_st_base, state_ep, cfg);
        Q_st = Q_st_base .* qscale_eff;
        Q_st = apply_group_process_scale(Q_st, sg_path, state_ep, cfg.QGroupScales);
        if cfg.RidgeFrac > 0
            qprior = sg_path.Q_prior{1, 1}(:, 1);
            ridge = repmat((cfg.RidgeFrac .* max(abs(qprior), 1)).^2, state_ep, 1);
            Q_st = Q_st + diag(ridge(:));
        end
        Qest = run_one_path_sic22_config(sg_path, Phi_st, Q_st, nR, nt, state_ep, cfg);
        [vali_est, ~, ~, ~, ~, ~, vali_sic_i] = validation4_sic(Qest, sg_path, nR, use_svs);
        qprior = sg_path.Q_prior{1, 1}(:, 1);
        all_kf = append_metrics(all_kf, vali_est, qprior, task_idx, ib, ip);
        all_interp = append_metrics(all_interp, vali_sic_i, qprior, task_idx, ib, ip);
    catch ME
        errors = errors + 1;
        fprintf(2, '  error task %d ib=%d ip=%d: %s\n', task_idx, ib, ip, ME.message);
    end
end

[kf, interp, n_common] = paired_summary(all_kf, all_interp);
group_stats = paired_summary_by_qgroup(all_kf, all_interp);
stats = struct();
stats.Name = string(cfg.Name);
stats.ObsUncMode = string(cfg.ObsUncMode);
stats.ObsUncScale = cfg.ObsUncScale;
stats.QScale = cfg.QScale;
stats.QScaleMode = string(cfg.QScaleMode);
stats.QScaleBounds = string(mat2str(cfg.QScaleBounds));
stats.P0Scale = cfg.P0Scale;
stats.InitMode = string(cfg.InitMode);
stats.OutputAnomScale = cfg.OutputAnomScale;
stats.OutputGroupScales = string(mat2str(cfg.OutputGroupScales));
stats.QGroupScales = string(mat2str(cfg.QGroupScales));
stats.InnovGateSigma = cfg.InnovGateSigma;
stats.InnovRMaxScale = cfg.InnovRMaxScale;
stats.InnovRPower = cfg.InnovRPower;
stats.CombineMode = string(cfg.CombineMode);
stats.SmoothMode = string(cfg.SmoothMode);
stats.ObsTemporalCorrMode = string(cfg.ObsTemporalCorrMode);
stats.OutputBoundsMode = string(cfg.OutputBoundsMode);
stats.OutputSmoothDays = cfg.OutputSmoothDays;
stats.N_common = n_common;
stats.errors = errors;
stats.corr_kf = kf.corr;
stats.corr_interp = interp.corr;
stats.NSE_kf = kf.NSE;
stats.NSE_interp = interp.NSE;
stats.rRMSE_kf = kf.rRMSE;
stats.rRMSE_interp = interp.rRMSE;
stats.rB_kf = kf.rB;
stats.rB_interp = interp.rB;
stats.score = (kf.corr - interp.corr) + (kf.NSE - interp.NSE) ...
    - 0.005 * (kf.rRMSE - interp.rRMSE) - 0.002 * (kf.rB - interp.rB);
stats = append_group_stats(stats, group_stats);

detail = struct();
if save_detail
    detail.kf = all_kf;
    detail.interp = all_interp;
    detail.group_stats = group_stats;
    detail.config = cfg;
end
end

function [Phi_st, Q_st] = get_or_build_phi_q(sg_path, Phi_save, Q_save, ib, ip, state_ep)
nR = length(sg_path.rch_len{1});
nState = nR * state_ep;
use_cached = false;
if numel(Phi_save) >= ib && numel(Q_save) >= ib && ...
        numel(Phi_save{ib}) >= ip && numel(Q_save{ib}) >= ip && ...
        ~isempty(Phi_save{ib}{ip}) && ~isempty(Q_save{ib}{ip})
    Phi_candidate = Phi_save{ib}{ip};
    Q_candidate = Q_save{ib}{ip};
    use_cached = isequal(size(Phi_candidate), [nState, nState]) && ...
        isequal(size(Q_candidate), [nState, nState]);
end

if use_cached
    Phi_st = Phi_candidate;
    Q_st = Q_candidate;
else
    [Phi_st, Q_st] = build_Phi_SWOT(sg_path, state_ep);
end
end

function qscale = effective_qscale(sg_path, Q_st_base, state_ep, cfg)
mode = lower(string(cfg.QScaleMode));
if mode == "fixed"
    qscale = cfg.QScale;
    return;
end

switch mode
    case "match_obs_qdiag"
        q_diag = diag(Q_st_base);
        q_diag = q_diag(isfinite(q_diag) & q_diag > 0);
        r_diag = first_valid_obs_rdiag(sg_path, state_ep, cfg);
        if isempty(q_diag) || isempty(r_diag)
            qscale = cfg.QScale;
        else
            qscale = median(r_diag, 'omitnan') ./ median(q_diag, 'omitnan');
        end
        if ~isfinite(qscale) || qscale <= 0
            qscale = cfg.QScale;
        end
        qscale = min(max(qscale, cfg.QScaleBounds(1)), cfg.QScaleBounds(2));

    otherwise
        error('Unknown QScaleMode: %s.', string(cfg.QScaleMode));
end
end

function r_diag = first_valid_obs_rdiag(sg_path, state_ep, cfg)
r_diag = [];
nR = length(sg_path.rch_len{1});
sic_start_day_idx = local_first_sic_path_day_idx(sg_path, nR);
if isnan(sic_start_day_idx)
    return;
end
sg_path_kf = local_slice_sic_daily_cells(sg_path, sic_start_day_idx);
max_ep = min(60, size(sg_path_kf.Q_SIC4DVar{1, 1}, 2) - state_ep);
if max_ep < 1
    return;
end
for ep = 1:max_ep
    [~, ~, R] = build_H_obs_SWOT_Q(sg_path_kf, state_ep, ep, 1, ...
        cfg.ObsUncMode, cfg.ObsUncScale, cfg.ObsTemporalCorrMode);
    if ~isempty(R)
        r_diag = diag(R);
        r_diag = r_diag(isfinite(r_diag) & r_diag > 0);
        return;
    end
end
end

function Qest_med = run_one_path_sic22_config(sg_path, Phi_st, Q_st, nR, nt, state_ep, cfg)
sic_start_day_idx = local_first_sic_path_day_idx(sg_path, nR);
if isnan(sic_start_day_idx)
    Qest_med = local_nan_Qest(nR, nt);
    return;
end

nt_run = nt - sic_start_day_idx + 1;
if nt_run <= state_ep
    Qest_med = local_nan_Qest(nR, nt);
    return;
end

sg_path_kf = local_slice_sic_daily_cells(sg_path, sic_start_day_idx);
xn = build_initial_state(sg_path, sic_start_day_idx, state_ep, cfg.InitMode);
sigma0 = calc_sigma0(sg_path);
tmp = repmat((sigma0 .^ 2) .* cfg.P0Scale, state_ep, 1);
P = diag(tmp(:));
xnn = cell(1, nt_run - state_ep);
Pnn = cell(1, nt_run - state_ep);
xpredn = cell(1, nt_run - state_ep);
Ppredn = cell(1, nt_run - state_ep);

for i = 1:(nt_run - state_ep)
    x_pred = Phi_st * xn;
    P_pred = (Phi_st * P * Phi_st') + Q_st;
    xpredn{i} = x_pred;
    Ppredn{i} = P_pred;
    [H_Q, z_Q, R_Q] = build_H_obs_SWOT_Q(sg_path_kf, state_ep, i, 1, ...
        cfg.ObsUncMode, cfg.ObsUncScale, cfg.ObsTemporalCorrMode);
    if ~isempty(z_Q)
        [H, zn, R] = append_Qobs([], [], [], H_Q, z_Q, R_Q);
        R = apply_innovation_r_gating(R, zn - H * x_pred, H, P_pred, cfg);
        Kn = P_pred * H' * pinv(H * P_pred * H' + R);
        xn = x_pred + Kn * (zn - H * x_pred);
        P = (eye(state_ep * nR) - Kn * H) * P_pred;
    else
        xn = x_pred;
        P = P_pred;
    end
    xnn{i} = xn;
    Pnn{i} = P;
end

if string(cfg.SmoothMode) == "rts"
    [xnn, Pnn] = rts_smooth_22day(xnn, Pnn, xpredn, Ppredn, Phi_st);
elseif string(cfg.SmoothMode) ~= "forward"
    error('Unknown SmoothMode: %s.', string(cfg.SmoothMode));
end

[~, Qest_run] = combine_xnn_SWOT_config(xnn, Pnn, nR, nt_run, state_ep, ...
    sg_path_kf, cfg.CombineMode);
Qest_med = local_pad_Qest_to_full_time(Qest_run, nR, nt, sic_start_day_idx);
Qest_med = scale_output_anomaly(Qest_med, sg_path, cfg.OutputAnomScale, cfg.OutputGroupScales);
Qest_med = apply_output_bounds(Qest_med, sg_path, cfg.OutputBoundsMode);
Qest_med = smooth_output_days(Qest_med, sg_path, cfg.OutputSmoothDays);
end

function [xs, Ps] = rts_smooth_22day(xf, Pf, xpred, Ppred, Phi)
xs = xf;
Ps = Pf;
n = numel(xf);
if n <= 1
    return;
end

for i = (n - 1):-1:1
    den = (Ppred{i + 1} + Ppred{i + 1}') ./ 2;
    ridge = max(1e-9 * mean(abs(diag(den)), 'omitnan'), eps);
    C = (Pf{i} * Phi') / (den + ridge * eye(size(den, 1)));
    xs{i} = xf{i} + C * (xs{i + 1} - xpred{i + 1});
    Ps{i} = Pf{i} + C * (Ps{i + 1} - Ppred{i + 1}) * C';
    Ps{i} = (Ps{i} + Ps{i}') ./ 2;
end
end

function [Q_tmp, Qest] = combine_xnn_SWOT_config(xnn, Pnn, nR, nt, state_ep, sg_path, combine_mode)
if string(combine_mode) == "median"
    [Q_tmp, Qest] = combine_xnn_SWOT(xnn, Pnn, nR, nt, state_ep, sg_path);
    return;
end

[Q_tmp, V_tmp] = build_window_estimate_and_variance(xnn, Pnn, nR, nt, state_ep, sg_path);
Qest = cell(1, 1);
obs_mask = [];
if any(string(combine_mode) == ["obs_count_center", "obs_prox_center"])
    obs_mask = sic_observation_mask(sg_path, nR, nt);
end
for j = 1:(nt - 1)
    vals = nan(nR, state_ep);
    vars = nan(nR, state_ep);
    for k = 1:state_ep
        vals(:, k) = Q_tmp{k}(:, j);
        vars(:, k) = V_tmp{k}(:, j);
    end
    switch string(combine_mode)
        case "center"
            center_idx = ceil(state_ep / 2);
            q = vals(:, center_idx);
            fallback = median(vals, 2, 'omitnan');
            q(~isfinite(q)) = fallback(~isfinite(q));
            Qest{1}(:, j) = q;
        case "center_weight"
            center_idx = ceil(state_ep / 2);
            w0 = 1 ./ (1 + abs((1:state_ep) - center_idx));
            w = repmat(w0, nR, 1);
            w(~isfinite(vals)) = 0;
            denom = sum(w, 2);
            q = sum(vals .* w, 2) ./ denom;
            fallback = median(vals, 2, 'omitnan');
            q(denom <= 0 | ~isfinite(q)) = fallback(denom <= 0 | ~isfinite(q));
            Qest{1}(:, j) = q;
        case "obs_count_center"
            center_idx = ceil(state_ep / 2);
            center_w = 1 ./ (1 + abs((1:state_ep) - center_idx));
            w = zeros(nR, state_ep);
            for k = 1:state_ep
                obs_count = window_observation_score(obs_mask, j, k, state_ep, "count");
                w(:, k) = center_w(k) .* (1 + obs_count);
            end
            w(~isfinite(vals)) = 0;
            denom = sum(w, 2);
            q = sum(vals .* w, 2) ./ denom;
            fallback = median(vals, 2, 'omitnan');
            q(denom <= 0 | ~isfinite(q)) = fallback(denom <= 0 | ~isfinite(q));
            Qest{1}(:, j) = q;
        case "obs_prox_center"
            center_idx = ceil(state_ep / 2);
            center_w = 1 ./ (1 + abs((1:state_ep) - center_idx));
            w = zeros(nR, state_ep);
            for k = 1:state_ep
                obs_score = window_observation_score(obs_mask, j, k, state_ep, "proximity");
                w(:, k) = center_w(k) .* (1 + obs_score);
            end
            w(~isfinite(vals)) = 0;
            denom = sum(w, 2);
            q = sum(vals .* w, 2) ./ denom;
            fallback = median(vals, 2, 'omitnan');
            q(denom <= 0 | ~isfinite(q)) = fallback(denom <= 0 | ~isfinite(q));
            Qest{1}(:, j) = q;
        case "median"
            Qest{1}(:, j) = median(vals, 2, 'omitnan');
        case "var_weight"
            w = 1 ./ max(vars, eps);
            w(~isfinite(vals) | ~isfinite(w)) = 0;
            denom = sum(w, 2);
            q = sum(vals .* w, 2) ./ denom;
            fallback = median(vals, 2, 'omitnan');
            q(denom <= 0 | ~isfinite(q)) = fallback(denom <= 0 | ~isfinite(q));
            Qest{1}(:, j) = q;
        case "arith"
            Qest{1}(:, j) = mean(vals, 2, 'omitnan');
        otherwise
            error('Unknown CombineMode: %s.', string(combine_mode));
    end
end
end

function score = window_observation_score(obs_mask, target_day, state_idx, state_ep, mode)
nR = size(obs_mask, 1);
window_start = target_day - state_idx + 1;
window_end = window_start + state_ep - 1;
lo = max(1, window_start);
hi = min(size(obs_mask, 2), window_end);
if lo > hi
    score = zeros(nR, 1);
    return;
end

switch string(mode)
    case "count"
        score = sum(obs_mask(:, lo:hi), 2);
    case "proximity"
        tau = state_ep / 3;
        days = lo:hi;
        temporal_weight = exp(-abs(days - target_day) ./ tau);
        score = sum(obs_mask(:, lo:hi) .* temporal_weight, 2);
    otherwise
        error('Unknown observation score mode: %s.', string(mode));
end
end

function obs_mask = sic_observation_mask(sg_path, nR, nt)
obs_mask = false(nR, nt);
if ~isfield(sg_path, 'Q_SIC4DVar') || isempty(sg_path.Q_SIC4DVar) || ...
        isempty(sg_path.Q_SIC4DVar{1, 1})
    return;
end

q_cells = sg_path.Q_SIC4DVar{1, 1};
nr = min(nR, size(q_cells, 1));
nd = min(nt, size(q_cells, 2));
if iscell(q_cells)
    obs_mask(1:nr, 1:nd) = ~cellfun(@isempty, q_cells(1:nr, 1:nd));
else
    obs_mask(1:nr, 1:nd) = isfinite(q_cells(1:nr, 1:nd));
end
end

function [Q_tmp, V_tmp] = build_window_estimate_and_variance(xnn, Pnn, nR, nt, state_ep, sg_path)
Q_true = sg_path.Q_prior{1, 1}(:, 1);
Q = nan(nR * state_ep, numel(xnn));
V = nan(nR * state_ep, numel(Pnn));
for i = 1:numel(xnn)
    Q(:, i) = xnn{i};
    V(:, i) = diag(Pnn{i});
end

Q_tmp = cell(1, state_ep);
V_tmp = cell(1, state_ep);
for i = 1:state_ep
    row_idx = (i - 1) * nR + (1:nR);
    if i == 1
        Q_tmp{i} = [Q(row_idx, :), reshape(Q((i * nR + 1):end, end), nR, state_ep - 1)];
        V_tmp{i} = [V(row_idx, :), reshape(V((i * nR + 1):end, end), nR, state_ep - 1)];
    elseif i == state_ep
        Q_tmp{i} = [reshape(Q(1:(end - nR), 1), nR, state_ep - 1), Q(row_idx, :)];
        V_tmp{i} = [reshape(V(1:(end - nR), 1), nR, state_ep - 1), V(row_idx, :)];
    else
        Q_tmp{i} = [reshape(Q(1:((i - 1) * nR), 1), nR, i - 1), ...
            Q(row_idx, :), reshape(Q((i * nR + 1):end, end), nR, state_ep - i)];
        V_tmp{i} = [reshape(V(1:((i - 1) * nR), 1), nR, i - 1), ...
            V(row_idx, :), reshape(V((i * nR + 1):end, end), nR, state_ep - i)];
    end
    Q_tmp{i} = Q_tmp{i} + mean(Q_true, 2);
end
end

function R = apply_innovation_r_gating(R, innovation, H, P_pred, cfg)
if ~isfinite(cfg.InnovGateSigma) || cfg.InnovGateSigma <= 0 || ...
        cfg.InnovRMaxScale <= 1 || isempty(R)
    return;
end

pred_var = diag(H * P_pred * H');
obs_var = diag(R);
innov_std = abs(innovation) ./ sqrt(max(pred_var + obs_var, eps));
scale = ones(size(obs_var));
mask = innov_std > cfg.InnovGateSigma;
if any(mask)
    scale(mask) = min(cfg.InnovRMaxScale, ...
        (innov_std(mask) ./ cfg.InnovGateSigma) .^ cfg.InnovRPower);
    R = diag(obs_var .* scale);
end
end

function Qest_med = scale_output_anomaly(Qest_med, sg_path, scale_factor, group_scales)
if (scale_factor == 1 && isempty(group_scales)) || isempty(Qest_med) || isempty(Qest_med{1})
    return;
end
Qprior = sg_path.Q_prior{1, 1}(:, 1);
Q = Qest_med{1};
scale_vec = scale_factor .* ones(size(Qprior));
if ~isempty(group_scales)
    scale_vec = scale_vec .* output_group_scale_vector(Qprior, group_scales);
end
Qest_med{1} = Qprior + scale_vec .* (Q - Qprior);
end

function Qest_med = apply_output_bounds(Qest_med, sg_path, bounds_mode)
if isempty(Qest_med) || isempty(Qest_med{1})
    return;
end

mode = lower(string(bounds_mode));
if mode == "none"
    return;
end

Q = Qest_med{1};
switch mode
    case "nonnegative"
        Qest_med{1} = max(Q, 0);

    case "prior_minmax"
        qmin = sg_path.minQ_prior{1, 1}(:, 1);
        qmax = sg_path.maxQ_prior{1, 1}(:, 1);
        lo = min(qmin, qmax);
        hi = max(qmin, qmax);
        lo(~isfinite(lo)) = 0;
        lo = max(lo, 0);
        bad_hi = ~isfinite(hi) | hi < lo;
        hi(bad_hi) = Inf;
        Qest_med{1} = min(max(Q, lo), hi);

    otherwise
        error('Unknown OutputBoundsMode: %s.', string(bounds_mode));
end
end

function Qest_med = smooth_output_days(Qest_med, sg_path, smooth_days)
if isempty(smooth_days) || all(smooth_days <= 1) || isempty(Qest_med) || isempty(Qest_med{1})
    return;
end

Q = Qest_med{1};
if isscalar(smooth_days)
    Qest_med{1} = smoothdata(Q, 2, 'movmedian', smooth_days, 'omitnan');
    return;
end

if numel(smooth_days) ~= 3
    error('OutputSmoothDays must be scalar or [low mid high].');
end
Qprior = sg_path.Q_prior{1, 1}(:, 1);
group_idx = qprior_group_index(Qprior);
for ig = 1:3
    rows = group_idx == ig;
    span = smooth_days(ig);
    if span > 1 && any(rows)
        Q(rows, :) = smoothdata(Q(rows, :), 2, 'movmedian', span, 'omitnan');
    end
end
Qest_med{1} = Q;
end

function Q_st = apply_group_process_scale(Q_st, sg_path, state_ep, group_scales)
if isempty(group_scales)
    return;
end
Qprior = sg_path.Q_prior{1, 1}(:, 1);
reach_scale = output_group_scale_vector(Qprior, group_scales);
state_scale = repmat(reach_scale(:), state_ep, 1);
state_scale(~isfinite(state_scale) | state_scale <= 0) = 1;
std_scale = sqrt(state_scale);
Q_st = Q_st .* (std_scale * std_scale');
end

function scale_vec = output_group_scale_vector(Qprior, group_scales)
if numel(group_scales) ~= 3
    error('OutputGroupScales must contain [low mid high].');
end
group_idx = qprior_group_index(Qprior);
scale_vec = nan(size(Qprior));
for ig = 1:3
    scale_vec(group_idx == ig) = group_scales(ig);
end
scale_vec(~isfinite(scale_vec)) = 1;
end

function group_idx = qprior_group_index(Qprior)
global OBS_PERCENT_QPRIOR
if isempty(OBS_PERCENT_QPRIOR) || ~isfield(OBS_PERCENT_QPRIOR, 'Q_SIC4DVar') || ...
        ~isfield(OBS_PERCENT_QPRIOR.Q_SIC4DVar, 'Qprior_group_edges')
    error('OBS_PERCENT_QPRIOR.Q_SIC4DVar.Qprior_group_edges is required for Qprior grouping.');
end
edges = OBS_PERCENT_QPRIOR.Q_SIC4DVar.Qprior_group_edges;
if numel(edges) < 2
    error('Qprior_group_edges must contain two thresholds.');
end
group_idx = nan(size(Qprior));
group_idx(Qprior <= edges(1)) = 1;
group_idx(Qprior > edges(1) & Qprior <= edges(2)) = 2;
group_idx(Qprior > edges(2)) = 3;
end

function x0 = build_initial_state(sg_path, start_day_idx, state_ep, init_mode)
switch string(init_mode)
    case "zero"
        nR = numel(sg_path.Q_prior{1, 1}(:, 1));
        x0 = zeros(nR * state_ep, 1);
    case "sic_rawx0"
        [~, x0_mat, support] = build_sic_linear_x0(sg_path, start_day_idx, state_ep);
        x0_mat(support ~= 1) = 0;
        x0 = reshape(x0_mat, [], 1);
    otherwise
        x0 = build_sic_linear_x0(sg_path, start_day_idx, state_ep);
end
end

function sg_path = get_path_struct_local(basin, ip)
nPath = numel(basin.paths);
sg_path = struct();
fns = fieldnames(basin);
for k = 1:numel(fns)
    fld = fns{k};
    val = basin.(fld);
    if iscell(val) && numel(val) == nPath
        sg_path.(fld) = {val{ip}};
    else
        sg_path.(fld) = val;
    end
end
end

function all = init_metric_arrays()
all.corr = [];
all.NSE = [];
all.rRMSE = [];
all.rB = [];
all.qprior = [];
all.qgroup = [];
all.task = [];
all.ib = [];
all.ip = [];
all.reach = [];
end

function all = append_metrics(all, vali, qprior, task_idx, ib, ip)
corr_vals = metric_col(vali, 'corr');
nse_vals = metric_col(vali, 'NSE');
rrmse_vals = metric_col(vali, 'rRMSE');
rb_vals = metric_col(vali, 'rB');
n = min([numel(corr_vals), numel(nse_vals), numel(rrmse_vals), numel(rb_vals), numel(qprior)]);
if n == 0
    return;
end
corr_vals = corr_vals(1:n);
nse_vals = nse_vals(1:n);
rrmse_vals = rrmse_vals(1:n);
rb_vals = rb_vals(1:n);
qprior = qprior(1:n);
all.corr = [all.corr; corr_vals]; %#ok<AGROW>
all.NSE = [all.NSE; nse_vals]; %#ok<AGROW>
all.rRMSE = [all.rRMSE; rrmse_vals]; %#ok<AGROW>
all.rB = [all.rB; rb_vals]; %#ok<AGROW>
all.qprior = [all.qprior; qprior(:)]; %#ok<AGROW>
qgroup = qprior_group_index(qprior);
all.qgroup = [all.qgroup; qgroup(:)]; %#ok<AGROW>
all.task = [all.task; repmat(task_idx, n, 1)]; %#ok<AGROW>
all.ib = [all.ib; repmat(ib, n, 1)]; %#ok<AGROW>
all.ip = [all.ip; repmat(ip, n, 1)]; %#ok<AGROW>
all.reach = [all.reach; (1:n)']; %#ok<AGROW>
end

function x = metric_col(S, field)
if isempty(S) || ~isfield(S, field)
    x = nan(0, 1);
    return;
end
x = S.(field);
if iscell(x)
    y = [];
    for i = 1:numel(x)
        y = [y; x{i}(:)]; %#ok<AGROW>
    end
    x = y;
else
    x = x(:);
end
end

function [kf, interp, n_common] = paired_summary(all_kf, all_interp)
[kf.corr, interp.corr, n_common.corr] = paired_metric(all_kf.corr, all_interp.corr);
[kf.NSE, interp.NSE, n_common.NSE] = paired_metric(all_kf.NSE, all_interp.NSE);
[kf.rRMSE, interp.rRMSE, n_common.rRMSE] = paired_metric(all_kf.rRMSE, all_interp.rRMSE);
[kf.rB, interp.rB, n_common.rB] = paired_metric(all_kf.rB, all_interp.rB);
n_common = min([n_common.corr, n_common.NSE, n_common.rRMSE, n_common.rB]);
end

function [ma, mb, n] = paired_metric(a, b)
n0 = min(numel(a), numel(b));
a = a(1:n0);
b = b(1:n0);
mask = isfinite(a) & isfinite(b);
ma = median(a(mask), 'omitnan');
mb = median(b(mask), 'omitnan');
n = nnz(mask);
end

function out = paired_summary_by_qgroup(all_kf, all_interp)
names = {'low', 'mid', 'high'};
out = struct();
for ig = 1:3
    mask = all_kf.qgroup == ig & all_interp.qgroup == ig;
    [kf, interp, n_common] = paired_summary(mask_metric_arrays(all_kf, mask), ...
        mask_metric_arrays(all_interp, mask));
    out.(names{ig}) = struct('kf', kf, 'interp', interp, 'n_common', n_common);
end
end

function all_masked = mask_metric_arrays(all, mask)
n = min([numel(mask), numel(all.corr), numel(all.NSE), numel(all.rRMSE), numel(all.rB)]);
mask = mask(1:n);
all_masked = struct();
all_masked.corr = all.corr(1:n);
all_masked.NSE = all.NSE(1:n);
all_masked.rRMSE = all.rRMSE(1:n);
all_masked.rB = all.rB(1:n);
all_masked.corr = all_masked.corr(mask);
all_masked.NSE = all_masked.NSE(mask);
all_masked.rRMSE = all_masked.rRMSE(mask);
all_masked.rB = all_masked.rB(mask);
end

function stats = append_group_stats(stats, group_stats)
names = {'low', 'mid', 'high'};
for i = 1:numel(names)
    nm = names{i};
    kf = group_stats.(nm).kf;
    interp = group_stats.(nm).interp;
    n_common = group_stats.(nm).n_common;
    stats.(sprintf('N_%s', nm)) = n_common;
    stats.(sprintf('corr_kf_%s', nm)) = kf.corr;
    stats.(sprintf('corr_interp_%s', nm)) = interp.corr;
    stats.(sprintf('corr_delta_%s', nm)) = kf.corr - interp.corr;
    stats.(sprintf('NSE_kf_%s', nm)) = kf.NSE;
    stats.(sprintf('NSE_interp_%s', nm)) = interp.NSE;
    stats.(sprintf('NSE_delta_%s', nm)) = kf.NSE - interp.NSE;
    stats.(sprintf('rRMSE_kf_%s', nm)) = kf.rRMSE;
    stats.(sprintf('rRMSE_interp_%s', nm)) = interp.rRMSE;
    stats.(sprintf('rRMSE_delta_%s', nm)) = kf.rRMSE - interp.rRMSE;
    stats.(sprintf('rB_kf_%s', nm)) = kf.rB;
    stats.(sprintf('rB_interp_%s', nm)) = interp.rB;
    stats.(sprintf('rB_delta_%s', nm)) = kf.rB - interp.rB;
end
end

function [summary_table, group_summary_table, files] = save_detail_outputs(detail, stats, cfg, opts, root)
tag = opts.DetailTag;
if isempty(tag)
    tag = sprintf('%s_%s', opts.ConfigSet, char(cfg.Name));
end
tag = regexprep(tag, '[^A-Za-z0-9_]+', '_');
stamp = datestr(now, 'yyyymmdd_HHMMSS');
base = fullfile(root, sprintf('sic22_compare_%s_%s', tag, stamp));

summary_table = build_comparison_summary(detail.kf, detail.interp, "all");
group_summary_table = build_group_comparison_summary(detail.kf, detail.interp);

files = struct();
files.mat = [base '.mat'];
files.png = [base '_cdf.png'];
files.fig = [base '_cdf.fig'];
files.summary_csv = [base '_summary.csv'];
files.group_summary_csv = [base '_group_summary.csv'];

save(files.mat, 'detail', 'stats', 'summary_table', 'group_summary_table', '-v7.3');
writetable(summary_table, files.summary_csv);
writetable(group_summary_table, files.group_summary_csv);

plot_sic22_kf_vs_interp_cdf(detail.kf, detail.interp, stats);
savefig(gcf, files.fig);
exportgraphics(gcf, files.png, 'Resolution', 220);

fprintf('Saved detailed SIC22 comparison outputs:\n');
fprintf('  %s\n', files.mat);
fprintf('  %s\n', files.png);
fprintf('  %s\n', files.fig);
fprintf('  %s\n', files.summary_csv);
fprintf('  %s\n', files.group_summary_csv);
end

function T = build_group_comparison_summary(kf, interp)
group_names = ["low"; "mid"; "high"];
T = table();
for ig = 1:numel(group_names)
    mask = kf.qgroup == ig & interp.qgroup == ig;
    Tg = build_comparison_summary(mask_metric_arrays(kf, mask), ...
        mask_metric_arrays(interp, mask), group_names(ig));
    T = [T; Tg]; %#ok<AGROW>
end
end

function T = build_comparison_summary(kf, interp, group_name)
metric_names = ["corr"; "NSE"; "rRMSE"; "rB"];
higher_is_better = [true; true; false; false];
T = table('Size', [numel(metric_names), 14], ...
    'VariableTypes', {'string','string','double','double','double','double','double', ...
    'double','double','double','double','double','double','double'}, ...
    'VariableNames', {'group','metric','N','kf_median','interp_median','delta_median', ...
    'kf_mean','interp_mean','kf_p25','kf_p75','interp_p25','interp_p75','win_rate','tie_rate'});

for im = 1:numel(metric_names)
    metric = metric_names(im);
    [a, b] = paired_values(kf.(metric), interp.(metric));
    if higher_is_better(im)
        wins = a > b;
    else
        wins = a < b;
    end
    ties = a == b;
    T.group(im) = group_name;
    T.metric(im) = metric;
    T.N(im) = numel(a);
    T.kf_median(im) = median(a, 'omitnan');
    T.interp_median(im) = median(b, 'omitnan');
    T.delta_median(im) = T.kf_median(im) - T.interp_median(im);
    T.kf_mean(im) = mean(a, 'omitnan');
    T.interp_mean(im) = mean(b, 'omitnan');
    T.kf_p25(im) = local_percentile(a, 25);
    T.kf_p75(im) = local_percentile(a, 75);
    T.interp_p25(im) = local_percentile(b, 25);
    T.interp_p75(im) = local_percentile(b, 75);
    T.win_rate(im) = mean(wins, 'omitnan');
    T.tie_rate(im) = mean(ties, 'omitnan');
end
end

function plot_sic22_kf_vs_interp_cdf(kf, interp, stats)
figure('Color', 'w', 'Position', [100, 100, 1300, 850]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

metric_names = {'corr', 'NSE', 'rRMSE', 'rB'};
titles = {'Correlation', 'NSE', 'rRMSE', 'rBias'};
xlabels = {'[-]', '[-]', '[%]', '[%]'};
limits = {[-1, 1], [-2, 1], [0, 300], [0, 200]};

for im = 1:numel(metric_names)
    metric = metric_names{im};
    [a, b] = paired_values(kf.(metric), interp.(metric));
    nexttile;
    hold on;
    [xk, fk] = local_ecdf(a);
    [xi, fi] = local_ecdf(b);
    plot(xi, fi, '--', 'LineWidth', 2.2, 'Color', [0.65, 0.12, 0.16]);
    plot(xk, fk, '-', 'LineWidth', 2.4, 'Color', [0.00, 0.34, 0.70]);
    grid on;
    title(titles{im}, 'FontSize', 16, 'FontWeight', 'normal');
    xlabel(xlabels{im}, 'FontSize', 13);
    ylabel('F(x)', 'FontSize', 13);
    xlim(limits{im});
    legend({sprintf('SIC interp median %.4g', median(b, 'omitnan')), ...
        sprintf('SIC22 KF median %.4g', median(a, 'omitnan'))}, ...
        'Location', 'best', 'FontSize', 11);
    set(gca, 'FontSize', 12);
end

sgtitle(sprintf('%s vs interpolated SIC4DVar, N=%d', ...
    char(stats.Name), stats.N_common), 'Interpreter', 'none', ...
    'FontSize', 18, 'FontWeight', 'bold');
end

function [a, b] = paired_values(a, b)
n = min(numel(a), numel(b));
a = a(1:n);
b = b(1:n);
mask = isfinite(a) & isfinite(b);
a = a(mask);
b = b(mask);
end

function [x, f] = local_ecdf(data)
data = data(isfinite(data));
if isempty(data)
    x = nan;
    f = nan;
    return;
end
x = sort(data(:));
f = (1:numel(x))' ./ numel(x);
x = [x(1); x];
f = [0; f];
end

function p = local_percentile(data, pct)
data = sort(data(isfinite(data)));
if isempty(data)
    p = NaN;
    return;
end
idx = 1 + (numel(data) - 1) * pct / 100;
lo = floor(idx);
hi = ceil(idx);
if lo == hi
    p = data(lo);
else
    w = idx - lo;
    p = (1 - w) * data(lo) + w * data(hi);
end
end
