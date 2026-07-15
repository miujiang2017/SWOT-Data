function find_group_vali_corr_equal_one(group_vali_out)
% find_group_vali_corr_equal_one
% =========================================================
% 查找 group_vali_out 里 corr == 1 的位置
%
% 输出：
%   ib, ipath, product, flow, reach_index, corr_value

prod_fields = {'Qest_med', 'SIC4DVar', 'MOMMA', 'geoBAM', 'MetroMan'};
flow_fields = {'low', 'mid', 'high'};

tol = 1e-12;

fprintf('\nLocations where correlation == 1:\n');
fprintf('-------------------------------------------------------------\n');
fprintf('%6s %8s %12s %8s %12s %12s\n', ...
    'ib', 'ipath', 'product', 'flow', 'reach_idx', 'corr');
fprintf('-------------------------------------------------------------\n');

count = 0;

for ib = 1:numel(group_vali_out)

    if ~isfield(group_vali_out(ib), 'paths') || isempty(group_vali_out(ib).paths)
        continue
    end

    paths = group_vali_out(ib).paths;

    if iscell(paths)
        nPath = numel(paths);
    elseif isstruct(paths)
        nPath = numel(paths);
    else
        continue
    end

    for ipath = 1:nPath

        if iscell(paths)
            P = paths{ipath};
        else
            P = paths(ipath);
        end

        if isempty(P) || ~isstruct(P)
            continue
        end

        for iprod = 1:numel(prod_fields)

            pfield = prod_fields{iprod};

            if ~isfield(P, pfield) || isempty(P.(pfield))
                continue
            end

            Sprod = P.(pfield);

            for iflow = 1:numel(flow_fields)

                flow_name = flow_fields{iflow};

                if ~isstruct(Sprod) || ~isfield(Sprod, flow_name) || isempty(Sprod.(flow_name))
                    continue
                end

                Sflow = Sprod.(flow_name);

                if ~isstruct(Sflow) || ~isfield(Sflow, 'corr') || isempty(Sflow.corr)
                    continue
                end

                corr_v = Sflow.corr(:);

                idx = find(~isnan(corr_v) & abs(corr_v - 1) < tol);

                for k = 1:numel(idx)

                    count = count + 1;

                    fprintf('%6d %8d %12s %8s %12d %12.6f\n', ...
                        ib, ipath, pfield, flow_name, idx(k), corr_v(idx(k)));

                end
            end
        end
    end
end

fprintf('-------------------------------------------------------------\n');
fprintf('Total corr == 1 cases: %d\n\n', count);

end