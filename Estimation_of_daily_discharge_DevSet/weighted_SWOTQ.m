function y = weighted_SWOTQ(sg_path, nR)
% weighted_Q_with_interp
% Compute weighted mean discharge from SIC4DVar / MOMMA / geoBAM
% and fill remaining NaNs by interpolation along river center position
%
% Inputs:
%   sg_path : struct containing Q products and center_pos
%   nR      : number of reaches
%
% Output:
%   y       : nR x 1 vector (filled, interpolated)

%% ---------- 1) 每个产品的行均值 ----------
Q_MOMMA_mean    = cellrowmean(sg_path.Q_MOMMA,    nR);
Q_geoBAM_mean   = cellrowmean(sg_path.Q_geoBAM,   nR);
Q_SIC4DVar_mean = cellrowmean(sg_path.Q_SIC4DVar, nR);

%% ---------- 2) 权重（按：SIC4DVar, MOMMA, geoBAM） ----------
mean_percent_unc = [0.5838, 0.6282, 0.6909];
sigma_rel = mean_percent_unc(:);        % 不确定度（越小越好）
w = 1 ./ (sigma_rel.^2);                % 统计上正确的权重

%% ---------- 3) 每个 reach 的加权平均 ----------
Qmat = [Q_SIC4DVar_mean, ...
        Q_MOMMA_mean, ...
        Q_geoBAM_mean];

Q_weighted_mean = nan(nR,1);

for i = 1:nR
    qi = Qmat(i,:);
    valid = ~isnan(qi);
    if any(valid)
        Q_weighted_mean(i) = sum(w(valid) .* qi(valid)') / sum(w(valid));
    end
end

y = Q_weighted_mean;

%% ---------- 4) 若仍有 NaN，沿河道中心位置插值 ----------
x = sg_path.center_pos{1,1}(:);

if any(isnan(y))
    valid = ~isnan(y);
    if sum(valid) >= 2
        y(~valid) = interp1( ...
            x(valid), y(valid), x(~valid), ...
            'linear', 'extrap');
    end
end

end

function row_mean = cellrowmean(C, nR)
% row_mean = cellrowmean(C, nR)
% C  : cell matrix (nR x nT) OR []
% nR : number of reaches
%
% Output:
%   row_mean : nR x 1 (NaN where no valid observation)

% ---- Case 0: completely empty or invalid ----
if isempty(C) || ~iscell(C)
    row_mean = nan(nR,1);
    return
end

% ---- Normal cell case ----
C = C{1,1};
nR0 = size(C,1);
row_mean = nan(nR,1);

for i = 1:nR0
    row = C(i,:);
    has = ~cellfun(@isempty, row);
    if any(has)
        row_mean(i) = mean(cell2mat(row(has)));
    end
end
end

