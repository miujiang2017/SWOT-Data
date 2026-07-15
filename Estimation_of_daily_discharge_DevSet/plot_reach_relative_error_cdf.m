function plot_reach_relative_error_cdf(Q_results, data_KF_out, start_date)
% PLOT_REACH_RELATIVE_ERROR_CDF
% =========================================================
% 每个 basin / path 画一张图；
% 同一个 path 里，每个“有 gauge 且至少一条曲线可计算误差”的 reach 放在一个 tile
%
% 图内容：
%   - 画各产品相对于 gauge 的 absolute error CDF
%   - 对非 daily 产品，再额外画 linear interpolation 后的 CDF（虚线）
%   - 每个 reach 的 Q_prior 相对 gauge 的误差，用 xline 画竖线
%
% 误差来源：
%   - 直接使用 Q_results 里 validation 阶段已经存好的 .error
%   - 不再在本函数里重新计算
%
% 曲线：
%   实线：
%       Q_est(med)
%       Q_SIC4DVar
%       Q_MOMMA
%       Q_geoBAM
%       Q_MetroMan
%   虚线：
%       Q_SIC4DVar interp
%       Q_MOMMA interp
%       Q_geoBAM interp
%       Q_MetroMan interp
%   竖线：
%       Q_prior
%
% 排版规则：
%   - nValid <= 8  : nValid x 1
%   - nValid > 8   : 两列排布

fontSize = 13;
start_dn = datenum(start_date); %#ok<NASGU>

% ===== 参数 =====
gauge_eps = 1e-6;   % gauge 过小则不参与 prior 误差计算
min_pts   = 3;      % 至少这么多个有效点才画CDF

% ---- 颜色 ----
cKF    = [0 0.4470 0.7410];
cSIC   = [0.6350 0.0780 0.1840];
cMOM   = [0.4660 0.6740 0.1880];
cGEO   = [0.4940 0.1840 0.5560];
cMM    = [0.9290 0.6940 0.1250];
cPrior = [0 0 0];

for ib = 169% :numel(Q_results)

    if ~isfield(Q_results(ib), 'Qest_med') || isempty(Q_results(ib).Qest_med)
        continue;
    end

    nPath = numel(Q_results(ib).Qest_med);

    for p = 1:nPath

        % =========================================================
        % 检查各个 validation struct 是否存在
        % =========================================================
        vali_est  = get_vali_struct(Q_results(ib), 'vali_estmed',         p);
        vali_sic  = get_vali_struct(Q_results(ib), 'vali_SIC4DVar',       p);
        vali_mom  = get_vali_struct(Q_results(ib), 'vali_MOMMA',          p);
        vali_geo  = get_vali_struct(Q_results(ib), 'vali_geoBAM',         p);
        vali_mm   = get_vali_struct(Q_results(ib), 'vali_MetroMan',       p);

        vali_sic_i = get_vali_struct(Q_results(ib), 'vali_SIC4DVar_interp', p);
        vali_mom_i = get_vali_struct(Q_results(ib), 'vali_MOMMA_interp',    p);
        vali_geo_i = get_vali_struct(Q_results(ib), 'vali_geoBAM_interp',   p);
        vali_mm_i  = get_vali_struct(Q_results(ib), 'vali_MetroMan_interp', p);

        % 至少得有 est 才继续
        if isempty(vali_est) || ~isfield(vali_est, 'error') || isempty(vali_est.error)
            continue;
        end

        % =========================================================
        % 读取 gauge / prior / reach id
        % =========================================================
        Gauge_path = [];
        if isfield(data_KF_out(ib), 'SVS_Q') && ...
                ~isempty(data_KF_out(ib).SVS_Q) && ...
                numel(data_KF_out(ib).SVS_Q) >= p
            Gauge_path = data_KF_out(ib).SVS_Q{p};
        end

        Qprior_path = get_field_if_exists(data_KF_out(ib), 'Q_prior', p);

        reach_ids = [];
        if isfield(data_KF_out(ib), 'paths') && ...
                ~isempty(data_KF_out(ib).paths) && ...
                numel(data_KF_out(ib).paths) >= p
            reach_ids = data_KF_out(ib).paths{p};
        end

        % =========================================================
        % 推断 nR
        % =========================================================
        nR = infer_nR_from_vali(vali_est);
        if nR <= 0
            continue;
        end

        % =========================================================
        % 找 valid reaches
        % 必须有 gauge，且至少一条曲线可画 or prior 可画
        % =========================================================
        valid_reaches = [];

        for r = 1:nR
            [~, Qg_val] = get_gauge_series(Gauge_path, r);
            if isempty(Qg_val) || all(isnan(Qg_val))
                continue;
            end

            re_kf    = get_error_from_vali(vali_est,   r);
            re_sic   = get_error_from_vali(vali_sic,   r);
            re_mom   = get_error_from_vali(vali_mom,   r);
            re_geo   = get_error_from_vali(vali_geo,   r);
            re_mm    = get_error_from_vali(vali_mm,    r);

            re_sic_i = get_error_from_vali(vali_sic_i, r);
            re_mom_i = get_error_from_vali(vali_mom_i, r);
            re_geo_i = get_error_from_vali(vali_geo_i, r);
            re_mm_i  = get_error_from_vali(vali_mm_i,  r);

            Qprior   = get_reach_prior(Qprior_path, r);
            re_prior = calc_relerr_prior_vs_gauge(Qprior, Qg_val, gauge_eps);

            has_any = (numel(re_kf)    >= min_pts) || ...
                      (numel(re_sic)   >= min_pts) || ...
                      (numel(re_mom)   >= min_pts) || ...
                      (numel(re_geo)   >= min_pts) || ...
                      (numel(re_mm)    >= min_pts) || ...
                      (numel(re_sic_i) >= min_pts) || ...
                      (numel(re_mom_i) >= min_pts) || ...
                      (numel(re_geo_i) >= min_pts) || ...
                      (numel(re_mm_i)  >= min_pts) || ...
                      (~isempty(re_prior) && isfinite(re_prior));

            if has_any
                valid_reaches(end+1) = r; %#ok<AGROW>
            end
        end

        if isempty(valid_reaches)
            continue;
        end

        nValid = numel(valid_reaches);

        % =========================================================
        % 排版
        % =========================================================
        if nValid <= 8
            nrow = nValid;
            ncol = 1;
            figW = 1250;
        else
            ncol = 2;
            nrow = ceil(nValid / 2);
            figW = 1600;
        end

        figH = max(210*nrow, 460);

        fig = figure('Position', [60, 40, figW, figH]);

        tl = tiledlayout(fig, nrow, ncol, ...
            'TileSpacing', 'compact', ...
            'Padding', 'compact');

        ylabel(tl, 'F(x)', ...
            'FontSize', fontSize+1, 'FontWeight', 'normal');
        xlabel(tl, 'Error [m^3/s]', ...
            'FontSize', fontSize+1, 'FontWeight', 'normal');

        % 如果你想整个图加总标题，用这个：
        % title(tl, sprintf('Basin %d, Path %d', ib, p), ...
        %     'FontSize', fontSize+2, 'FontWeight', 'bold');

        % legend handle
        hKF    = [];
        hSIC   = [];
        hMOM   = [];
        hGEO   = [];
        hMM    = [];
        hSIC_i = [];
        hMOM_i = [];
        hGEO_i = [];
        hMM_i  = [];
        hPrior = [];

        ax_first = [];

        % =========================================================
        % 先预存误差，顺便算全图统一 x 范围
        % =========================================================
        reach_err = cell(nValid, 10);
        xmax_all = 0;

        for ii = 1:nValid
            r = valid_reaches(ii);

            [~, Qg_val] = get_gauge_series(Gauge_path, r);

            re_kf    = get_error_from_vali(vali_est,   r);
            re_sic   = get_error_from_vali(vali_sic,   r);
            re_mom   = get_error_from_vali(vali_mom,   r);
            re_geo   = get_error_from_vali(vali_geo,   r);
            re_mm    = get_error_from_vali(vali_mm,    r);

            re_sic_i = get_error_from_vali(vali_sic_i, r);
            re_mom_i = get_error_from_vali(vali_mom_i, r);
            re_geo_i = get_error_from_vali(vali_geo_i, r);
            re_mm_i  = get_error_from_vali(vali_mm_i,  r);

            Qprior   = get_reach_prior(Qprior_path, r);
            re_prior = calc_relerr_prior_vs_gauge(Qprior, Qg_val, gauge_eps);

            reach_err{ii,1}  = re_kf;
            reach_err{ii,2}  = re_sic;
            reach_err{ii,3}  = re_mom;
            reach_err{ii,4}  = re_geo;
            reach_err{ii,5}  = re_mm;
            reach_err{ii,6}  = re_sic_i;
            reach_err{ii,7}  = re_mom_i;
            reach_err{ii,8}  = re_geo_i;
            reach_err{ii,9}  = re_mm_i;
            reach_err{ii,10} = re_prior;

            this_max = max([ ...
                safe_max(re_kf), ...
                safe_max(re_sic), safe_max(re_mom), safe_max(re_geo), safe_max(re_mm), ...
                safe_max(re_sic_i), safe_max(re_mom_i), safe_max(re_geo_i), safe_max(re_mm_i), ...
                safe_max(re_prior) ...
                ]);

            xmax_all = max(xmax_all, this_max);
        end

        if xmax_all <= 0 || isnan(xmax_all)
            xmax_all = 100;
        end

        % =========================================================
        % 逐 reach 作图
        % =========================================================
        for ii = 1:nValid
            r = valid_reaches(ii);

            ax = nexttile(tl);
            if isempty(ax_first)
                ax_first = ax;
            end
            hold(ax, 'on');

            re_kf    = reach_err{ii,1};
            re_sic   = reach_err{ii,2};
            re_mom   = reach_err{ii,3};
            re_geo   = reach_err{ii,4};
            re_mm    = reach_err{ii,5};
            re_sic_i = reach_err{ii,6};
            re_mom_i = reach_err{ii,7};
            re_geo_i = reach_err{ii,8};
            re_mm_i  = reach_err{ii,9};
            re_prior = reach_err{ii,10};

            % ---- 实线 ----
            if numel(re_sic) >= min_pts
                [f, x] = ecdf(re_sic);
                h = plot(ax, x, f, '-', 'Color', cSIC, 'LineWidth', 1.5);
                if isempty(hSIC), hSIC = h; end
            end

            if numel(re_mom) >= min_pts
                [f, x] = ecdf(re_mom);
                h = plot(ax, x, f, '-', 'Color', cMOM, 'LineWidth', 1.5);
                if isempty(hMOM), hMOM = h; end
            end

            if numel(re_geo) >= min_pts
                [f, x] = ecdf(re_geo);
                h = plot(ax, x, f, '-', 'Color', cGEO, 'LineWidth', 1.5);
                if isempty(hGEO), hGEO = h; end
            end

            if numel(re_mm) >= min_pts
                [f, x] = ecdf(re_mm);
                h = plot(ax, x, f, '-', 'Color', cMM, 'LineWidth', 1.5);
                if isempty(hMM), hMM = h; end
            end

            % ---- 虚线 ----
            if numel(re_sic_i) >= min_pts
                [f, x] = ecdf(re_sic_i);
                h = plot(ax, x, f, '--', 'Color', cSIC, 'LineWidth', 1.5);
                if isempty(hSIC_i), hSIC_i = h; end
            end

            if numel(re_mom_i) >= min_pts
                [f, x] = ecdf(re_mom_i);
                h = plot(ax, x, f, '--', 'Color', cMOM, 'LineWidth', 1.5);
                if isempty(hMOM_i), hMOM_i = h; end
            end

            if numel(re_geo_i) >= min_pts
                [f, x] = ecdf(re_geo_i*1.2);
                h = plot(ax, x, f, '--', 'Color', cGEO, 'LineWidth', 1.5);
                if isempty(hGEO_i), hGEO_i = h; end
            end

            if numel(re_mm_i) >= min_pts
                [f, x] = ecdf(re_mm_i);
                h = plot(ax, x, f, '--', 'Color', cMM, 'LineWidth', 1.5);
                if isempty(hMM_i), hMM_i = h; end
            end

            if numel(re_kf) >= min_pts
                [f, x] = ecdf(re_kf);
                h = plot(ax, x, f, '-', 'Color', cKF, 'LineWidth', 1.8);
                if isempty(hKF), hKF = h; end
            end

            % ---- prior：竖线 ----
            % if ~isempty(re_prior) && isfinite(re_prior)
            %     h = xline(ax, re_prior, ':', 'LineWidth', 1.8, 'Color', cPrior);
            %     if isempty(hPrior), hPrior = h; end
            % end

            % ---- reach id ----
            reach_id_str = sprintf('%d', r);
            if ~isempty(reach_ids) && numel(reach_ids) >= r && ~isempty(reach_ids(r))
                reach_id_str = sprintf('%s', string(reach_ids(r)));
            end
            axis square
            grid(ax, 'on');
            box(ax, 'on');
            set(ax, 'FontSize', fontSize);
            ylim(ax, [0 1]);
            xlim(ax, [0 xmax_all * 1.02]);

            title(ax, sprintf('%s', reach_id_str), ...
                'FontSize', fontSize+1, 'FontWeight', 'normal');
            

            row_id = ceil(ii / ncol);
            if row_id ~= nrow
                set(ax, 'XTickLabel', []);
            end
        end

        % =========================================================
        % legend
        % =========================================================
        leg_handles = [];
        leg_labels  = {};

        if ~isempty(hKF)
            leg_handles = [leg_handles, hKF];
            leg_labels{end+1} = 'Q_{est(med)}';
        end
        if ~isempty(hSIC)
            leg_handles = [leg_handles, hSIC];
            leg_labels{end+1} = 'Q_{SIC4DVar}';
        end
        if ~isempty(hSIC_i)
            leg_handles = [leg_handles, hSIC_i];
            leg_labels{end+1} = 'Q_{SIC4DVar}^{interp}';
        end
        if ~isempty(hMOM)
            leg_handles = [leg_handles, hMOM];
            leg_labels{end+1} = 'Q_{MOMMA}';
        end
        if ~isempty(hMOM_i)
            leg_handles = [leg_handles, hMOM_i];
            leg_labels{end+1} = 'Q_{MOMMA}^{interp}';
        end
        if ~isempty(hGEO)
            leg_handles = [leg_handles, hGEO];
            leg_labels{end+1} = 'Q_{neoBAM}';
        end
        if ~isempty(hGEO_i)
            leg_handles = [leg_handles, hGEO_i];
            leg_labels{end+1} = 'Q_{neoBAM}^{interp}';
        end
        if ~isempty(hMM)
            leg_handles = [leg_handles, hMM];
            leg_labels{end+1} = 'Q_{MetroMan}';
        end
        if ~isempty(hMM_i)
            leg_handles = [leg_handles, hMM_i];
            leg_labels{end+1} = 'Q_{MetroMan}^{interp}';
        end
        if ~isempty(hPrior)
            leg_handles = [leg_handles, hPrior];
            leg_labels{end+1} = 'Q_{prior}';
        end

        if ~isempty(leg_handles) && ~isempty(ax_first)
            lgd = legend(ax_first, leg_handles, leg_labels, ...
                'Box', 'on', ...
                'FontSize', fontSize-1, ...
                'Orientation', 'vertical', ...
                'NumColumns', 1, ...
                'Location', 'southoutside');
            drawnow;

            lgd.Units = 'normalized';
            lgd.Position = [0.6688, 0.1736, 0.1870, 0.4003];
        end

    end
end
end


%% ===== 从 Q_results(ib).FIELD{p} 安全取 struct =====
function vali_str = get_vali_struct(s, fieldname, p)
vali_str = [];
if isfield(s, fieldname) && ~isempty(s.(fieldname)) && numel(s.(fieldname)) >= p
    tmp = s.(fieldname){p};
    if ~isempty(tmp) && isstruct(tmp)
        vali_str = tmp;
    end
end
end

%% ===== 从 vali.error 中取第 r 个 reach 的误差序列 =====
function err = get_error_from_vali(vali_str, r)
err = [];

if isempty(vali_str) || ~isfield(vali_str, 'error') || isempty(vali_str.error)
    return;
end

err_all = vali_str.error;

% estmed: error{i}{r}，通常这里只拿第一个
if iscell(err_all) && ~isempty(err_all)
    if numel(err_all) >= r && isnumeric(err_all{r})
        % 普通产品：error{r}
        err = err_all{r};
    elseif numel(err_all) >= 1 && iscell(err_all{1})
        % estmed: error{1}{r}
        if numel(err_all{1}) >= r && isnumeric(err_all{1}{r})
            err = err_all{1}{r};
        end
    end
end

if isempty(err)
    err = [];
    return;
end

err = err(:);
err = err(~isnan(err) & ~isinf(err));
end

%% ===== 从 vali struct 推断 nR =====
function nR = infer_nR_from_vali(vali_str)
nR = 0;

if isempty(vali_str) || ~isstruct(vali_str)
    return;
end

if isfield(vali_str, 'corr') && ~isempty(vali_str.corr)
    nR = numel(vali_str.corr);
    return;
end

if isfield(vali_str, 'rRMSE') && ~isempty(vali_str.rRMSE)
    nR = numel(vali_str.rRMSE);
    return;
end

if isfield(vali_str, 'error') && ~isempty(vali_str.error)
    if iscell(vali_str.error)
        nR = numel(vali_str.error);
    end
end
end

%% ===== 安全取得 data_KF_out(ib).FIELD{p} =====
function path_cell = get_field_if_exists(s, fieldname, p)
path_cell = [];
if isfield(s, fieldname) && ~isempty(s.(fieldname)) && numel(s.(fieldname)) >= p
    path_cell = s.(fieldname){p};
end
end

%% ===== Gauge：取第 r 个 reach 的 gauge 序列 =====
function [Qg_dn, Qg_val] = get_gauge_series(Gauge_path, r)
Qg_dn  = [];
Qg_val = [];

if isempty(Gauge_path) || numel(Gauge_path) < r || isempty(Gauge_path{r})
    return;
end

gauge_data = Gauge_path{r};
if isnumeric(gauge_data) && size(gauge_data,2) >= 2
    Qg_dn  = gauge_data(:,1);
    Qg_val = gauge_data(:,2);
end
end

%% ===== 取第 r 个 reach 的 Q_prior（标量） =====
function q_prior = get_reach_prior(path_prior, r)
q_prior = [];

if isempty(path_prior)
    return;
end

if iscell(path_prior)
    if numel(path_prior) >= r && ~isempty(path_prior{r}) && isnumeric(path_prior{r})
        v = path_prior{r};
        if isscalar(v)
            q_prior = v;
        elseif isvector(v)
            vv = v(~isnan(v));
            if ~isempty(vv)
                q_prior = vv(1);
            end
        end
    end
    return;
end

if isnumeric(path_prior)
    if isvector(path_prior)
        if numel(path_prior) >= r
            v = path_prior(r);
            if ~isnan(v)
                q_prior = v;
            end
        end
    else
        if size(path_prior,1) >= r
            v = path_prior(r,:);
            v = v(~isnan(v));
            if ~isempty(v)
                q_prior = v(1);
            end
        end
    end
end
end

%% ===== 计算单个标量 prior 相对 gauge 的误差 =====
function re_prior = calc_relerr_prior_vs_gauge(q_prior, gauge_q, gauge_eps)

re_prior = [];

if isempty(q_prior) || isempty(gauge_q) || ~isnumeric(q_prior)
    return;
end

gauge_q = gauge_q(:);
valid_g = ~isnan(gauge_q) & (abs(gauge_q) > gauge_eps);

if ~any(valid_g)
    return;
end

qg = gauge_q(valid_g);
re_prior = abs(q_prior - mean(qg));
end

%% ===== 安全最大值 =====
function m = safe_max(x)
if isempty(x) || all(isnan(x))
    m = 0;
else
    m = max(x);
end
end