function [H, z, R] = build_H_obs_SWOT_Q(sg_path, state_ep, ep, k_Qobs)
% BUILD_H_OBS_SWOT_Q
% 输入单条 path 的结构 sg_path，输出该 path 在当前窗口的 H, z, R
%
% k_Qobs:
%   1: SIC4DVar
%   2: MOMMA
%   3: geoBAM
%   4: SADS
%   5: MetroMan

nR = length(sg_path.rch_len{1});  % Number of reaches
mean_percent_unc = [0.2783, 0.3350, 0.4618, 0.3005, 0.2564];%[SIC4DVar,MOMMA, geoBAM, MetroMan, SADS] Qgauge
% mean_percent_unc = [0.4149, 0.5006, 0.4892, 0.4180 0.3703]; % [SIC4DVar, MOMMA, geoBAM, MetroMan, SADS]Qobs
% mean_percent_unc = [5.1367, 6.3608, 6.8366, 7.1602, 0.3703]; %sqrt(Qgauge)
% mean_percent_unc = [4.0213, 5.6063, 5.3987, 5.5901, 0.3703]; %sqrt(Qobs)
% mean_percent_unc = [7.0498, 8.8799, 9.2281, 10.2743, 0.3703]; %sqrt(rgauge)
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

% ---- 2) 构造 z（去均值）----
% 注意：Q_cell_mean 通常是 nR×1（或 nR×?），这里按列复制到窗口宽度
Q_mean_win  = repmat(sg_path.Q_prior{1, 1}(:,1), 1, size(Q_win,2));%repmat(sg_path.Q_prior{1, 1}(:,1), 1, size(Q_win,2));%repmat(Q_cell_mean, 1, size(Q_win,2));
Q_mean_win  = num2cell(Q_mean_win);
Q_cell_sub  = cellfun(@(x,y) x - y, Q_win, Q_mean_win, 'UniformOutput', false);

non_empty_Q = Q_cell_sub(~cellfun(@isempty, Q_cell_sub));
z = cell2mat(non_empty_Q(:));

% ---- 3) 构造 R：按比例不确定度 ----
% 观测标准差 = obs * mean_percent_unc(k_Qobs)
Q_cell_unc = cellfun(@(x) (abs(x)) * mean_percent_unc(k_Qobs), Q_win, 'UniformOutput', false);
non_empty_Qunc = Q_cell_unc(~cellfun(@isempty, Q_cell_unc));
Rvec = cell2mat(non_empty_Qunc(:)).^2;   % 方差

R = diag(Rvec);

% ---- 4) 构造 H ----
H = zeros(numel(idx), state_ep*nR);
for j = 1:numel(idx)
    H(j, idx(j)) = 1;
end
end