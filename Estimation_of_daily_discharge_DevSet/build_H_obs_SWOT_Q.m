function [H, z, R] = build_H_obs_SWOT_Q(sg_path, state_ep, ep, k_Qobs, obs_unc_mode, obs_unc_scale, obs_corr_mode)
% BUILD_H_OBS_SWOT_Q
% 输入单条 path 的结构 sg_path，输出该 path 在当前窗口的 H, z, R
%
% k_Qobs:
%   1: SIC4DVar
%   2: MOMMA
%   3: geoBAM
%   4: MetroMan
%   5: SADS
%
% obs_unc_mode:
%   'mean_percent'  : 固定percent方案，R标准差 = Qprior(reach) * 固定mean percent(product)
%   'qprior_group'  : 当前方案，R标准差 = Qprior(reach) * percent(product, Qprior group)
%   'qprior_group_p68/p75': use the group empirical 68th/75th percentile percent
%   'qprior_group_high_p68/p75/p90': use recommended percent except high-Qprior group percentile
%   'qprior_group_floor_mean': qprior_group, with percent no smaller than product mean percent
%   'qprior_power_*': 幂律方案，R标准差 = percent(group) * Qref^(1-beta) * Qprior^beta
% obs_unc_scale:
% obs_corr_mode:
%   'none'          : diagonal R
%   'same_reach_tau': same-reach observation errors use exp(-dt/tau) covariance

if nargin < 5 || isempty(obs_unc_mode)
    obs_unc_mode = 'qprior_group';
end
if nargin < 6 || isempty(obs_unc_scale)
    obs_unc_scale = 1;
end
if nargin < 7 || isempty(obs_corr_mode)
    obs_corr_mode = 'none';
end

nR = length(sg_path.rch_len{1});  % Number of reaches
mean_percent_unc = [ 0.16237, 0.3350, 0.4618, 0.3005, 0.2564]; % [SIC4DVar, MOMMA, geoBAM, MetroMan, SADS]
H = zeros(1, state_ep*nR);

Q_cell      = [];
Q_cell_mean = [];

% ---- 0) 选择观测来源 ----
if k_Qobs == 1 && isfield(sg_path,'Q_SIC4DVar') && ~isempty(sg_path.Q_SIC4DVar)
    Q_cell      = sg_path.Q_SIC4DVar{1,1};
    Q_cell_mean = sg_path.mean_SIC4DVar{1,1};

elseif k_Qobs == 2 && isfield(sg_path,'Q_MOMMA') && ~isempty(sg_path.Q_MOMMA)
    Q_cell      = sg_path.Q_MOMMA{1,1};
    Q_cell_mean = sg_path.mean_MOMMA{1,1};

elseif k_Qobs == 3 && isfield(sg_path,'Q_geoBAM') && ~isempty(sg_path.Q_geoBAM)
    Q_cell      = sg_path.Q_geoBAM{1,1};
    Q_cell_mean = sg_path.mean_geoBAM{1,1};

elseif k_Qobs == 4 && isfield(sg_path,'Q_MetroMan') && ~isempty(sg_path.Q_MetroMan)
    Q_cell      = sg_path.Q_MetroMan{1,1};
    Q_cell_mean = sg_path.mean_MetroMan{1,1};

elseif k_Qobs == 5 && isfield(sg_path,'Q_SADS') && ~isempty(sg_path.Q_SADS)
    Q_cell      = sg_path.Q_SADS{1,1};
    Q_cell_mean = sg_path.mean_SADS{1,1};

end

% 没有该来源观测 → 返回空
if isempty(Q_cell)
    H = [];
    z = [];
    R = [];
    return;
end

% ---- 1) 当前窗口取子块 ----
cols = (ep+1):(ep+state_ep);
Q_win = Q_cell(:, cols);

% 有观测的位置
emp = cellfun(@isempty, Q_win);              % nR × state_ep
tmp = reshape(emp, state_ep*nR, 1);
idx = find(tmp == 0);

% ---- 2) 构造 z ----
% 两个 uncertainty 选项都使用 z = Qobs - Qprior
Qprior = sg_path.Q_prior{1, 1}(:,1);
Q_mean_win = repmat(Qprior, 1, size(Q_win,2));
Q_mean_win = num2cell(Q_mean_win);
Q_cell_sub = cellfun(@(x,y) x - y, Q_win, Q_mean_win, 'UniformOutput', false);
non_empty_Q = Q_cell_sub(~cellfun(@isempty, Q_cell_sub));
z = cell2mat(non_empty_Q(:));

switch lower(string(obs_unc_mode))
    case "mean_percent"
        % 固定percent方案：R标准差 = Qprior(reach) * 固定mean percent(product)
        Qprior_win = repmat(Qprior, 1, size(Q_win,2));
        Qprior_cell = num2cell(Qprior_win);
        Q_cell_unc = cellfun(@(x,y) abs(y) * mean_percent_unc(k_Qobs) * obs_unc_scale, ...
            Q_win, Qprior_cell, 'UniformOutput', false);
        non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
        Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

    otherwise
        mode = lower(string(obs_unc_mode));
        floor_mean_percent = endsWith(mode, "_floor_mean");
        base_mode = erase(mode, "_floor_mean");
        percent_stat = "recommended_percent";
        high_percent_stat = "";
        if any(base_mode == ["qprior_group_high_p68", "qprior_group_high_p75", "qprior_group_high_p90"])
            high_percent_stat = extractAfter(base_mode, "qprior_group_high_");
            base_mode = "qprior_group";
        end
        if any(base_mode == ["qprior_group_p68", "qprior_group_p75", "qprior_group_p90"])
            percent_stat = extractAfter(base_mode, "qprior_group_");
            base_mode = "qprior_group";
        end
        if base_mode == "qprior_group"
            beta = 1;
        elseif startsWith(base_mode, "qprior_power_")
            beta = local_parse_beta(base_mode, "qprior_power_");
        elseif startsWith(base_mode, "mean_power_")
            beta = local_parse_beta(base_mode, "mean_power_");
        else
            error('Unknown obs_unc_mode: %s. Use mean_percent, qprior_group, qprior_power_0p75, etc.', string(obs_unc_mode));
        end

        % 当前方案：R标准差 = Qprior(reach) * percent(product, Qprior group)
        % percent 和 Qprior 分组门槛来自 obs_percent_Qprior 的输出 OBS_PERCENT_QPRIOR
        if startsWith(base_mode, "mean_power_")
            percent_by_reach = mean_percent_unc(k_Qobs) .* ones(size(Qprior));
        else
            percent_by_reach = local_percent_by_Qprior_group(Qprior, k_Qobs, percent_stat);
            if strlength(high_percent_stat) > 0
                percent_by_reach = local_apply_high_group_percent(Qprior, k_Qobs, ...
                    percent_by_reach, high_percent_stat);
            end
            if floor_mean_percent
                percent_by_reach = max(percent_by_reach, mean_percent_unc(k_Qobs));
            end
        end
        Qref = median(abs(Qprior(isfinite(Qprior) & Qprior ~= 0)), 'omitnan');
        if ~isfinite(Qref) || Qref <= 0
            Qref = median(abs(Qprior), 'omitnan');
        end
        if ~isfinite(Qref) || Qref <= 0
            Qref = 1;
        end
        Qscale_by_reach = (Qref .^ (1 - beta)) .* (max(abs(Qprior), eps) .^ beta);
        percent_win = repmat(percent_by_reach, 1, size(Q_win,2));
        Qscale_win = repmat(Qscale_by_reach, 1, size(Q_win,2));
        Qscale_cell = num2cell(Qscale_win);
        percent_cell = num2cell(percent_win);
        Q_cell_unc = cellfun(@(x,y,p) abs(y) * p * obs_unc_scale, ...
            Q_win, Qscale_cell, percent_cell, 'UniformOutput', false);
        non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
        Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差
end

% 方案3（旧实验）：z = Qobs - Qprior；R标准差 = mean(Qobs, reach) * 手动percent(product)
% Q_mean_win = repmat(sg_path.Q_prior{1, 1}(:,1), 1, size(Q_win,2));
% Q_mean_win = num2cell(Q_mean_win);
% Q_cell_sub = cellfun(@(x,y) x - y, Q_win, Q_mean_win, 'UniformOutput', false);
% non_empty_Q = Q_cell_sub(~cellfun(@isempty, Q_cell_sub));
% z = cell2mat(non_empty_Q(:));
% Qobs_mean = local_reach_mean_from_Qcell(Q_cell, nR);
% Qprior = sg_path.Q_prior{1, 1}(:,1);
% bad_mean = ~isfinite(Qobs_mean) | Qobs_mean <= 0;
% Qobs_mean(bad_mean) = Qprior(bad_mean);
% Qobs_mean_win = repmat(Qobs_mean, 1, size(Q_win,2));
% Qobs_mean_cell = num2cell(Qobs_mean_win);
% Q_cell_unc = cellfun(@(x,y) abs(y) * mean_percent_unc(k_Qobs), ...
%     Q_win, Qobs_mean_cell, 'UniformOutput', false);
% non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
% Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

% 方案4（旧实验）：z = Qobs - mean(Qobs, reach)；R标准差 = Qprior(reach) * 手动percent(product)
% Qprior = sg_path.Q_prior{1, 1}(:,1);
% Qobs_mean = local_reach_mean_from_Qcell(Q_cell, nR);
% bad_mean = ~isfinite(Qobs_mean);
% Qobs_mean(bad_mean) = Qprior(bad_mean);
% Q_mean_win = repmat(Qobs_mean, 1, size(Q_win,2));
% Q_mean_win = num2cell(Q_mean_win);
% Q_cell_sub = cellfun(@(x,y) x - y, Q_win, Q_mean_win, 'UniformOutput', false);
% non_empty_Q = Q_cell_sub(~cellfun(@isempty, Q_cell_sub));
% z = cell2mat(non_empty_Q(:));
% Qprior_win = repmat(Qprior, 1, size(Q_win,2));
% Qprior_cell = num2cell(Qprior_win);
% Q_cell_unc = cellfun(@(x,y) abs(y) * manual_percent(k_Qobs), ...
%     Q_win, Qprior_cell, 'UniformOutput', false);
% non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
% Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

R = local_build_observation_covariance(Rvec, idx, nR, sg_path, obs_corr_mode);

% ---- 4) 构造 H ----
H = zeros(numel(idx), state_ep*nR);
for j = 1:numel(idx)
    H(j, idx(j)) = 1;
end
end


function R = local_build_observation_covariance(Rvec, idx, nR, sg_path, obs_corr_mode)

mode = lower(string(obs_corr_mode));
if mode == "none"
    R = diag(Rvec);
    return
end

reach_idx = mod(idx - 1, nR) + 1;
day_idx = floor((idx - 1) ./ nR) + 1;

switch mode
    case "same_reach_tau"
        tau_days = local_tau_days(sg_path, nR);
        s = sqrt(max(Rvec(:), eps));
        C = eye(numel(Rvec));
        for i = 1:numel(Rvec)
            same_reach = reach_idx == reach_idx(i);
            dt = abs(day_idx(same_reach) - day_idx(i));
            C(i, same_reach) = exp(-dt ./ max(tau_days(reach_idx(i)), eps));
        end
        R = (s * s') .* C;
        R = (R + R') ./ 2;
        ridge = max(1e-8 * mean(Rvec, 'omitnan'), eps);
        R = R + ridge * eye(size(R, 1));

    otherwise
        error('Unknown obs_corr_mode: %s. Use none or same_reach_tau.', string(obs_corr_mode));
end

end


function tau_days = local_tau_days(sg_path, nR)

tau_days = nan(nR, 1);
if isfield(sg_path, 'tau') && ~isempty(sg_path.tau) && ~isempty(sg_path.tau{1})
    tau_days = abs(sg_path.tau{1}(:)) ./ 86400;
end

if numel(tau_days) < nR
    tau_days(end + 1:nR, 1) = NaN;
else
    tau_days = tau_days(1:nR);
end

good = isfinite(tau_days) & tau_days >= 2;
fallback = median(tau_days(good), 'omitnan');
if ~isfinite(fallback) || fallback < 2
    fallback = 7;
end
tau_days(~good) = fallback;

end


function beta = local_parse_beta(mode, prefix)

token = erase(string(mode), prefix);
token = replace(token, "p", ".");
beta = str2double(token);
if ~isfinite(beta) || beta <= 0 || beta > 1.5
    error('Invalid uncertainty beta in obs_unc_mode: %s.', string(mode));
end

end


function percent_by_reach = local_percent_by_Qprior_group(Qprior, k_Qobs, percent_stat)

if nargin < 3 || isempty(percent_stat)
    percent_stat = "recommended_percent";
end

global OBS_PERCENT_QPRIOR

if isempty(OBS_PERCENT_QPRIOR) || ~isstruct(OBS_PERCENT_QPRIOR)
    error(['OBS_PERCENT_QPRIOR is empty. Run obs_percent_Qprior first, then assign ', ...
        'global OBS_PERCENT_QPRIOR before Kalman filtering.']);
end

product_fields = {'Q_SIC4DVar','Q_MOMMA','Q_geoBAM','Q_MetroMan','Q_SADS'};
if k_Qobs < 1 || k_Qobs > numel(product_fields)
    error('Invalid k_Qobs: %d.', k_Qobs);
end

fld = product_fields{k_Qobs};
if ~isfield(OBS_PERCENT_QPRIOR, fld)
    error('OBS_PERCENT_QPRIOR does not contain %s.', fld);
end

S = OBS_PERCENT_QPRIOR.(fld);
if ~isfield(S, 'Qprior_group_edges') || numel(S.Qprior_group_edges) < 2 || ...
        ~isfield(S, 'group')
    error('OBS_PERCENT_QPRIOR.%s does not contain Qprior group information.', fld);
end

edges = S.Qprior_group_edges;
if any(~isfinite(edges))
    error('OBS_PERCENT_QPRIOR.%s has invalid Qprior group thresholds.', fld);
end

p_low = local_get_group_percent(S, 'low', fld, percent_stat);
p_mid = local_get_group_percent(S, 'mid', fld, percent_stat);
p_high = local_get_group_percent(S, 'high', fld, percent_stat);

percent_by_reach = nan(size(Qprior));
percent_by_reach(Qprior <= edges(1)) = p_low;
percent_by_reach(Qprior > edges(1) & Qprior <= edges(2)) = p_mid;
percent_by_reach(Qprior > edges(2)) = p_high;

bad = ~isfinite(percent_by_reach) | percent_by_reach <= 0;
if any(bad)
    error('Invalid percent assigned from OBS_PERCENT_QPRIOR.%s.', fld);
end

end


function percent_by_reach = local_apply_high_group_percent(Qprior, k_Qobs, percent_by_reach, percent_stat)

global OBS_PERCENT_QPRIOR
product_fields = {'Q_SIC4DVar','Q_MOMMA','Q_geoBAM','Q_MetroMan','Q_SADS'};
fld = product_fields{k_Qobs};
S = OBS_PERCENT_QPRIOR.(fld);
edges = S.Qprior_group_edges;
p_high = local_get_group_percent(S, 'high', fld, percent_stat);
percent_by_reach(Qprior > edges(2)) = p_high;

end


function p = local_get_group_percent(S, group_name, fld, percent_stat)

if nargin < 4 || isempty(percent_stat)
    percent_stat = "recommended_percent";
end

p = NaN;

if isfield(S.group, group_name)
    G = S.group.(group_name);
    stat = char(percent_stat);
    if isfield(G, stat) && isfinite(G.(stat)) && G.(stat) > 0
        p = G.(stat);
    end
end

if (~isfinite(p) || p <= 0) && isfield(S, 'recommended_percent') && ...
        isfinite(S.recommended_percent) && S.recommended_percent > 0
    p = S.recommended_percent;
end

if ~isfinite(p) || p <= 0
    error('No valid percent is available for OBS_PERCENT_QPRIOR.%s group %s.', fld, group_name);
end

end


function q_mean = local_reach_mean_from_Qcell(Q_cell, nR)

q_mean = nan(nR, 1);

if isempty(Q_cell) || ~iscell(Q_cell)
    return
end

nR_use = min(nR, size(Q_cell, 1));
for r = 1:nR_use
    vals = Q_cell(r, :);
    vals = vals(~cellfun(@isempty, vals));
    if isempty(vals)
        continue
    end

    vals = cellfun(@(x) x(:), vals, 'UniformOutput', false);
    vals = vertcat(vals{:});
    vals = vals(isfinite(vals));

    if ~isempty(vals)
        q_mean(r) = mean(vals, 'omitnan');
    end
end

end
