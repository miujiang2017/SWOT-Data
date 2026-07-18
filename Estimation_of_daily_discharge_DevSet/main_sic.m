clear all
close all
clc

addpath(fullfile(pwd, '..', 'RiverSP'));
addpath(fullfile(pwd, '..', 'SWORD V16'));
addpath(fullfile(pwd, '..', 'SoS'));


%% Default settings
% Path to the folder containing the SoS files
folder_path = fullfile(pwd, '..', 'SoS', 'SoS Dataset Oct');
% subset_ids = jsondecode(fileread([folder_path,'/reaches_of_interest_devset.json']));

% Prefix of the .nc files ('af', 'eu', 'na', 'oc' or 'sa')
file_prefix = 'na';
% Constrained or unconstrained ('con' or 'uncon')
sos_type = 'uncon';

%% Read gauge and prior data from SoS file and save in basin.mat
% read prior from SoS file (sword_v17_SOS_priors.nc)
% SoS_PriorsData_v17 = read_SoS_Priorsv005(folder_path, file_prefix, 17);
% 
% % translate SWORD reach IDs from version v17b to v16
% SoS_PriorsData_v16_trans = SoS_PriorsData_map_v17b_to_v16(SoS_PriorsData_v17, file_prefix);

% read prior from SoS file (sword_v16_SOS_priors.nc)
SoS_PriorsData_v16 = read_SoS_Priorsv005(folder_path, file_prefix, 16);

% copy gauge data from v17b to v16
% SoS_PriorsData_v16 = copyGaugeByReachID(SoS_PriorsData_v16, SoS_PriorsData_v17,file_prefix);

% find reach ids with valid ML prior and save some attributes from SWORD (SWORD_v16)
basins =  enumerate_subset_paths_by_basin(SoS_PriorsData_v16, file_prefix);

% Read DevSet reach ids
basins = add_SoS_priors_to_basins(basins, SoS_PriorsData_v16);

% add SVS gauge discharge
basins = add_SVS_gauge_to_basins(basins);%v16
% basins = add_SVS_gauge_to_basins2(basins, file_prefix);% v17
%% read result
SoS_ResultsData = read_SoS_Resultsv005(folder_path, file_prefix, sos_type);
IRIS_file = 'IRIS_2.9.nc'; % read IRIS (SWORD 16)
%IRIS_file = 'IRIS_3.3.nc'; % read IRIS (SWORD 17)
basins = add_SoS_results_to_basins(basins, SoS_ResultsData, IRIS_file);
opts.jump_threshold = 3;
opts.max_segment_ratio = 5;
opts.min_segment_length = 1;
opts.allow_singleton_at_hard_break = true;

[basins, split_info] = split_basins_paths_by_Qprior(basins, opts);
use_svs = true;
out = obs_percent_Qprior(basins, use_svs);
global OBS_PERCENT_QPRIOR
OBS_PERCENT_QPRIOR = out;
obs_unc_mode = 'mean_percent'; % 'mean_percent': Qprior*固定percent；'qprior_group': Qprior*分组percent
obs_unc_scale = 1;
% [k, ~] = compute_k(basins);
%% Filter paths with gauge stations and SWOT discharge
% option = 1: 需要有任意 SWOT Q 产品
% option = 2: 需要有 SVS gauge
basins_out = filter_basins(basins,2);

%% Pull reach data in RiverSP using Hydrocron
start_date = '2023-03-29';
end_date = '2025-05-02';
nt = datenum(end_date) - datenum(start_date) + 1;

% basins_out = add_RiverSP_ReachData_to_basins(basins_out, start_date, end_date);
% [basins_out2, n2_before, n2_after] = rerun_riversp(basins_out, start_date, end_date);
% basins_out=basins_out2;
basinsv16_1 = basins_out(1:100);
basinsv16_2 = basins_out(101:200);
basinsv16_3 = basins_out(201:300);
basinsv16_4 = basins_out(301:400);
basinsv16_5 = basins_out(401:500);
basinsv16_6 = basins_out(501:568);
% save('basinsv16_1.mat','basinsv16_1');
% save('basinsv16_2.mat','basinsv16_2');
% save('basinsv16_3.mat','basinsv16_3');
% save('basinsv16_4.mat','basinsv16_4');
% save('basinsv16_5.mat','basinsv16_5');
% save('basinsv16_6.mat','basinsv16_6');
load('basinsv16_1.mat');
load('basinsv16_2.mat');
load('basinsv16_3.mat');
load('basinsv16_4.mat');
load('basinsv16_5.mat');
load('basinsv16_6.mat');
basins_out_old = [basinsv16_1,basinsv16_2,basinsv16_3,basinsv16_4,basinsv16_5,basinsv16_6];
basins_out = add_RiverSP_ReachData_to_basins_with_old(basins_out, basins_out_old, start_date, end_date, true);

%% Generate data for KF
start_date = '2023-03-29'; 
end_date = '2025-05-02';
state_ep = 22;
data_KF = data_for_KF(basins_out, start_date, end_date, state_ep);
data_KF_out = filter_KF(data_KF);

%% Generate start value
data_KF_out = build_cDtau(data_KF_out);

% Loop over each basin
Q_results = [];
%% Kalman filtering
load('Phi_save.mat')
load('Q_save.mat')
%%
for ib =1:6%numel(data_KF_out)%1:numel(data_KF_out)
    ib
    sg_basin = data_KF_out(ib);
    % Loop over each path in the basin
    for ip = 1%:numel(sg_basin.paths)
        sg_path = get_path_struct(sg_basin, ip);
        % sg_path = subset_sg_path_reaches(sg_path, 35, 46);  % 只保留第 3 到第 8 个 reach
        nR = length(sg_path.rch_len{1});  % Number of reaches
        sic_start_day_idx = local_first_sic_path_day_idx(sg_path, nR);
        if isnan(sic_start_day_idx)
            Qest_med = local_nan_Qest(nR, nt);
            [vali_estmed, ...
                vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
                vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
                vali_SADS_interp, vali_MetroMan_interp] = ...
                validation4_sic(Qest_med, sg_path, nR,use_svs);
            Q_results = save_Qest(Q_results, ib, ip, ...
                Qest_med, ...
                vali_estmed, ...
                vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
                vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
                vali_SADS_interp, vali_MetroMan_interp);
            continue
        end
        nt_run = nt - sic_start_day_idx + 1;
        if nt_run <= state_ep
            Qest_med = local_nan_Qest(nR, nt);
            [vali_estmed, ...
                vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
                vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
                vali_SADS_interp, vali_MetroMan_interp] = ...
                validation4_sic(Qest_med, sg_path, nR,use_svs);
            Q_results = save_Qest(Q_results, ib, ip, ...
                Qest_med, ...
                vali_estmed, ...
                vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
                vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
                vali_SADS_interp, vali_MetroMan_interp);
            continue
        end
        sg_path_kf = local_slice_sic_daily_cells(sg_path, sic_start_day_idx);

        %% Build transition matrix Phi and process noise
        % [Phi_st, Q_st, ~] = build_Phi_SWOT(sg_path_kf, state_ep);
        %  Phi_save{ib}{ip} =Phi_st;
        % Q_save{ib}{ip} =Q_st ;
        Phi_st=Phi_save{ib}{ip};
        Q_st = Q_save{ib}{ip};
        obs_mean = sg_path.Q_prior{1, 1}(:,1);
        xn1n1 = build_sic_linear_x0(sg_path, sic_start_day_idx, state_ep);%reshape(sg_path.start_value{1,1} - obs_mean, [], 1);
        sigma0 = calc_sigma0(sg_path);
        tmp=repmat(sigma0.^2, state_ep, 1);%(sg_path.start_value{1,1}*0.18).^2;
        Pn1n1 = diag(tmp(:));

        i = 1;
        %         %% 1. Initialization and Pre-calculations for each path
        xnn1(:,1) = Phi_st * xn1n1;
        Pnn1{1} = (Phi_st * Pn1n1 * Phi_st') + Q_st;

        % Build the observation matrix for the current path (you will need to adjust this for each path)
        % [H, zn, R, z_idx, ~] = build_H_obs_SWOT_dA(sg_path, i, state_ep);
        % 1: SIC4DVar 2: MOMMA 3: geoBAM 4: MetroMan 5:SADS
        [H_Q,z_Q,R_Q] = build_H_obs_SWOT_Q(sg_path_kf,state_ep,i,1,obs_unc_mode,obs_unc_scale); %
        % [H_Q2,z_Q2,R_Q2] = build_H_obs_SWOT_Q(sg_path,state_ep,i,2); %
        % [H_Q3,z_Q3,R_Q3] = build_H_obs_SWOT_Q(sg_path,state_ep,i,3); %
        % [H_Q4,z_Q4,R_Q4] = build_H_obs_SWOT_Q(sg_path,state_ep,i,4); %
        % [H_Q5,z_Q5,R_Q5] = build_H_obs_SWOT_Q(sg_path,state_ep,i,5); %
        if ~isempty(z_Q)%| ~isempty(z_Q2)|~isempty(z_Q3)|~isempty(z_Q4)%|~isempty(z_Q5)
            H =[];R=[];zn=[];
            [H, zn, R] = append_Qobs(H, zn, R, H_Q,  z_Q,  R_Q);
            % [H, zn, R] = append_Qobs(H, zn, R, H_Q2, z_Q2, R_Q2);
            % [H, zn, R] = append_Qobs(H, zn, R, H_Q3, z_Q3, R_Q3);
            % [H, zn, R] = append_Qobs(H, zn, R, H_Q4, z_Q4, R_Q4);
            % [H, zn, R] = append_Qobs(H, zn, R, H_Q5, z_Q5, R_Q5);

            % Berechnung Kalman Gain:
            Kn = Pnn1{i} * H' * pinv(H * Pnn1{i} * H' + R);

            % Update durch Beobachtung:
            xnn{i} = xnn1(:, i) + Kn * (zn - H * xnn1(:, i));

            % Berechnung der a-posteriori Kovarianz:
            Pnn{i} = (eye(state_ep * nR) - Kn * H) * Pnn1{i};

        else

            xnn{i} = xnn1(:,i);
            Pnn{i} = Pnn1{i};

        end
        %% Other iterations
        for i = 2:nt_run-state_ep
            % Pre-calculations for the next iteration step
            xnn1(:,i) = Phi_st * xnn{i-1};
            Pnn1{i} = (Phi_st * Pnn{i-1} * Phi_st') + Q_st;

            % Build the observation matrix for the current path (you will need to adjust this for each path)
            % [H, zn, R, z_idx, ~] = build_H_obs_SWOT_dA(sg_path, i, state_ep);
            % 1: SIC4DVar 2: MOMMA 3: geoBAM
            [H_Q,z_Q,R_Q] = build_H_obs_SWOT_Q(sg_path_kf,state_ep,i,1,obs_unc_mode,obs_unc_scale); %
            % [H_Q2,z_Q2,R_Q2] = build_H_obs_SWOT_Q(sg_path,state_ep,i,2); %
            % [H_Q3,z_Q3,R_Q3] = build_H_obs_SWOT_Q(sg_path,state_ep,i,3); %
            % [H_Q4,z_Q4,R_Q4] = build_H_obs_SWOT_Q(sg_path,state_ep,i,4); %
            % [H_Q5,z_Q5,R_Q5] = build_H_obs_SWOT_Q(sg_path,state_ep,i,5); %
            if ~isempty(z_Q)%| ~isempty(z_Q2)|~isempty(z_Q4)%|~isempty(z_Q5)
                H =[];R=[];zn=[];
                [H, zn, R] = append_Qobs(H, zn, R, H_Q,  z_Q,  R_Q);
                % [H, zn, R] = append_Qobs(H, zn, R, H_Q2, z_Q2, R_Q2);
                %[H, zn, R] = append_Qobs(H, zn, R, H_Q3, z_Q3, R_Q3);
                % [H, zn, R] = append_Qobs(H, zn, R, H_Q4, z_Q4, R_Q4);
                % [H, zn, R] = append_Qobs(H, zn, R, H_Q5, z_Q5, R_Q5);

                % Compute Kalman gain
                Kn = Pnn1{i} * H' * pinv(H * Pnn1{i} * H' + R);

                % Update state estimate
                xnn{i} = xnn1(:,i) + Kn * (zn - H * xnn1(:,i));

                % Update covariance estimate
                Pnn{i} = (eye(state_ep * nR) - Kn * H) * Pnn1{i};
            else
                % If no observation, just propagate the previous state and covariance
                xnn{i} = xnn1(:,i);
                Pnn{i} = Pnn1{i};
            end
        end

        %% Store results for the current path
        [~, Qest_med_kf] = combine_xnn_SWOT(xnn, Pnn, nR, nt_run, state_ep, sg_path_kf);
        Qest_med = local_pad_Qest_to_full_time(Qest_med_kf, nR, nt, sic_start_day_idx);
        [vali_estmed, ...
            vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
            vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
            vali_SADS_interp, vali_MetroMan_interp] = ...
            validation4_sic(Qest_med, sg_path, nR,use_svs);
        % vali_estmed.NSE
        % Q_results(263).vali_estmed{1, 1}.NSE
        % Q_results(263).vali_SIC4DVar{1, 1}.NSE
        % Q_results(263).vali_geoBAM{1, 1}.NSE
        % Q_results(263).vali_MetroMan{1, 1}.NSE
        Q_results = save_Qest(Q_results, ib, ip, ...
            Qest_med, ...
            vali_estmed, ...
            vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
            vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
            vali_SADS_interp, vali_MetroMan_interp);


        %% Clear
        clear xnn1 Pnn1 xnn Pnn
    end
end
%%
%load('Q_results.mat')
use_svs=true;
for ib =1:numel(data_KF_out)%1:numel(data_KF_out)
    sg_basin = data_KF_out(ib);
    % Loop over each path in the basin
    for ip = 1:numel(sg_basin.paths)
        sg_path = get_path_struct(sg_basin, ip);
        nR = length(sg_path.rch_len{1});  % Number of reaches
        Qest_med = Q_results(ib).Qest_med{1, ip}  ;
        [vali_estmed, ...
            vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
            vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
            vali_SADS_interp, vali_MetroMan_interp] = ...
            validation4(Qest_med, sg_path, nR,use_svs);
                Q_results = save_Qest(Q_results, ib, ip, ...
            Qest_med, ...
            vali_estmed, ...
            vali_SIC4DVar, vali_MOMMA, vali_geoBAM, vali_SADS, vali_MetroMan, ...
            vali_SIC4DVar_interp, vali_MOMMA_interp, vali_geoBAM_interp, ...
            vali_SADS_interp, vali_MetroMan_interp);
    end
end
plot_reach_metric_cdf(Q_results);
plot_timeseries(Q_results, data_KF_out, start_date);
% 
plot_all_metrics_on_map(data_KF_out, Q_results, file_prefix)
plot_reach_relative_error_cdf(Q_results, data_KF_out, start_date)
plot_reach_metric_barplot(Q_results, data_KF_out)
plot_reaches_on_map(data_KF_out, file_prefix)
plot_metric_improvement_boxchart(Q_results)

%%
diag_rows = table();

for ib = 1:numel(data_KF_out)
    sg_basin = data_KF_out(ib);

    if ~isfield(sg_basin,'paths') || isempty(sg_basin.paths)
        continue
    end

    for ip = 1:numel(sg_basin.paths)

        sg_path = get_path_struct(sg_basin, ip);

        if ~isfield(sg_path,'Q_prior') || isempty(sg_path.Q_prior) || isempty(sg_path.Q_prior{1})
            continue
        end

        Qprior = sg_path.Q_prior{1}(:,1);
        nR = numel(Qprior);

        jump_prev = nan(nR,1);
        jump_prev(2:end) = max(Qprior(2:end), Qprior(1:end-1)) ./ ...
                           max(min(Qprior(2:end), Qprior(1:end-1)), eps);

        log_jump_prev = nan(nR,1);
        log_jump_prev(2:end) = abs(diff(log10(Qprior)));

        path_Qratio = max(Qprior,[],'omitnan') / min(Qprior(Qprior > 0),[],'omitnan');

        % ---------- Qest ----------
        [q_corr, q_NSE, q_rRMSE, q_rB] = get_metrics(Q_results, ib, ip, 'vali_estmed', nR);

        % ---------- interpolation products ----------
        [sic_corr, sic_NSE, sic_rRMSE, sic_rB] = get_metrics(Q_results, ib, ip, 'vali_SIC4DVar_interp', nR);
        [mom_corr, mom_NSE, mom_rRMSE, mom_rB] = get_metrics(Q_results, ib, ip, 'vali_MOMMA_interp', nR);
        [met_corr, met_NSE, met_rRMSE, met_rB] = get_metrics(Q_results, ib, ip, 'vali_MetroMan_interp', nR);

        interp_NSE_mat = [sic_NSE, mom_NSE, met_NSE];
        interp_corr_mat = [sic_corr, mom_corr, met_corr];
        interp_rRMSE_mat = [sic_rRMSE, mom_rRMSE, met_rRMSE];
        interp_rB_mat = [sic_rB, mom_rB, met_rB];

        best_interp_NSE = max(interp_NSE_mat, [], 2, 'omitnan');
        best_interp_corr = max(interp_corr_mat, [], 2, 'omitnan');
        best_interp_rRMSE = min(interp_rRMSE_mat, [], 2, 'omitnan');
        best_interp_rB = min(interp_rB_mat, [], 2, 'omitnan');

        q_minus_best_NSE = q_NSE - best_interp_NSE;
        q_minus_best_corr = q_corr - best_interp_corr;
        q_minus_best_rRMSE = q_rRMSE - best_interp_rRMSE;
        q_minus_best_rB = q_rB - best_interp_rB;

        T = table( ...
            repmat(ib,nR,1), ...
            repmat(ip,nR,1), ...
            (1:nR)', ...
            Qprior, ...
            repmat(path_Qratio,nR,1), ...
            jump_prev, ...
            log_jump_prev, ...
            q_corr, q_NSE, q_rRMSE, q_rB, ...
            sic_corr, sic_NSE, sic_rRMSE, sic_rB, ...
            mom_corr, mom_NSE, mom_rRMSE, mom_rB, ...
            met_corr, met_NSE, met_rRMSE, met_rB, ...
            best_interp_corr, best_interp_NSE, best_interp_rRMSE, best_interp_rB, ...
            q_minus_best_corr, q_minus_best_NSE, q_minus_best_rRMSE, q_minus_best_rB, ...
            'VariableNames', { ...
            'ib','ip','reach','Qprior','path_Qratio','jump_prev','log_jump_prev', ...
            'Qest_corr','Qest_NSE','Qest_rRMSE','Qest_rB', ...
            'SIC_interp_corr','SIC_interp_NSE','SIC_interp_rRMSE','SIC_interp_rB', ...
            'MOMMA_interp_corr','MOMMA_interp_NSE','MOMMA_interp_rRMSE','MOMMA_interp_rB', ...
            'Metro_interp_corr','Metro_interp_NSE','Metro_interp_rRMSE','Metro_interp_rB', ...
            'best_interp_corr','best_interp_NSE','best_interp_rRMSE','best_interp_rB', ...
            'Qest_minus_best_corr','Qest_minus_best_NSE','Qest_minus_best_rRMSE','Qest_minus_best_rB'});

        diag_rows = [diag_rows; T];
    end
end

save('path_Qprior_vs_interp_diag.mat','diag_rows','-v7.3');


function [corr_v, NSE_v, rRMSE_v, rB_v] = get_metrics(Q_results, ib, ip, field_name, nR)

corr_v = nan(nR,1);
NSE_v = nan(nR,1);
rRMSE_v = nan(nR,1);
rB_v = nan(nR,1);

if numel(Q_results) < ib || ~isfield(Q_results(ib), field_name)
    return
end

if numel(Q_results(ib).(field_name)) < ip || isempty(Q_results(ib).(field_name){ip})
    return
end

vali = Q_results(ib).(field_name){ip};

if isempty(vali)
    return
end

if isfield(vali,'corr')
    corr_v = unwrap_metric(vali.corr, nR);
end
if isfield(vali,'NSE')
    NSE_v = unwrap_metric(vali.NSE, nR);
end
if isfield(vali,'rRMSE')
    rRMSE_v = unwrap_metric(vali.rRMSE, nR);
end
if isfield(vali,'rB')
    rB_v = unwrap_metric(vali.rB, nR);
end

end


function x = unwrap_metric(v, nR)

x = nan(nR,1);

if isempty(v)
    return
end

if iscell(v)
    v = v{1};
end

v = v(:);
n = min(nR, numel(v));
x(1:n) = v(1:n);

end

%% median flow regime
all_group_vali = init_group_vali_collect();

for ib = 1:numel(data_KF_out)

    ib
    sg_basin = data_KF_out(ib);

    for ip = 1:numel(sg_basin.paths)

        sg_path = get_path_struct(sg_basin, ip);
        nR = length(sg_path.rch_len{1});

        Qest_med = Q_results(ib).Qest_med{1, ip};

        group_vali_path = validation_flow_groups( ...
            Qest_med, sg_path, nR, use_svs);

        all_group_vali = append_group_vali_collect( ...
            all_group_vali, group_vali_path);

    end
end

group_median = calc_group_vali_median(all_group_vali);

disp(group_median)
%% 
max_nse = -inf;
best_ib = NaN;
best_ip = NaN;
best_r  = NaN;

for ib = 350:398%numel(Q_results)%257%numel(Q_results)

    if isempty(Q_results(ib).vali_estmed)
        continue
    end

    for ip = 1:numel(Q_results(ib).vali_estmed)

        vali = Q_results(ib).vali_estmed{ip};

        if isempty(vali) || ~isfield(vali, 'NSE') || isempty(vali.NSE)
            continue
        end

        nse = vali.NSE;

        [local_max, r] = max(nse);

        if local_max > max_nse
            max_nse = local_max;
            best_ib = ib;
            best_ip = ip;
            best_r  = r;
        end

    end
end

fprintf('Max NSE = %.3f (basin %d, path %d, reach %d)\n', ...
    max_nse, best_ib, best_ip, best_r);

%% gauge max time
all_vals = [];

for ib = 1:numel(data_KF_out)

    if isempty(data_KF_out(ib).Gauge_Q)
        continue
    end

    for ip = 1:numel(data_KF_out(ib).Gauge_Q)

        G = data_KF_out(ib).Gauge_Q{ip};


for r = 1:numel(G)

    ts = G{r};

    if isempty(ts)
        continue
    end

    q = ts(:,2);          % discharge
    tg= ts(:,1);          % time
    tg = max(tg(~isnan(q)));     % remove NaN

    all_vals = [all_vals; tg];

end

    end
end

% 去重
[unique_vals,~,ic] = unique(all_vals);
counts = accumarray(idx,1);
reference_date = datetime(2000, 1, 1, 0, 0, 0);
dates = reference_date + seconds(unique_vals);
fprintf('Total non-NaN values: %d\n', numel(all_vals));
fprintf('Unique values: %d\n', (unique_vals));
%%
function sg_path = get_path_struct(basin, ip)
% GET_PATH_STRUCT  从 data_KF_out(ib) 中提取第 ip 条 path 的子结构
% 输出 sg_path 中所有按 path 的字段都变成 1×1 cell 包裹
%
% 例如：
%   basin.rch_len = {2×1 cell}
%   sg_path.rch_len = { basin.rch_len{ip} }

if ~isfield(basin, 'paths') || isempty(basin.paths)
    error('get_path_struct:NoPaths', ...
        '输入的 basin 结构里没有 paths 字段或为空。');
end

nPath = numel(basin.paths);
if ip < 1 || ip > nPath
    error('get_path_struct:IndexOutOfRange', ...
        'ip=%d 超出可用 path 数量 (1..%d)。', ip, nPath);
end

sg_path = struct();
fns = fieldnames(basin);

for k = 1:numel(fns)
    fld = fns{k};
    val = basin.(fld);

    % -------- Case 1: 按 path 存的字段（cell，长度 = nPath）--------
    if iscell(val) && numel(val) == nPath
        % 输出为 1×1 cell
        sg_path.(fld) = { val{ip} };

        % -------- Case 2: 非按 path 存储的字段（直接复制）--------
    else
        sg_path.(fld) = val;
    end
end
end


% basins(4).RiverSP_ReachData{1, 1}
% for i = 1:length(basins(4).RiverSP_ReachData{1, 1})
%     tmp = median(basins(4).RiverSP_ReachData{1, 1}{i, 1}.wse);
%   if mean(tmp)~=-9.999999999990000e+11
% wse(i) = tmp;
%   else
%       wse(i) = nan;
%   end
% end
% figure,plot(wse,'o')

% %%
% wse = nan(366,length(idx));
% for i=1:length(idx)
%     day = datenum(extractBetween(string(data(i).time_str), 1, 10))-datenum(start_date)+1;
%     node_q = data(i).node_q;
%     node_filter = find( node_q <1);
%     wse(day(node_filter),i) = data(i).wse(node_filter);
%     node_len(i) = data(i).p_length(1);
% end
%  % --- node cumulative position (center of each node) ---
%     dist = cumsum(node_len(:)) - node_len(:)/2;   % 51×1
%
%     [T, N] = size(wse);                           % 366 × 51
%     slope = NaN(T,1);
%
%     for t = 1:T
%         w = wse(t,:);
%
%         idx1 = ~isnan(w);          % 有效 node（有些 node 水位会 NaN）
%         if sum(idx1) > 1           % 至少两个点才能拟合
%             p = polyfit(dist(idx1), w(idx1), 1);
%             slope(t) = p(1);      % slope = 回归系数
%         end
%     end
%
%     % --- 最终平均 slope ---
%     S = mean(slope,'omitnan')   % 忽略 NaN 天


%%
reference_date = datetime(2000,1,1,0,0,0,'TimeZone','UTC');

all = SoS_ResultsData{3, 2}.Q_MOMMA(:,1);
for i = 1: length(all)
    dates(:,i)  = reference_date + seconds(all(i));
end

%% Compare reach IDs in paths between basins_out and basins_out_old
% Compare reach IDs in paths between basins_out and basins_out_old

all_same = true;

for i = 1:numel(basins_out)

    basin_id_new = basins_out(i).basin_id;
    basin_id_old = basins_out_old(i).basin_id;

    if ~isequaln(basin_id_new, basin_id_old)
        all_same = false;
        fprintf('Basin index %d has different basin_id: new = %s, old = %s\n', ...
            i, string(basin_id_new), string(basin_id_old));
        continue
    end

    n_path_new = numel(basins_out(i).paths);
    n_path_old = numel(basins_out_old(i).paths);

    if n_path_new ~= n_path_old
        all_same = false;
        fprintf('Basin %s has different number of paths: new = %d, old = %d\n', ...
            string(basin_id_new), n_path_new, n_path_old);
    end

    n_path = min(n_path_new, n_path_old);

    for p = 1:n_path

        reach_new = basins_out(i).paths{p};
        reach_old = basins_out_old(i).paths{p};

        if ~isequaln(reach_new, reach_old)
            all_same = false;

            fprintf('\nDifferent path found:\n');
            fprintf('Basin index: %d\n', i);
            fprintf('Basin ID: %s\n', string(basin_id_new));
            fprintf('Path index: %d\n', p);

            fprintf('New path reach IDs size: %s\n', mat2str(size(reach_new)));
            fprintf('Old path reach IDs size: %s\n', mat2str(size(reach_old)));

            fprintf('New reach IDs:\n');
            disp(reach_new)

            fprintf('Old reach IDs:\n');
            disp(reach_old)
        end
    end
end

if all_same
    disp('All path reach IDs are the same.');
else
    disp('Some path reach IDs are different.');
end
%%
% ib = 1; 
% p  = 1;
% r=15;
% t0 = datetime(2024,1,1);
% 
% %% ---------- Gauge Q（该 reach 的 gauge 时序） ----------
% G  = data_KF_out(ib).Gauge_Q{p,1}{r,1};
% % [datenum, Q]
% tG = datetime(G(:,1), 'ConvertFrom','datenum');
% qG = G(:,2);
% 
% % 如果你只想看 2024-01-01 以后（通常都会）
% idxG = tG >= t0;
% tG = tG(idxG);
% qG = qG(idxG);
% 
% %% ---------- WSE（该 reach 的 wse 时序：第 1 行） ----------
% Wcell = data_KF_out(ib).slope_RiverSP{p,1};   % cell: (Nreach x Nday)
% 
% col_wse   = 2;     % <<< 你截图里有值的列：2 或 6（如果不同产品/不同轨道就改）
% 
% % 取出这一行的时间序列（沿列方向）
% c = Wcell(r, :);    % 1 x Nday cell，每列一天
% 
% % 如果每个 cell 里是一个 1xNcol 的向量，就取第 col_wse 个；
% % 如果每个 cell 里本身就是一个标量，那下面也兼容。
% wse = nan(1, numel(c));
% has = false(1, numel(c));
% 
% for j = 1:numel(c)
%     if ~isempty(c{j})
%         v = c{j};
%         if isnumeric(v) && isscalar(v)
%             wse(j) = v;
%             has(j) = true;
%         elseif isnumeric(v) && numel(v) >= col_wse
%             wse(j) = v(col_wse);
%             has(j) = true;
%         end
%     end
% end
% 
% % WSE 的日期（每列一天，从 2024-01-01 开始）
% Nday = size(Wcell,2);
% tW_all = t0 + days(0:Nday-1);
% 
% tW = tW_all(has);
% wse_plot = wse(has);
% 
% %% ---------- 画图：Gauge 连续，WSE 离散 ----------
% figure; grid on; hold on;
% 
% yyaxis left
% plot(tG, qG, '-');
% ylabel('Gauge Q')
% 
% yyaxis right
% scatter(tW, wse_plot, 22, 'filled');   % 只画有观测的天
% ylabel('WSE')
% 
% xlim([t0 max([tG; tW_all(:)])]);
% title(sprintf('Gauge Q vs WSE (ib=%d, path=%d, reachRow=%d)', ib, p, reach_row));
% 
% % ---- 对齐同一天 ----
% [t_common, iG, iW] = intersect(Gday, tW);
% 
% qG_c  = qG_day(iG);
% wse_c = wse_plot(iW)';
% 
% % ---- 显式剔除 NaN（两边一起）----
% valid = ~isnan(qG_c) & ~isnan(wse_c);
% 
% qG_c  = qG_c(valid);
% wse_c = wse_c(valid);
% t_common = t_common(valid);
% 
% % ---- correlation ----
% R_pearson  = corr(qG_c, wse_c);
% R_spearman = corr(qG_c, wse_c, 'Type','Spearman');
% 
% N = numel(qG_c);
% 
% % ---- 写在图上 ----
% yyaxis left
% txt = sprintf('Pearson r = %.2f\nSpearman r = %.2f\nN = %d days', ...
%               R_pearson, R_spearman, N);
% 
% xpos = t0 + days(10);
% ypos = max(qG) * 0.95;
% 
% text(xpos, ypos, txt, ...
%     'VerticalAlignment','top', ...
%     'BackgroundColor','w', ...
%     'EdgeColor','k');
