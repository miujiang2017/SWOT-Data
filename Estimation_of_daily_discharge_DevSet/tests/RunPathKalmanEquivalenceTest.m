classdef RunPathKalmanEquivalenceTest < matlab.unittest.TestCase
    %RUNPATHKALMANEQUIVALENCETEST Regression tests for refactored KF runner.

    methods (TestClassSetup)
        function addDevSetToPath(testCase)
            devSetDir = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                devSetDir, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testSyntheticPathMatchesLegacyLoop(testCase)
            stateEp = 3;
            nt = 8;
            nR = 2;
            sgPath = makeSyntheticPath(nR, nt);
            phi = eye(nR * stateEp);
            processNoise = eye(nR * stateEp) * 0.01;

            cfg = swot.config.defaultConfig();
            cfg.kf.stateEp = stateEp;
            cfg.kf.observationProducts = 1;

            actual = swot.filter.runPathKalman(sgPath, phi, processNoise, nR, nt, cfg);
            expected = runLegacyLoop(sgPath, phi, processNoise, nR, nt, stateEp);

            testCase.verifyEqual(actual{1}, expected{1});
        end
    end
end

function sgPath = makeSyntheticPath(nR, nt)
sgPath = struct();
sgPath.rch_len = {ones(nR, 1)};
sgPath.Q_prior = {[10; 20]};
sgPath.minQ_prior = {[7; 14]};
sgPath.maxQ_prior = {[13; 26]};

qCell = cell(nR, nt);
for r = 1:nR
    for t = 1:nt
        if mod(r + t, 2) == 0
            qCell{r, t} = sgPath.Q_prior{1}(r) + 0.1 * r + 0.05 * t;
        end
    end
end
sgPath.Q_SIC4DVar = {qCell};
sgPath.mean_SIC4DVar = sgPath.Q_prior;
end

function QestMed = runLegacyLoop(sgPath, phi, processNoise, nR, nt, stateEp)
xn1n1 = zeros(nR * stateEp, 1);
sigma0 = calc_sigma0(sgPath);
tmp = repmat(sigma0 .^ 2, stateEp, 1);
Pn1n1 = diag(tmp(:));

i = 1;
xnn1(:, 1) = phi * xn1n1;
Pnn1{1} = (phi * Pn1n1 * phi') + processNoise;
[xnn{i}, Pnn{i}] = legacyUpdate(xnn1(:, i), Pnn1{i}, sgPath, stateEp, i, nR);

for i = 2:(nt - stateEp)
    xnn1(:, i) = phi * xnn{i - 1};
    Pnn1{i} = (phi * Pnn{i - 1} * phi') + processNoise; %#ok<AGROW>
    [xnn{i}, Pnn{i}] = legacyUpdate(xnn1(:, i), Pnn1{i}, sgPath, stateEp, i, nR);
end

[~, QestMed] = combine_xnn_SWOT(xnn, Pnn, nR, nt, stateEp, sgPath);
end

function [xn, Pn] = legacyUpdate(xPred, PPred, sgPath, stateEp, ep, nR)
[H_Q, z_Q, R_Q] = build_H_obs_SWOT_Q(sgPath, stateEp, ep, 1);
if ~isempty(z_Q)
    H = [];
    R = [];
    zn = [];
    [H, zn, R] = append_Qobs(H, zn, R, H_Q, z_Q, R_Q);
    Kn = PPred * H' * pinv(H * PPred * H' + R);
    xn = xPred + Kn * (zn - H * xPred);
    Pn = (eye(stateEp * nR) - Kn * H) * PPred;
else
    xn = xPred;
    Pn = PPred;
end
end
