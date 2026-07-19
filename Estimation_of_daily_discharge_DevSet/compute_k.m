function [k_median, basins_out] = compute_k(basins_out)

for ib = 1:numel(basins_out)

    npath = numel(basins_out(ib).Y_MOMMA);
    basins_out(ib).k = cell(npath,1);

    for ip = 1:npath

        Ycell = basins_out(ib).Y_MOMMA{ip};
        qdata = basins_out(ib).Q_SVS{ip};

        if isempty(Ycell) || isempty(qdata)
            basins_out(ib).k{ip} = [];
            continue
        end

        width = basins_out(ib).width_sword{ip};
        slope = basins_out(ib).slope_sword{ip};

        width = width(:);
        slope = slope(:);

        nreach = min([numel(Ycell), numel(qdata), numel(width), numel(slope)]);
        k = nan(nreach,1);

        for ir = 1:nreach

            Yi = Ycell{ir};
            Qi = qdata{ir};

            if isempty(Yi) || isempty(Qi)
                continue
            end

            if size(Qi,2) < 2
                continue
            end

            Ymean = median(Yi(:), 'omitnan');
            Qmean = median(Qi(:,2), 'omitnan');

            Wi = width(ir);
            Si = slope(ir);

            if isnan(Ymean) || isnan(Qmean) || isnan(Wi) || isnan(Si)
                continue
            end

            if Ymean <= 0 || Wi <= 0 || Si == 0
                continue
            end

            k(ir) = Qmean / ...
                (Ymean * Wi^1.8 * abs(Si*1e-3)^0.6);
            
            % k(ir) = median(Qi(:,2) ./ ...
            %     (Ymean * Wi^1.8 * abs(Si*1e-3)^0.6), 'omitnan');
        end

        basins_out(ib).k{ip} = k;

    end
end
%% ===== 所有有效 k 的 median =====

k_all = [];

for ib = 1:numel(basins_out)

    if ~isfield(basins_out(ib),'k') || isempty(basins_out(ib).k)
        continue
    end

    for ip = 1:numel(basins_out(ib).k)

        kvec = basins_out(ib).k{ip};

        if isempty(kvec)
            continue
        end

        kvec = kvec(:);
        kvec = kvec(~isnan(kvec));

        if isempty(kvec)
            continue
        end

        k_all = [k_all; kvec];

    end
end

k_median = median(k_all,'omitnan');

fprintf('Valid k number = %d\n', numel(k_all));
fprintf('Median k = %.6f\n', k_median);
end