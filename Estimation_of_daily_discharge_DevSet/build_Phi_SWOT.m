function [Phi_st, Q_st, Sigma] = build_Phi_SWOT(sg_path, state_ep)
    % Extract information from sg_path
    nR = length(sg_path.rch_len{1});  % Number of reaches
    L_center_pos = sg_path.center_pos{1};  % Center positions for each reach
    c = sg_path.c{1};  % Wave celerity for each reach
    D = sg_path.D{1};  % Hydraulic diffusivity for each reach
    tau = abs(sg_path.tau{1});  % Decorrelation length for each reach
    idx = find(tau < 2*86400);
    tau(idx) = mean(tau);
    thr = 0.001;

    % Initialize matrices for correlation
    R_crs_mat = zeros(state_ep * nR, state_ep * nR);  % Cross-correlation matrix
    R_auto_mat = zeros(state_ep * nR, state_ep * nR);  % Autocorrelation matrix

    % Loop through each reach to calculate the correlation matrices
    for i = 1:nR
        idx1 = nR - i + 1;  % Index for cross-correlation

        % Cross-correlation calculation
        x_lags1 = repmat(L_center_pos, state_ep, 1) - L_center_pos(i);
        idx2 = find(x_lags1(1:nR) < 0);
        idx2 = repmat(idx2, state_ep, 1);
        idx3 = find(x_lags1 < 0);
        tmp = 1:state_ep;
        t_lags_cr = [];
        idx4 = setdiff((1:nR*state_ep)',idx3);
        for k = 1:state_ep
            lag = reshape(repmat(tmp, nR, 1), state_ep * nR, 1);
            t_lags_cr{k} = lag .* 86400;  % Time lags in seconds
            tmp = tmp - 1;

            %Calculate cross-correlation using the correlation model
            r_cr = corrModel_AD_eq([c(i) D(i) tau(i)], t_lags_cr{k}(idx4), (x_lags1(idx4)));
            idx5 = find(r_cr < thr);
            if ~isempty(idx5)
                r_cr(idx5) = corrModel_AD_correct(c(i), D(i), tau(i), t_lags_cr{k}(idx4(idx5)), (x_lags1(idx4(idx5))), r_cr(idx5), 200, thr,200);
            end

            r_tmp_cr = [];
            if ~isempty(idx2)
                for j = 1:length(idx3)
                    r_tmp_cr(j, 1) = corrModel_AD_eq([c(idx2(j)) D(idx2(j)) tau(idx2(j))], (-t_lags_cr{k}(idx3(j))), (-x_lags1(idx3(j))));
                    if r_tmp_cr(j, 1) < thr
                        r_tmp_cr(j, 1) = corrModel_AD_correct(c(idx2(j)), D(idx2(j)), tau(idx2(j)), (-t_lags_cr{k}(idx3(j))), (-x_lags1(idx3(j))), r_tmp_cr(j, 1), 200, thr,200);
                    end
                end
            end
            R_crs_mat(idx4, i + nR * (k - 1)) = r_cr;
            R_crs_mat(idx3, i + nR * (k - 1)) = r_tmp_cr;
        end

        % Autocorrelation calculation
        x_lags1 = repmat(L_center_pos, state_ep, 1) - L_center_pos(i);
        idx2 = find(x_lags1(1:nR) < 0);
        idx2 = repmat(idx2, state_ep, 1);
        idx3 = find(x_lags1 < 0);
        tmp = 0:state_ep - 1;
        t_lags_at = [];
        idx4 = setdiff((1:nR*state_ep)',idx3);

        for k = 1:state_ep
            lag = reshape(repmat(tmp, nR, 1), state_ep * nR, 1);
            t_lags_at{k} = lag .* 86400;  % Time lags in seconds
            tmp = tmp - 1;

            % Calculate autocorrelation using the correlation model
            r_at = corrModel_AD_eq([c(i) D(i) tau(i)], t_lags_at{k}(idx4), (x_lags1(idx4)));
            idx6 = find(r_at < thr);
            if ~isempty(idx6)
                r_at(idx6) = corrModel_AD_correct(c(i), D(i), tau(i), t_lags_at{k}(idx4(idx6)), (x_lags1(idx4(idx6))), r_at(idx6), 200, thr,200);
            end

            r_tmp_at = [];
            if ~isempty(idx2)
                for j = 1:length(idx3)
                    r_tmp_at(j, 1) = corrModel_AD_eq([c(idx2(j)) D(idx2(j)) tau(idx2(j))], (-t_lags_at{k}(idx3(j))), (-x_lags1(idx3(j))));
                    if r_tmp_at(j, 1) < thr
                        r_tmp_at(j, 1) = corrModel_AD_correct(c(idx2(j)), D(idx2(j)), tau(idx2(j)), (-t_lags_at{k}(idx3(j))), (-x_lags1(idx3(j))), r_tmp_at(j, 1), 200, thr,200);
                    end
                end
            end
            R_auto_mat(idx4, i + nR * (k - 1)) = r_at;
            R_auto_mat(idx3, i + nR * (k - 1)) = r_tmp_at;
        end
    end

    % Phi_st (Final Correlation Matrix)
    Phi_st = R_crs_mat + R_auto_mat;

    % Q_st (not specified in your code, so assume it to be the correlation matrix)
    Q_st = Phi_st;

    % Sigma (Standard deviation of the correlation)
    Sigma = std(Phi_st, 0, 2);  % Standard deviation along rows (reach dimension)#

    % Q_st = Sigma -  Sigma_delta * inv(Sigma) *Sigma_delta';
[Phi_st, Q_st] = stabilize_transition(sg_path, R_auto_mat, R_crs_mat, state_ep);
end


%%
% x_lag =0:100:500000;
% for j = 1:length(x_lag) 
%     % 
%     a(j) = corrModel_AD_eq([c(i) D(i) tau(i)], t_lags_cr{1}(1),  x_lag(j)); 
%      % a1(j) = corrModel_AD_eq([1.85 166 11.57*86400], 86400,  x_lag(j)); 
%      % a2(j) = corrModel_AD_eq([1.85 266 11.57*86400],  86400,  x_lag(j)); 
%      % a3(j) = corrModel_AD_eq([1.85 566 11.57*86400],  86400,  x_lag(j)); 
%      % a4(j) = corrModel_AD_eq([1.85 1066 11.57*86400],  86400,  x_lag(j)); 
% end
% figure,plot(x_lag/1000,a,'linewidth',1.2)
% hold on
% plot(x_lag/1000,a2,'linewidth',1.2)
% 
% hold on
% plot(x_lag/1000,a3,'linewidth',1.2)
% hold on
% plot(x_lag/1000,a4,'linewidth',1.2)
% ylabel('correlation');
% xlabel('\Delta x [km]');
% set(gca, 'FontSize', 15); 
% title('Correlation');
% legend({'D = 166 m^3/s','D = 266 m^3/s','D = 566 m^3/s','D = 1066 m^3/s'})