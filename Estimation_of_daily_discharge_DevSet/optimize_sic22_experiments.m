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
    stats = run_config(tasks, data_KF_out, Phi_save, Q_save, nt, state_ep, use_svs, cfg);
    row = struct2table(stats, 'AsArray', true);
    results = [results; row]; %#ok<AGROW>
    disp(row(:, {'Name','N_common','corr_kf','corr_interp','NSE_kf','NSE_interp', ...
        'rRMSE_kf','rRMSE_interp','rB_kf','rB_interp','score'}));
    save(outfile, 'results', 'configs', 'tasks', 'opts', '-v7.3');
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
parser.parse(varargin{:});
opts = parser.Results;
opts.ConfigSet = char(opts.ConfigSet);
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
    'OutputGroupScales', [], 'QGroupScales', []);

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
end
end

function stats = run_config(tasks, data_KF_out, Phi_save, Q_save, nt, state_ep, use_svs, cfg)
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
        Q_st = Q_st_base .* cfg.QScale;
        Q_st = apply_group_process_scale(Q_st, sg_path, state_ep, cfg.QGroupScales);
        if cfg.RidgeFrac > 0
            qprior = sg_path.Q_prior{1, 1}(:, 1);
            ridge = repmat((cfg.RidgeFrac .* max(abs(qprior), 1)).^2, state_ep, 1);
            Q_st = Q_st + diag(ridge(:));
        end
        Qest = run_one_path_sic22_config(sg_path, Phi_st, Q_st, nR, nt, state_ep, cfg);
        [vali_est, ~, ~, ~, ~, ~, vali_sic_i] = validation4_sic(Qest, sg_path, nR, use_svs);
        qprior = sg_path.Q_prior{1, 1}(:, 1);
        all_kf = append_metrics(all_kf, vali_est, qprior);
        all_interp = append_metrics(all_interp, vali_sic_i, qprior);
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
stats.P0Scale = cfg.P0Scale;
stats.InitMode = string(cfg.InitMode);
stats.OutputAnomScale = cfg.OutputAnomScale;
stats.OutputGroupScales = string(mat2str(cfg.OutputGroupScales));
stats.QGroupScales = string(mat2str(cfg.QGroupScales));
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

for i = 1:(nt_run - state_ep)
    x_pred = Phi_st * xn;
    P_pred = (Phi_st * P * Phi_st') + Q_st;
    [H_Q, z_Q, R_Q] = build_H_obs_SWOT_Q(sg_path_kf, state_ep, i, 1, ...
        cfg.ObsUncMode, cfg.ObsUncScale);
    if ~isempty(z_Q)
        [H, zn, R] = append_Qobs([], [], [], H_Q, z_Q, R_Q);
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

[~, Qest_run] = combine_xnn_SWOT(xnn, Pnn, nR, nt_run, state_ep, sg_path_kf);
Qest_med = local_pad_Qest_to_full_time(Qest_run, nR, nt, sic_start_day_idx);
Qest_med = scale_output_anomaly(Qest_med, sg_path, cfg.OutputAnomScale, cfg.OutputGroupScales);
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
all.qgroup = [];
end

function all = append_metrics(all, vali, qprior)
corr_vals = metric_col(vali, 'corr');
all.corr = [all.corr; corr_vals]; %#ok<AGROW>
all.NSE = [all.NSE; metric_col(vali, 'NSE')]; %#ok<AGROW>
all.rRMSE = [all.rRMSE; metric_col(vali, 'rRMSE')]; %#ok<AGROW>
all.rB = [all.rB; metric_col(vali, 'rB')]; %#ok<AGROW>
qgroup = qprior_group_index(qprior);
qgroup = qgroup(1:min(numel(qgroup), numel(corr_vals)));
all.qgroup = [all.qgroup; qgroup(:)]; %#ok<AGROW>
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
