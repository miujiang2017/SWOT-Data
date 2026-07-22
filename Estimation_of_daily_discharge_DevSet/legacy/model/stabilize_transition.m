function [Phi, Q_st] = stabilize_transition(sg_path, R_auto_mat, R_crs_mat, state_ep, opts)
% 与你原函数同功能；只是把几个超参数自适应化，并加了数值稳健细节
% opts 可空；可用字段：alpha_rel, lambda, rho_max, gamma0, sig_floor, qmin_rel

    if nargin < 6, opts = struct(); end
lambda    = getf(opts,'lambda',   0.15);   % 收缩弱一点，保留方向性
rho_max   = getf(opts,'rho_max',  0.995);  % 放宽动态上限，允许更接近真实起伏
gamma0    = getf(opts,'gamma0',   0.95);   % 少掺水，别把动态拉得太钝
sig_floor = getf(opts,'sig_floor',1e-6);   % 保持
alpha_rel = getf(opts,'alpha_rel',3e-4);   % 降低岭强度，避免把Φ压小
qmin_rel  = getf(opts,'qmin_rel', 1e-9);   % 很小的对角抬升，保稳定不锁死   % 新：Q_st 对角抬升比例

    % --- Step 1: 不确定性 std（仅加下限） %%%
    minQ = sg_path.minQ_prior{1, 1}(:,1);
    maxQ = sg_path.maxQ_prior{1, 1}(:,1);
    Q_unc1 = (maxQ-minQ)/6;                          % 1×T
    %Q_unc1 = calc_sigma0(sg_path)
    Q_unc1 = max(Q_unc1, sig_floor);                % %%%
    sig1 = repmat(Q_unc1, state_ep, 1);
    sig2 = repmat(Q_unc1, state_ep, 1);

    % --- Step 2: 清理相关矩阵（先对称化再 PSD） %%%
    % Make correlation matrices PSD
    Ra = 0.5*(R_auto_mat + R_auto_mat');
    Rc = R_crs_mat;% %%%
    Rc = 0.5*(R_crs_mat  + R_crs_mat' );            % %%%
    Ra = make_psd(Ra);

%     Rc_raw = R_crs_mat;
% Rc_sym = 0.5*(Rc_raw + Rc_raw');
%     eta    = getf(opts,'eta_sym',1);   % 可调
%     Rc     = (1-eta)*Rc_raw + eta*Rc_sym;
     Rc = make_psd(Rc);
    % Pull correlation matrices a bit toward identity:
    Ra = (1-lambda)*Ra + lambda*eye(size(Ra));
    Rc = (1-lambda)*Rc + lambda*eye(size(Rc));

    % --- Step 3: 协方差（与你一致） ---
    S1 = diag(sig1);
    S2 = diag(sig2);
    Sigma       = S2 * Ra * S2;
    Sigma_delta = S1 * Rc * S2;
    Sigma = 0.5*(Sigma + Sigma.');                  % %%% 轻对称化

% --- Step 4: Phi (adaptive ridge + adaptive gamma + light spectral-radius constraint) ---
n     = size(Sigma, 1);                          % state dimension
scale = trace(Sigma) / max(n, 1);                % typical variance scale (mean diagonal of Sigma)
alpha = alpha_rel * max(scale, sig_floor);       % data-scaled ridge (replaces fixed 1e-3)
Phi   = Sigma_delta / (Sigma + alpha*eye(n));    % ridge solution: right-division equals inverse times


    rho = max(abs(eig(Phi)));                       % 你的谱半径检查
    if rho > rho_max
        Phi = Phi * (rho_max / rho);                % 保留你的“整体缩放”
    end

    % γ 设为自适应：别把已经很保守的 Phi 再压得过软 %%%
    gamma = min(gamma0, rho_max / max(rho, eps));   % %%%
    Phi = (1-gamma)*eye(n) + gamma*Phi;

    % --- Step 5: Q_st（过程噪声协方差） ---
    Q_st = Sigma -  Sigma_delta * pinv(Sigma) *Sigma_delta';
    %Q_st = Sigma - Phi*Sigma*Phi.';
   Q_st = 0.5*(Q_st + Q_st.');                     % %%% 对称化
    qmin = qmin_rel * max(scale, sig_floor);        % %%%
    Q_st = make_psd(Q_st, qmin);                    % 更稳的 PSD 投影
end

function v = getf(S, field, default)
    if isfield(S,field) && ~isempty(S.(field)), v = S.(field); else, v = default; end
end

% function [Phi, Q_st] = stabilize_transition(Q, R_auto_mat, R_crs_mat, state_ep, opts)
% % 稳定化状态转移矩阵（支持等幅选项，鲁棒处理NaN/尺寸/病态）
% 
%     if nargin < 5, opts = struct(); end
%     % ---- 默认参数（可在 opts 里覆盖）----
%     lambda    = getf(opts,'lambda',   0.0);
%     rho_max   = getf(opts,'rho_max',  0.9999);
%     gamma0    = getf(opts,'gamma0',   1.0);
%     sig_floor = getf(opts,'sig_floor',1e-6);
%     alpha_rel = getf(opts,'alpha_rel',1e-6);
%     qmin_rel  = getf(opts,'qmin_rel', 1e-12);
%     equal_amp = getf(opts,'equal_amp', true);
%     r_target  = getf(opts,'r_target', 0.9999);
% 
%     % ---- Step 1: 标度（忽略NaN）----
%     try
%         Q_unc1 = std(Q, 0, 1, 'omitnan');   % R2020a+
%     catch
%         Q_unc1 = nanstd(Q, 0, 1);           % 旧版兼容
%     end
%     Q_unc1(~isfinite(Q_unc1)) = 0;          % 把NaN/Inf当0处理
%     Q_unc1 = max(Q_unc1, sig_floor);        % 下限
%     sig1 = repmat(Q_unc1', state_ep, 1);
%     sig2 = sig1;
% 
%     % ---- Step 2: 相关矩阵清理 ----
%     Ra = 0.5*(R_auto_mat + R_auto_mat');
%     Rc = 0.5*(R_crs_mat  + R_crs_mat' );
%     if any(~isfinite(Ra(:))) || any(~isfinite(Rc(:)))
%         error('R_auto_mat 或 R_crs_mat 含非有限元素。');
%     end
%     Ra = make_psd(Ra);
%     Rc = make_psd(Rc);
%     Ra = (1-lambda)*Ra + lambda*eye(size(Ra));
%     Rc = (1-lambda)*Rc + lambda*eye(size(Rc));
% 
%     % ---- 尺寸检查 ----
%     n = numel(sig1);
%     if size(Ra,1) ~= n || size(Rc,1) ~= n || size(Ra,2) ~= n || size(Rc,2) ~= n
%         error('尺寸不匹配：n=%d，但 size(Ra)=[%d %d], size(Rc)=[%d %d]', ...
%               n, size(Ra,1), size(Ra,2), size(Rc,1), size(Rc,2));
%     end
% 
%     % ---- Step 3: 协方差 ----
%     S1 = diag(sig1);
%     S2 = diag(sig2);
%     Sigma       = S2 * Ra * S2;
%     Sigma_delta = S1 * Rc * S2;
%     Sigma       = 0.5*(Sigma + Sigma.');
%     if any(~isfinite(Sigma(:))) || any(~isfinite(Sigma_delta(:)))
%         % 兜底：用极小噪声的对角阵
%         warning('Sigma 含非有限元素，回退为小对角阵。');
%         Sigma = max(mean(sig1)^2, sig_floor)*eye(n);
%         Sigma_delta = zeros(n);
%     end
% 
%     % ---- Step 4: Φ（岭 + 限谱 + I混合）----
%     scale = trace(Sigma)/max(n,1);
%     alpha = alpha_rel * max(scale, sig_floor);
%     A = Sigma + alpha*eye(n);
%     % 右除更稳（内部会选合适求解器）
%     Phi = Sigma_delta / A;
% 
%     rho = max(abs(eig(Phi)));
%     if isfinite(rho) && rho > rho_max
%         Phi = Phi * (rho_max / rho);
%     end
%     gamma = min(gamma0, rho_max / max(rho, eps));
%     Phi = (1-gamma)*eye(n) + gamma*Phi;
% 
%     % ---- Step 4.5: 等幅投影（极分解），失败则跳过 ----
%     if equal_amp
%         try
%             [U,~,V] = svd(Phi);
%             Phi = r_target * (U*V.');
%         catch
%             warning('equal_amp 投影失败，跳过 SVD。');
%         end
%     end
% 
%     % ---- Step 5: 过程噪声（与最终Φ匹配）----
%     Q_st = Sigma -  Sigma_delta * inv(Sigma) *Sigma_delta';
%     Q_st = 0.5*(Q_st + Q_st.');
%     qmin = qmin_rel * max(scale, sig_floor);
%     Q_st = make_psd(Q_st, qmin);
% 
%     % ---- 最后安全检查 ----
%     if any(~isfinite(Phi(:))) || any(~isfinite(Q_st(:)))
%         error('Phi 或 Q_st 包含非有限元素，请检查输入/NaN。');
%     end
% end
% 
% function v = getf(S, field, default)
%     if isfield(S,field) && ~isempty(S.(field)), v = S.(field); else, v = default; end
% end
