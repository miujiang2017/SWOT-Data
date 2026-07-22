function r_fill = corrModel_AD_correct(c, D, tau, t_lags_at, x_lags1, r_at, dD, thr, dTau)
% r_fill = corrModel_AD_correct(c, D, tau, t_lags_at, x_lags1, r_at, dD, thr, dTau)
%
% 先对坏点迭代增大 D 修正；若仍有坏点，再对剩余坏点迭代调整 tau 修正一次。
% 全过程不报错/不 warning；仅在最终仍不满足阈值时 error 一次。

max_iter = 10000;

x_lags1   = x_lags1(:);
t_lags_at = t_lags_at(:);
r_tmp     = r_at(:);

idx_bad = find(r_tmp < thr);
if isempty(idx_bad)
    r_fill = r_tmp;
    return;
end

% ---- 可选：特殊处理 x_lags1==0 的坏点（保留你原逻辑，但不报错）----
idx_zero_in_bad = idx_bad(x_lags1(idx_bad) == 0);
if ~isempty(idx_zero_in_bad)
    % 这里用 abs(tau) 保持你原来的写法
    r_tmp(idx_zero_in_bad) = corrModel_AD_eq([c, D, abs(tau)], ...
        t_lags_at(idx_zero_in_bad), x_lags1(idx_zero_in_bad) + 100);

    bad_mask = (r_tmp < thr) | ~isfinite(r_tmp);
    idx_bad  = find(bad_mask);
    if isempty(idx_bad)
        r_fill = r_tmp;
        return;
    end
end

% =========================================================
% 1) 第1轮：只对坏点迭代增大 D
% =========================================================
D_curr = D;
for it = 1:max_iter
    D_curr = D_curr + dD;

    r_new = corrModel_AD_eq([c, D_curr, tau], ...
        t_lags_at(idx_bad), x_lags1(idx_bad));

    r_tmp(idx_bad) = r_new;

    bad_mask = (r_tmp < thr) | ~isfinite(r_tmp);
    % if ~isfinite(r_tmp)
    %     xx
    % end
    idx_bad  = find(bad_mask);
    if isempty(idx_bad)
        r_fill = r_tmp;
        return;
    end
end

% =========================================================
% 2) 第2轮：仍有坏点才对 tau 做同样操作（若 dTau 缺失则跳过）
% =========================================================
if nargin >= 9 && ~isempty(dTau) && dTau ~= 0
    tau_curr = tau;

    % 策略：增大 |tau|，保持符号不变
    sgn = sign(tau_curr);
    if sgn == 0
        sgn = 1;
    end

    for it = 1:max_iter
        tau_curr = sgn * (abs(tau_curr) + dTau);

        r_new = corrModel_AD_eq([c, D, tau_curr], ...
            t_lags_at(idx_bad), x_lags1(idx_bad));

        r_tmp(idx_bad) = r_new;

        bad_mask = (r_tmp < thr) | ~isfinite(r_tmp);
        idx_bad  = find(bad_mask);
        if isempty(idx_bad)
            r_fill = r_tmp;
            return;
        end
    end
end

% =========================================================
% 3) 第3轮：仍有坏点 -> 从原始 D 开始，同时增大 D 与 |tau|
% =========================================================
if ~isempty(idx_bad) && nargin >= 9 && ~isempty(dTau) && dTau ~= 0

    D_curr   = D;   % 从原始 D 起步，并保证为正
    tau_curr = tau;

    for it = 1:max_iter
        D_curr   = D_curr + dD;
        tau_curr = tau_curr + dTau;

        r_new = corrModel_AD_eq([c, D_curr, tau_curr], ...
            t_lags_at(idx_bad), x_lags1(idx_bad));

        r_tmp(idx_bad) = r_new;

        bad_mask = (r_tmp < thr) | ~isfinite(r_tmp);
        idx_bad  = find(bad_mask);

        if isempty(idx_bad)
            r_fill = r_tmp;
            return;
        end
    end
end

% =========================================================
% 最终检查：仍坏就 error（同时报告 <thr 与 NaN/Inf）
% =========================================================
n_below = nnz(r_tmp < thr);
n_nf    = nnz(~isfinite(r_tmp));
n_bad   = nnz((r_tmp < thr) | ~isfinite(r_tmp));

error('corrModel_AD_correct_noNaN:DidNotConverge', ...
    ['After correction, %d points are still bad (thr=%.6g): ' ...
    '%d below thr, %d non-finite. Last D=%.6g, tau=%g, dD=%.6g, dTau=%g'], ...
    n_bad, thr, n_below, n_nf, D_curr, tau, dD, ...
    (nargin>=9 && ~isempty(dTau))*dTau);
end
