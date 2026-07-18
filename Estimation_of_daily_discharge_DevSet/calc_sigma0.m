function sigma0 = calc_sigma0(sg_path)
% init_P0_from_Qstats
% Initialize KF initial covariance from Q statistics
%
% Inputs (nR x 1):
%   Qmin, Qmean, Qmax
%
% Output (nR x 1):
%   P0  : std for each reach

Qmin = sg_path.minQ_prior{1, 1}(:,1);
Qmax = sg_path.maxQ_prior{1, 1}(:,1);
Qmean = sg_path.Q_prior{1, 1}(:,1);
nR = numel(Qmean);
sigma0 = nan(nR,1);

for i = 1:nR
    if Qmax(i) / Qmean(i) > 10
        % Extreme-flood dominated reach
        sigma0(i) = 0.16237 * Qmean(i);
    else
        % Normal range-based estimate
        sigma0(i) = (Qmax(i) - Qmin(i)) / 6;
        
    end
end

end
