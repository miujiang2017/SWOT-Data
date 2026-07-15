function find_negative_rB_group_vali(group_vali_out)

prod_fields = {'Qest_med', 'SIC4DVar', 'MOMMA', 'geoBAM', 'MetroMan'};
flow_fields = {'low', 'mid', 'high'};

fprintf('\nLocations where rB < 0:\n');
fprintf('-------------------------------------------------------------\n');
fprintf('%6s %8s %12s %8s %12s %12s\n', ...
    'ib', 'ipath', 'product', 'flow', 'reach_idx', 'rB');
fprintf('-------------------------------------------------------------\n');

count = 0;

for ib = 1:numel(group_vali_out)

    if ~isfield(group_vali_out(ib), 'paths') || isempty(group_vali_out(ib).paths)
        continue
    end

    paths = group_vali_out(ib).paths;

    for ipath = 1:numel(paths)

        P = paths(ipath);

        for iprod = 1:numel(prod_fields)

            pfield = prod_fields{iprod};

            if ~isfield(P, pfield) || isempty(P.(pfield))
                continue
            end

            Sprod = P.(pfield);

            for iflow = 1:numel(flow_fields)

                flow_name = flow_fields{iflow};

                if ~isfield(Sprod, flow_name) || isempty(Sprod.(flow_name))
                    continue
                end

                Sflow = Sprod.(flow_name);

                if ~isfield(Sflow, 'rB') || isempty(Sflow.rB)
                    continue
                end

                rB = Sflow.rB(:);
                idx = find(~isnan(rB) & rB < 0);

                for k = 1:numel(idx)
                    count = count + 1;
                    fprintf('%6d %8d %12s %8s %12d %12.4f\n', ...
                        ib, ipath, pfield, flow_name, idx(k), rB(idx(k)));
                end
            end
        end
    end
end

fprintf('-------------------------------------------------------------\n');
fprintf('Total negative rB cases: %d\n\n', count);

end