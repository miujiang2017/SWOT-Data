function [H, z, R] = build_H_obs_SWOT_Q(sg_path, state_ep, ep, k_Qobs, obs_unc_mode, obs_unc_scale)
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
%   'prior_range'   : R标准差 = (Qmax_prior - Qmin_prior) / 6 * obs_unc_scale
% obs_unc_scale:

if nargin < 5 || isempty(obs_unc_mode)
    obs_unc_mode = 'qprior_group';
end
if nargin < 6 || isempty(obs_unc_scale)
    obs_unc_scale = 1;
end

nR = length(sg_path.rch_len{1});  % Number of reaches
mean_percent_unc = [ 0.2783, 0.3350, 0.4618, 0.3005, 0.2564]; % [SIC4DVar, MOMMA, geoBAM, MetroMan, SADS]
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
% uncertainty 选项都使用 z = Qobs - Qprior
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
        Q_cell_unc = cellfun(@(x,y) abs(y) * mean_percent_unc(k_Qobs), ...
            Q_win, Qprior_cell, 'UniformOutput', false);
        non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
        Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

    case "qprior_group"
        % 当前方案：R标准差 = Qprior(reach) * percent(product, Qprior group)
        % percent 和 Qprior 分组门槛来自 obs_percent_Qprior 的输出 OBS_PERCENT_QPRIOR
        percent_by_reach = local_percent_by_Qprior_group(Qprior, k_Qobs);
        percent_win = repmat(percent_by_reach, 1, size(Q_win,2));
        Qprior_win = repmat(Qprior, 1, size(Q_win,2));
        Qprior_cell = num2cell(Qprior_win);
        percent_cell = num2cell(percent_win);
        Q_cell_unc = cellfun(@(x,y,p) abs(y) * p * obs_unc_scale, ...
            Q_win, Qprior_cell, percent_cell, 'UniformOutput', false);
        non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
        Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

    case "prior_range"
        % prior range方案：R标准差 = (Qmax_prior - Qmin_prior) / 6
        sigma_reach = local_prior_range_sigma(sg_path, Qprior, mean_percent_unc(k_Qobs));
        sigma_win = repmat(sigma_reach, 1, size(Q_win,2));
        sigma_cell = num2cell(sigma_win);
        Q_cell_unc = cellfun(@(x,s) abs(s) * obs_unc_scale, ...
            Q_win, sigma_cell, 'UniformOutput', false);
        non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_win));
        Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

    otherwise
        error('Unknown obs_unc_mode: %s. Use mean_percent, qprior_group, or prior_range.', string(obs_unc_mode));
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

R = diag(Rvec);

% ---- 4) 构造 H ----
H = zeros(numel(idx), state_ep*nR);
for j = 1:numel(idx)
    H(j, idx(j)) = 1;
end
end


function percent_by_reach = local_percent_by_Qprior_group(Qprior, k_Qobs)

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

p_low = local_get_group_percent(S, 'low', fld);
p_mid = local_get_group_percent(S, 'mid', fld);
p_high = local_get_group_percent(S, 'high', fld);

percent_by_reach = nan(size(Qprior));
percent_by_reach(Qprior <= edges(1)) = p_low;
percent_by_reach(Qprior > edges(1) & Qprior <= edges(2)) = p_mid;
percent_by_reach(Qprior > edges(2)) = p_high;

bad = ~isfinite(percent_by_reach) | percent_by_reach <= 0;
if any(bad)
    error('Invalid percent assigned from OBS_PERCENT_QPRIOR.%s.', fld);
end

end


function p = local_get_group_percent(S, group_name, fld)

p = NaN;

if isfield(S.group, group_name)
    G = S.group.(group_name);
    if isfield(G, 'recommended_percent') && isfinite(G.recommended_percent) && G.recommended_percent > 0
        p = G.recommended_percent;
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


function sigma_reach = local_prior_range_sigma(sg_path, Qprior, fallback_percent)

fallback_sigma = abs(Qprior(:)) * fallback_percent;
bad_fallback = ~isfinite(fallback_sigma) | fallback_sigma <= 0;
fallback_sigma(bad_fallback) = eps;
sigma_reach = fallback_sigma;

if ~isfield(sg_path, 'minQ_prior') || ~isfield(sg_path, 'maxQ_prior') || ...
        isempty(sg_path.minQ_prior) || isempty(sg_path.maxQ_prior) || ...
        ~iscell(sg_path.minQ_prior) || ~iscell(sg_path.maxQ_prior) || ...
        isempty(sg_path.minQ_prior{1}) || isempty(sg_path.maxQ_prior{1})
    return
end

Qmin = sg_path.minQ_prior{1};
Qmax = sg_path.maxQ_prior{1};
if isempty(Qmin) || isempty(Qmax)
    return
end

if isvector(Qmin)
    Qmin = Qmin(:);
else
    Qmin = Qmin(:, 1);
end
if isvector(Qmax)
    Qmax = Qmax(:);
else
    Qmax = Qmax(:, 1);
end
n_use = min([numel(sigma_reach), numel(Qmin), numel(Qmax)]);
if n_use < 1
    return
end

sigma_tmp = (Qmax(1:n_use) - Qmin(1:n_use)) / 8;
ok = isfinite(sigma_tmp) & sigma_tmp > 0;
sigma_reach(1:n_use) = fallback_sigma(1:n_use);
sigma_reach(ok) = sigma_tmp(ok);

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
