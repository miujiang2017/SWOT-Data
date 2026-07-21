function [Q_tmp, Qest_center] = combine_xnn_SWOT_center(xnn, Pnn, nR, nt, state_ep, sg_path)
%COMBINE_XNN_SWOT_CENTER Convert 22-day KF states to daily discharge by center selection.
%
% This is the same window unstacking logic as combine_xnn_SWOT.m, but the
% final daily estimate does not use the median across all overlapping windows.
% For each target day, it selects the estimate where that day is closest to
% the center of the 22-day state window. If that center estimate is missing,
% it falls back to the original median.
%
% Inputs and outputs match combine_xnn_SWOT.m.
% Pnn is accepted for signature compatibility and is not used here.

%#ok<*INUSD>

Q_prior = sg_path.Q_prior{1, 1}(:, 1);
Q = nan(nR * state_ep, numel(xnn));

for i = 1:numel(xnn)
    Q(:, i) = xnn{i};
end

Q_tmp = cell(1, state_ep);
for i = 1:state_ep
    row_idx = (i - 1) * nR + (1:nR);
    if i == 1
        Q_tmp{i} = [Q(row_idx, :), reshape(Q((i * nR + 1):end, end), nR, state_ep - 1)];
    elseif i == state_ep
        Q_tmp{i} = [reshape(Q(1:(end - nR), 1), nR, state_ep - 1), Q(row_idx, :)];
    else
        Q_tmp{i} = [reshape(Q(1:((i - 1) * nR), 1), nR, i - 1), ...
            Q(row_idx, :), reshape(Q((i * nR + 1):end, end), nR, state_ep - i)];
    end
    Q_tmp{i} = Q_tmp{i} + mean(Q_prior, 2);
end

center_idx = ceil(state_ep / 2);
Qest_center = cell(1, 1);
for j = 1:(nt - 1)
    vals = nan(nR, state_ep);
    for i = 1:state_ep
        vals(:, i) = Q_tmp{i}(:, j);
    end

    q = vals(:, center_idx);
    fallback = median(vals, 2, 'omitnan');
    bad = ~isfinite(q);
    q(bad) = fallback(bad);
    Qest_center{1}(:, j) = q;
end
end
