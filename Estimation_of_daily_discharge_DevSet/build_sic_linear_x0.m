function [x0, x0_mat, support] = build_sic_linear_x0(sg_path, start_day_idx, state_ep)
% BUILD_SIC_LINEAR_X0
% Build the initial KF state from SIC4DVar using linear additive anomaly.
%
% State definition in the KF:
%   x = Q - Qprior
%
% This function:
%   1. takes raw SIC4DVar values in start_day_idx : start_day_idx+state_ep-1;
%   2. converts them to additive anomaly: Q_SIC4DVar - Qprior;
%   3. interpolates each day along reach center position;
%   4. interpolates each reach temporally across the state_ep window;
%   5. fills unsupported entries with zero anomaly.
%
% Outputs:
%   x0      : (nR*state_ep) x 1 vector, ordered by day blocks of nR reaches
%   x0_mat  : nR x state_ep matrix
%   support : nR x state_ep integer mask
%             0 missing/fallback to prior, 1 raw SIC, 2 spatial, 3 temporal

Qprior = sg_path.Q_prior{1, 1}(:, 1);
nR = numel(Qprior);

x0_mat = nan(nR, state_ep);
support = zeros(nR, state_ep);

if isnan(start_day_idx) || start_day_idx < 1 || ...
        ~isfield(sg_path, 'Q_SIC4DVar') || isempty(sg_path.Q_SIC4DVar) || ...
        isempty(sg_path.Q_SIC4DVar{1, 1})
    x0_mat(:) = 0;
    x0 = reshape(x0_mat, [], 1);
    return
end

Qsic = sg_path.Q_SIC4DVar{1, 1};
if isempty(Qsic) || ~iscell(Qsic)
    x0_mat(:) = 0;
    x0 = reshape(x0_mat, [], 1);
    return
end

if isfield(sg_path, 'center_pos') && ~isempty(sg_path.center_pos) && ...
        ~isempty(sg_path.center_pos{1})
    center_pos = sg_path.center_pos{1}(:);
else
    center_pos = (1:nR).';
end

n_days = size(Qsic, 2);
day_idx = start_day_idx : min(start_day_idx + state_ep - 1, n_days);

raw_anom = nan(nR, state_ep);
for kk = 1:numel(day_idx)
    d = day_idx(kk);
    for r = 1:nR
        if r > size(Qsic, 1)
            continue
        end

        val = Qsic{r, d};
        if isempty(val) || ~isnumeric(val)
            continue
        end

        val = val(:);
        val = val(isfinite(val));
        if isempty(val)
            continue
        end

        raw_anom(r, kk) = mean(val, 'omitnan') - Qprior(r);
        support(r, kk) = 1;
    end
end

% Spatial interpolation for each day.
spatial_anom = raw_anom;
for kk = 1:state_ep
    y = raw_anom(:, kk);
    valid = isfinite(y) & isfinite(center_pos);

    if sum(valid) >= 2
        yq = local_interp_by_position(center_pos(valid), y(valid), center_pos);
        fill_idx = ~isfinite(spatial_anom(:, kk)) & isfinite(yq);
        spatial_anom(fill_idx, kk) = yq(fill_idx);
        support(fill_idx, kk) = 2;
    end
end

% Temporal interpolation for each reach.
x0_mat = spatial_anom;
for r = 1:nR
    y = spatial_anom(r, :);
    valid = isfinite(y);

    if sum(valid) >= 2
        t_valid = find(valid);
        yq = interp1(t_valid, y(valid), 1:state_ep, 'linear', nan);
        yq_nearest = interp1(t_valid, y(valid), 1:state_ep, 'nearest', 'extrap');
        yq(~isfinite(yq)) = yq_nearest(~isfinite(yq));

        fill_idx = ~isfinite(x0_mat(r, :)) & isfinite(yq);
        x0_mat(r, fill_idx) = yq(fill_idx);
        support(r, fill_idx) = 3;
    elseif sum(valid) == 1
        t_valid = find(valid);
        fill_idx = ~isfinite(x0_mat(r, :));
        x0_mat(r, fill_idx) = y(t_valid);
        support(r, fill_idx) = 3;
    end
end

% Unsupported entries fall back to zero anomaly, i.e. Qprior.
x0_mat(~isfinite(x0_mat)) = 0;
x0 = reshape(x0_mat, [], 1);

end


function yq = local_interp_by_position(x, y, xq)

x = x(:);
y = y(:);
xq = xq(:);

valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

if numel(x) < 2
    yq = nan(size(xq));
    return
end

[xu, ~, ic] = unique(x);
yu = accumarray(ic, y, [], @mean);

if numel(xu) < 2
    yq = nan(size(xq));
    return
end

yq = interp1(xu, yu, xq, 'linear', nan);
yq_nearest = interp1(xu, yu, xq, 'nearest', 'extrap');
yq(~isfinite(yq)) = yq_nearest(~isfinite(yq));

end
