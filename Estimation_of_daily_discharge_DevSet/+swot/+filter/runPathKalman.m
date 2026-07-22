function Qest_med = runPathKalman(sg_path, Phi_st, Q_st, nR, nt, cfg)
%RUNPATHKALMAN Run the legacy 22-day Kalman filter for one river path.

arguments
    sg_path (1,1) struct
    Phi_st double
    Q_st double
    nR (1,1) double
    nt (1,1) double
    cfg (1,1) struct
end

stateEp = cfg.kf.stateEp;
xn1n1 = buildInitialState(sg_path, nR, stateEp, cfg.kf.initialStateMode);
sigma0 = calc_sigma0(sg_path);
tmp = repmat(sigma0 .^ 2, stateEp, 1);
Pn1n1 = diag(tmp(:));

xnn1 = zeros(nR * stateEp, max(nt - stateEp, 1));
Pnn1 = cell(1, max(nt - stateEp, 1));
xnn = cell(1, max(nt - stateEp, 1));
Pnn = cell(1, max(nt - stateEp, 1));

i = 1;
xnn1(:, i) = Phi_st * xn1n1;
Pnn1{i} = (Phi_st * Pn1n1 * Phi_st') + Q_st;
[xnn{i}, Pnn{i}] = updateOneStep(xnn1(:, i), Pnn1{i}, sg_path, stateEp, i, cfg);

for i = 2:(nt - stateEp)
    xnn1(:, i) = Phi_st * xnn{i - 1};
    Pnn1{i} = (Phi_st * Pnn{i - 1} * Phi_st') + Q_st;
    [xnn{i}, Pnn{i}] = updateOneStep(xnn1(:, i), Pnn1{i}, sg_path, stateEp, i, cfg);
end

[~, Qest_med] = combine_xnn_SWOT(xnn, Pnn, nR, nt, stateEp, sg_path);
end

function x0 = buildInitialState(sg_path, nR, stateEp, initialStateMode)
switch string(initialStateMode)
    case "zero_anomaly"
        x0 = zeros(nR * stateEp, 1);
    case "legacy_start_value"
        obsMean = sg_path.Q_prior{1, 1}(:, 1);
        x0 = reshape(sg_path.start_value{1, 1} - obsMean, [], 1);
    otherwise
        error('Unknown initialStateMode: %s.', initialStateMode);
end
end

function [xn, Pn] = updateOneStep(xPred, PPred, sg_path, stateEp, ep, cfg)
[H, zn, R] = buildCombinedQObservation(sg_path, stateEp, ep, cfg.kf.observationProducts);
if isempty(zn)
    xn = xPred;
    Pn = PPred;
    return
end

Kn = PPred * H' * pinv(H * PPred * H' + R);
xn = xPred + Kn * (zn - H * xPred);
Pn = (eye(size(PPred, 1)) - Kn * H) * PPred;
end

function [H, zn, R] = buildCombinedQObservation(sg_path, stateEp, ep, observationProducts)
H = [];
zn = [];
R = [];

for productIdx = observationProducts(:)'
    [H_Q, z_Q, R_Q] = build_H_obs_SWOT_Q(sg_path, stateEp, ep, productIdx);
    if ~isempty(z_Q)
        [H, zn, R] = append_Qobs(H, zn, R, H_Q, z_Q, R_Q);
    end
end
end
