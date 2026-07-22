function [data_KF_out] = build_cDtau(data_KF_out, state_ep)
% BUILD_CDTAU Estimate c, D, and the WSE-based 1/e decorrelation time.
%
% state_ep is optional and defaults to 22 days. The maximum tau is set to
% twice this state window, while the reach-specific lower bound is limited
% by the effective WSE sampling interval.

if nargin < 2 || isempty(state_ep)
    state_ep = 22;
end
validateattributes(state_ep, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'state_ep');

% Loop through each part in data_KF_out
for ib =  1:6%numel(data_KF_out)
    % Directly work on the current part in data_KF_out
    nPaths = numel(data_KF_out(ib).paths);  % Number of paths for this part

    % Ensure 'c', 'D', and 'tau' are initialized as cell arrays for each path
    if ~isfield(data_KF_out(ib), 'c')
        data_KF_out(ib).c = cell(1, nPaths);  % Initialize 'c' field as cell array
    end
    if ~isfield(data_KF_out(ib), 'D')
        data_KF_out(ib).D = cell(1, nPaths);  % Initialize 'D' field as cell array
    end
    if ~isfield(data_KF_out(ib), 'tau')
        data_KF_out(ib).tau = cell(1, nPaths);  % Initialize 'tau' field as cell array
    end

    % Loop through each path in the part
    for ip = 1:nPaths
        path = data_KF_out(ib).paths{ip};  % Get the current path (reach information)

        nR = numel(path);  % Number of reaches in this path (assuming path is a cell array of reaches)

        % Initialize c, D, and tau for this path
        c = nan(nR, 1);
        D = nan(nR, 1);
        tau = nan(nR, 1);
        min_tau_obs = 10;
        min_pairs_per_bin = 10;
        tau_min = 2 * 86400;
        tau_max = 60* 86400;%2 * state_ep * 86400;

        % Extract necessary data for this path
        w_sword = data_KF_out(ib).w_sword{ip};  % Width for this path
        s_sword = data_KF_out(ib).s_sword{ip};  % Width for this path
        % if ~isempty(data_KF_out(ib).s_IRIS)
        %     s_IRIS = data_KF_out(ib).s_IRIS{ip};  % Slope for this path
        % else
        %     s_IRIS = nan;
        % end
        Q_prior = data_KF_out(ib).Q_prior{ip};  % Mean discharge for this path
        center_pos = data_KF_out(ib).center_pos{ip};  % Center position for this path
        W = data_KF_out(ib).width_RiverSP{ip};  % Mean discharge for this path
        S = data_KF_out(ib).slope_RiverSP{ip};  % Center position for this path
        % Gauge_Q = data_KF_out(ib).Gauge_Q_intpl{ip};
        H = data_KF_out(ib).wse_RiverSP{ip};



        % Initialize output vector for the decorrelation length of each reach
        decorrelation_lengths = NaN(1, nR);

        % Loop over each reach
        for r = 1:nR

            % Extract the water-level time series for reach r (stored as cells)
            h = H(r, :);

            % Replace empty cells with NaN for easier numeric processing
            h(cellfun(@isempty, h)) = {NaN};

            % Convert the cell row into a numeric array
            h = cell2mat(h);

            % If the entire series contains no valid data, skip this reach
            if all(isnan(h))
                continue;
            end

            % Remove the mean (compute autocorrelation on zero-mean data)
            h = h - nanmean(h);

            % Identify indices with valid (non-NaN) observations
            valid_indices = ~isnan(h);
            h_valid      = h(valid_indices);       % Valid water-level values
            time_valid   = find(valid_indices);    % Corresponding time indices

            % Number of valid data points
            N = length(h_valid);
            if N < min_tau_obs || var(h_valid) <= 0
                continue;
            end

            % Keep the original four-gap smoothing scale, but use the
            % median gap so long missing intervals do not inflate the bins.
            % The first lag-bin center is therefore 2*dt_eff.
            dt_eff = median(diff(time_valid), 'omitnan');
            bin_width = 4 * dt_eff;
            if ~isfinite(bin_width) || bin_width <= 0
                continue;
            end

            % Container for all pairwise lag-correlation samples: [dt, h_i*h_j]
            acf_data = [];

            % Compute all pairwise products h(i) * h(j) and their time lags dt
            for i = 1:N
                for j = i+1:N
                    dt      = abs(time_valid(j) - time_valid(i));  % Time difference
                    corr_ij = h_valid(i) * h_valid(j);             % Autocorrelation term
                    acf_data = [acf_data; dt, corr_ij];
                end
            end
            if isempty(acf_data)
                continue;
            end
            % Construct lag bins and compute mean correlation within each bin
            max_lag    = max(acf_data(:,1));                     % Maximum time lag
            edges      = 0:bin_width:(max_lag + bin_width);      % Bin boundaries
            lag_centers = edges(1:end-1) + bin_width/2;          % Bin center values
            acf_vals   = NaN(length(lag_centers), 1);            % Binned ACF values
            pair_counts = zeros(length(lag_centers), 1);

            % Average the correlation samples within each lag bin
            for k = 1:length(lag_centers)
                if k < length(lag_centers)
                    idx = acf_data(:,1) >= edges(k) & acf_data(:,1) < edges(k+1);
                else
                    idx = acf_data(:,1) >= edges(k) & acf_data(:,1) <= edges(k+1);
                end
                pair_counts(k) = sum(idx);
                if any(idx)
                    acf_vals(k) = mean(acf_data(idx, 2));
                else
                    acf_vals(k) = NaN;
                end
            end

            % Normalize the ACF by the variance to obtain correlation coefficients
            acf_vals = acf_vals / var(h_valid);

            % A lag bin supported by only a few pairs is too unstable to
            % determine the first 1/e crossing.
            acf_vals(pair_counts < min_pairs_per_bin) = NaN;

            % Suppress an isolated noisy bin while retaining the original
            % empirical 1/e-crossing definition.
            acf_smooth = movmedian(acf_vals, 3, 'omitnan');

            % Find the first lag where ACF drops below 1/e (≈ 0.3679)
            crossing_level = 1 / exp(1);
            idx = find(isfinite(acf_vals) & isfinite(acf_smooth) & ...
                acf_smooth < crossing_level, 1, 'first');

            % Store the decorrelation length if found
            if ~isempty(idx)
                tau_day = lag_centers(idx);

                % Interpolate between the nearest supported bins on either
                % side of 1/e to avoid quantizing tau at bin centers.
                idx_prev = find(isfinite(acf_vals(1:idx-1)) & ...
                    isfinite(acf_smooth(1:idx-1)) & ...
                    acf_smooth(1:idx-1) >= crossing_level, 1, 'last');
                if ~isempty(idx_prev)
                    rho1 = acf_smooth(idx_prev);
                    rho2 = acf_smooth(idx);
                    t1 = lag_centers(idx_prev);
                    t2 = lag_centers(idx);
                    if isfinite(rho1) && isfinite(rho2) && rho1 ~= rho2
                        tau_interp = t1 + (crossing_level-rho1) * ...
                            (t2-t1) / (rho2-rho1);
                        if isfinite(tau_interp) && tau_interp >= t1 && tau_interp <= t2
                            tau_day = tau_interp;
                        end
                    end
                end

                % Do not claim a decorrelation time shorter than the
                % typical observation interval of this reach.
                tau_min_reach_day = max(tau_min / 86400, dt_eff);
                tau_day = min(max(tau_day, tau_min_reach_day), tau_max / 86400);
                decorrelation_lengths(r) = tau_day;
            end
        end

        tau = decorrelation_lengths * 86400;
        tau(isfinite(tau)) = min(max(tau(isfinite(tau)), tau_min), tau_max);


        % Calculate Hydraulic Diffusivity D and Wave Celerity c for each reach in the path
        for i = 1:nR
            % Remove NaNs and calculate c
            W_row  = W(i, :);
            S_row  = S(i, :);
            non_empty_idx = ~cellfun(@isempty,  W_row) & ~cellfun(@isempty,  S_row);  % Non-empty index
            if sum(non_empty_idx) > 0
                W_row = cell2mat(W_row(non_empty_idx));
                S_row = cell2mat(S_row(non_empty_idx));
                % c(i) = (5 / 3) * 1.2 * mean((W_row)'.^0.8 .* (abs(S_row))'.^0.6);
             %  c(i) = (5 / 3) * 1.627053 * mean(W_row)'.^0.8 .* mean(abs(S_row))'.^0.6;
                   c(i) = (5 / 3) * 1.025247 *w_sword(i).^0.8 .* (abs(s_sword(i)))'.^0.6;
                % 原始方案：直接对每个 measurement 算 Q/(2WS) 后取 median，容易被很小的瞬时 slope 放大
                D(i) = median(abs(Q_prior(i,1) ./ (2 * W_row .* abs(S_row))));
                W_eff = median(W_row(isfinite(W_row) & W_row > 0), 'omitnan');
                S_eff = median(abs(S_row(isfinite(S_row) & S_row ~= 0)), 'omitnan');
                S_eff = max(S_eff, 1e-6);
                if isfinite(W_eff) && W_eff > 0 && isfinite(S_eff) && S_eff > 0
                    D(i) = abs(Q_prior(i,1) / (2 * W_eff * S_eff));
                end
                % c(i) = (5 / 3) * 1.48 * w_sword(i)'.^0.8 .* mean(abs(S_row))'.^0.6;
                %D(i) = median(abs(Q_prior(i,1) ./ (2 * w_sword(i) .* s_sword(i))));
            end

            % Calculate D using the formula: D = Q/(2 * W * S)
            % Where Q is the discharge, W is width, and S is slope
            % if ~isnan(s_IRIS)
            %     D(i) = abs(Q_prior(i,1) / (2 * w_sword(i) * s_IRIS(i,1)));
            % else
            %     if s_sword(i,1)>1e-10
            %         D(i) = abs(Q_prior(i,1) / (2 * w_sword(i) * s_sword(i,1)/1000));
            %     else
            %         s_mean = mean(s_sword(s_sword>1e-10));
            %         D(i) = abs(Q_prior(i,1) / (2 * w_sword(i) * s_mean(i,1)/1000));
            %     end
            % end
            % % Calculate tau for this path (autocorrelation of Gauge_Q_intpl)
            % if ~isempty( Gauge_Q{i, 1})
            %     y = Gauge_Q{i, 1}(end-365:end,2);
            %     [cval, lags] = xcorr(y, 'normalized');
            %     corr_y = cval(nR - 1 : -1 : 1);
            %     dt = [1 : nR - 1]';
            %     tau(i, 1) = -sum(log(corr_y) .* dt) / sum(log(corr_y).^2) * 86400;  % Convert to seconds
            % else
            %     % If Gauge_Q_intpl is missing for this reach, use interpolation
            %     tau(i, 1) = nan;  % You can add your interpolation method here if needed
            % end
        end

        % Interpolate missing values for c and D if needed
        % 遍历每个位置
        for i = 1:length(c)
            if isnan(c(i))  % 如果当前值为 NaN
                % 获取有效的中心位置和对应的c值
                valid_indices = ~isnan(c);

                if sum(valid_indices) >= 2  % 如果有效数据大于或等于 2，则使用线性插值
                    % 先做线性插值（不外插），区间外会返回 NaN
                    c_lin = interp1(center_pos(valid_indices), ...
                        c(valid_indices), ...
                        center_pos(i), ...
                        'linear');  % 注意：没有 'extrap'

                    if isnan(c_lin)
                        % 需要外插的地方：用最近邻
                        c(i) = interp1(center_pos(valid_indices), ...
                            c(valid_indices), ...
                            center_pos(i), ...
                            'nearest','extrap');
                    else
                        % 区间内：用线性插值
                        c(i) = c_lin;
                    end
                else
                    % 如果有效数据不足 2，则使用最近邻插值
                    c(i) = c(valid_indices);
                end
            end
            if isnan(D(i))  % 如果当前值为 NaN
                % 获取有效的中心位置和对应的D值
                valid_indices = ~isnan(D);

                if sum(valid_indices) >= 2  % 如果有效数据大于或等于 2，则使用线性插值
                    % 先做线性插值（不外插），区间外会返回 NaN
                    D_lin = interp1(center_pos(valid_indices), ...
                        D(valid_indices), ...
                        center_pos(i), ...
                        'linear');  % 注意：没有 'extrap'

                    if isnan(D_lin)
                        % 需要外插的地方：用最近邻
                        D(i) = interp1(center_pos(valid_indices), ...
                            D(valid_indices), ...
                            center_pos(i), ...
                            'nearest','extrap');
                    else
                        % 区间内：用线性插值
                        D(i) = D_lin;
                    end
                else
                    % 如果有效数据不足 2，则使用最近邻插值
                    D(i) = D(valid_indices);
                end
            end

            if isnan(tau(i))  % 如果当前值为 NaN
                % 获取有效的中心位置和对应的tau值
                valid_indices = ~isnan(tau);

                if sum(valid_indices) >= 2  % 如果有效数据大于或等于 2，则使用线性插值
                    % 先做线性插值（不外插），区间外会返回 NaN
                    tau_lin = interp1(center_pos(valid_indices), ...
                        tau(valid_indices), ...
                        center_pos(i), ...
                        'linear');

                    if isnan(tau_lin)
                        % 需要外插的地方：用最近邻
                        tau(i) = interp1(center_pos(valid_indices), ...
                            tau(valid_indices), ...
                            center_pos(i), ...
                            'nearest','extrap');
                    else
                        % 区间内：用线性插值
                        tau(i) = tau_lin;
                    end
                else
                    % 如果有效数据不足 2，则使用最近邻插值
                    if any(valid_indices)
                        tau(i) = tau(valid_indices);
                    end
                end
                if isfinite(tau(i))
                    tau(i) = min(max(tau(i), tau_min), tau_max);
                end
            end
        end

        % Smooth tau along the path in log-space to reduce isolated reach-scale spikes.
        valid_tau = isfinite(tau) & tau > 0;
        if sum(valid_tau) >= 3
            logtau = log(tau);
            logtau_smooth = movmedian(logtau, 3, 'omitnan');
            tau(valid_tau) = exp(logtau_smooth(valid_tau));
            tau(valid_tau) = min(max(tau(valid_tau), tau_min), tau_max);
        end

        % Smooth D along the path in log-space to reduce isolated reach-scale spikes.
        valid_D = isfinite(D) & D > 0;
        D2 = D;
        if sum(valid_D) >= 3
            logD = log(D);
            logD_smooth = movmedian(logD, 3, 'omitnan');
            D(valid_D) = exp(logD_smooth(valid_D));
        end

        % Store the results back in the part structure for this path
        data_KF_out(ib).c{ip} = c;  % Store c for this path
        data_KF_out(ib).D{ip} = D;  % Store D for this path
        data_KF_out(ib).tau{ip} = tau;  % Store tau for this path
    end
end
end
