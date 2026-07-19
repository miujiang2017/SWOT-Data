function out = find_negative_tau_paths(data_in)
% find_negative_tau_paths
% Find paths whose tau contains negative values.
%
% Usage:
%   out = find_negative_tau_paths(data_KF_out);
%
% Output:
%   n x 2 numeric array: [ib, ip]

if nargin < 1 || isempty(data_in) || ~isstruct(data_in)
    error('Input must be a struct array with a tau field.');
end

out = [];

for ib = 1:numel(data_in)
    if ~isfield(data_in(ib), 'tau') || isempty(data_in(ib).tau)
        continue
    end

    tau_paths = data_in(ib).tau;
    if ~iscell(tau_paths)
        continue
    end

    for ip = 1:numel(tau_paths)
        tau = tau_paths{ip};
        if isempty(tau) || ~isnumeric(tau)
            continue
        end

        tau = tau(:);
        neg_idx = find(isfinite(tau) & tau < 0);
        if isempty(neg_idx)
            continue
        end

        out(end+1, :) = [ib, ip]; %#ok<AGROW>
    end
end

if isempty(out)
    fprintf('No negative tau values found.\n');
else
    disp(out);
end

end
