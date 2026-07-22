function plot_reach_metric_barplot(Q_results, data_KF_out)

fontSize = 15;

% ---- 深色 ----
cKF   = [0.0000 0.4470 0.7410];
cSIC  = [0.6350 0.0780 0.1840];
cMOM  = [0.4660 0.6740 0.1880];
cGEO  = [0.4940 0.1840 0.5560];
cMM   = [0.9290 0.6940 0.1250];

% ---- 浅色 ----
cSICi = lighten_color(cSIC,0.7);
cMOMi = lighten_color(cMOM,0.7);
cGEOi = lighten_color(cGEO,0.7);
cMMi  = lighten_color(cMM ,0.7);

for ib =389%:300

    nPath = numel(Q_results(ib).vali_estmed);

    for p =1:nPath

        S_est   = get_vali_struct(Q_results(ib),'vali_estmed',p);
        S_sic   = get_vali_struct(Q_results(ib),'vali_SIC4DVar',p);
        S_sici  = get_vali_struct(Q_results(ib),'vali_SIC4DVar_interp',p);
        S_mom   = get_vali_struct(Q_results(ib),'vali_MOMMA',p);
        S_momi  = get_vali_struct(Q_results(ib),'vali_MOMMA_interp',p);
        S_geo   = get_vali_struct(Q_results(ib),'vali_geoBAM',p);
        S_geoi  = get_vali_struct(Q_results(ib),'vali_geoBAM_interp',p);
        S_mm    = get_vali_struct(Q_results(ib),'vali_MetroMan',p);
        S_mmi   = get_vali_struct(Q_results(ib),'vali_MetroMan_interp',p);

        corr_est  = get_metric_from_struct(S_est,'corr');
        corr_sic  = get_metric_from_struct(S_sic,'corr');
        corr_sici = get_metric_from_struct(S_sici,'corr');
        corr_mom  = get_metric_from_struct(S_mom,'corr');
        corr_momi = get_metric_from_struct(S_momi,'corr');
        corr_geo  = get_metric_from_struct(S_geo,'corr');
        corr_geoi = get_metric_from_struct(S_geoi,'corr');
        corr_mm   = get_metric_from_struct(S_mm,'corr');
        corr_mmi  = get_metric_from_struct(S_mmi,'corr');

        NSE_est  = get_metric_from_struct(S_est,'NSE');
        NSE_sic  = get_metric_from_struct(S_sic,'NSE');
        NSE_sici = get_metric_from_struct(S_sici,'NSE');
        NSE_mom  = get_metric_from_struct(S_mom,'NSE');
        NSE_momi = get_metric_from_struct(S_momi,'NSE');
        NSE_geo  = get_metric_from_struct(S_geo,'NSE');
        NSE_geoi = get_metric_from_struct(S_geoi,'NSE');
        NSE_mm   = get_metric_from_struct(S_mm,'NSE');
        NSE_mmi  = get_metric_from_struct(S_mmi,'NSE');

        rRMSE_est  = get_metric_from_struct(S_est,'rRMSE');
        rRMSE_sic  = get_metric_from_struct(S_sic,'rRMSE');
        rRMSE_sici = get_metric_from_struct(S_sici,'rRMSE');
        rRMSE_mom  = get_metric_from_struct(S_mom,'rRMSE');
        rRMSE_momi = get_metric_from_struct(S_momi,'rRMSE');
        rRMSE_geo  = get_metric_from_struct(S_geo,'rRMSE');
        rRMSE_geoi = get_metric_from_struct(S_geoi,'rRMSE');
        rRMSE_mm   = get_metric_from_struct(S_mm,'rRMSE');
        rRMSE_mmi  = get_metric_from_struct(S_mmi,'rRMSE');

        rB_est  = get_metric_from_struct(S_est,'rB');
        rB_sic  = get_metric_from_struct(S_sic,'rB');
        rB_sici = get_metric_from_struct(S_sici,'rB');
        rB_mom  = get_metric_from_struct(S_mom,'rB');
        rB_momi = get_metric_from_struct(S_momi,'rB');
        rB_geo  = get_metric_from_struct(S_geo,'rB');
        rB_geoi = get_metric_from_struct(S_geoi,'rB');
        rB_mm   = get_metric_from_struct(S_mm,'rB');
        rB_mmi  = get_metric_from_struct(S_mmi,'rB');

        Y_corr_all = [corr_est corr_sic corr_sici corr_mom corr_momi corr_geo corr_geoi corr_mm corr_mmi];
        Y_NSE_all  = [NSE_est  NSE_sic  NSE_sici  NSE_mom  NSE_momi  NSE_geo  NSE_geoi  NSE_mm  NSE_mmi];
        Y_rRMSE_all= [rRMSE_est rRMSE_sic rRMSE_sici rRMSE_mom rRMSE_momi rRMSE_geo rRMSE_geoi rRMSE_mm rRMSE_mmi];
        Y_rB_all   = [rB_est rB_sic rB_sici rB_mom rB_momi rB_geo rB_geoi rB_mm rB_mmi];

        labels_all = {'Q_{est(med)}','Q_{SIC4DVar}', 'Q_{SIC4DVar}^{interp}','Q_{MOMMA}', 'Q_{MOMMA}^{interp}','Q_{neoBAM}', 'Q_{neoBAM}^{interp}', 'Q_{MetroMan}', 'Q_{MetroMan}^{interp}'};
        colors_all = {cKF,cSIC,cSICi,cMOM,cMOMi,cGEO,cGEOi,cMM,cMMi};

        keep = ...
            any(~isnan(Y_corr_all),1) | ...
            any(~isnan(Y_NSE_all),1)  | ...
            any(~isnan(Y_rRMSE_all),1)| ...
            any(~isnan(Y_rB_all),1);

        Y_corr  = Y_corr_all(:,keep);
        Y_NSE   = Y_NSE_all(:,keep);
        Y_rRMSE = Y_rRMSE_all(:,keep);
        Y_rB    = Y_rB_all(:,keep);

        colors_use = colors_all(keep);
        labels_use = labels_all(keep);

        nValid = size(Y_corr,1);
        fig = figure;
        tl = tiledlayout(fig, 2, 2, ...
            'TileSpacing', 'compact', ...
            'Padding', 'compact');


        ax1 = nexttile;
        b1 = bar(Y_corr,'grouped');
        style_bar_series_dynamic(b1,colors_use);
       % grid on
        title(ax1, '(a). Correlation', 'FontSize', fontSize, 'FontWeight', 'normal');
        set(ax1, 'FontSize', fontSize, 'XTick', 1:nValid, 'XTickLabel', []);
        ylabel('[-]', 'FontSize', fontSize, 'FontWeight', 'normal')
        ylim([min(Y_corr,[],"all")-0.1,max(Y_corr,[],"all")+0.1])
        ax2 = nexttile;
        b2 = bar(Y_NSE,'grouped');
        style_bar_series_dynamic(b2,colors_use);
        %grid on
        title(ax2, '(b). NSE', 'FontSize', fontSize, 'FontWeight', 'normal');
        set(ax2, 'FontSize', fontSize, 'XTick', 1:nValid, 'XTickLabel', []);
        ylabel('[-]', 'FontSize', fontSize, 'FontWeight', 'normal')
        ylim([min(Y_NSE,[],"all")-0.1,max(Y_NSE,[],"all")+0.1])
        ax3 = nexttile;
        b3 = bar(Y_rRMSE,'grouped');
        style_bar_series_dynamic(b3,colors_use);
        %grid on
        title(ax3, '(c). rRMSE', 'FontSize', fontSize, 'FontWeight', 'normal');
        set(ax3, 'FontSize', fontSize, 'XTick', 1:nValid, 'XTickLabel', []);
        ylabel('[%]', 'FontSize', fontSize, 'FontWeight', 'normal')
        ylim([min(Y_rRMSE,[],"all")-100,max(Y_rRMSE,[],"all")+100])
        ax4 = nexttile;
        b4 = bar(Y_rB,'grouped');
        style_bar_series_dynamic(b4,colors_use);
        %grid on
        title(ax4, '(d). rBias', 'FontSize', fontSize, 'FontWeight', 'normal');
        set(ax4, 'FontSize', fontSize, 'XTick', 1:nValid, 'XTickLabel', []);
        ylabel('[%]', 'FontSize', fontSize, 'FontWeight', 'normal')
        if nValid==18
            xlim(ax1, [6.5, 7+0.5]); xlim(ax2, [6.5, 7+0.5]); xlim(ax3, [6.5, 7+0.5]); xlim(ax4, [6.5, 7+0.5]);
        else if  nValid==6
                xlim(ax1, [0.5, 1+0.5]); xlim(ax2, [0.5, 1+0.5]); xlim(ax3, [0.5, 1+0.5]); xlim(ax4, [0.5, 1+0.5]);
        else if nValid==15
                xlim(ax1, [5.5, 6+0.5]); xlim(ax2, [5.5, 6+0.5]); xlim(ax3, [5.5, 6+0.5]); xlim(ax4, [5.5, 6+0.5]);
        end
        end
        end
        ylim([min(Y_rB,[],"all")-100,max(Y_rB,[],"all")+100])
        lgd.Units = 'normalized';
        lgd.Position = [0.08 0.955 0.84 0.04];
        lgd = legend(ax1, b1, labels_use, ...
            'Orientation','horizontal', ...
            'Box','on', ...
            'FontSize',fontSize-1);

        lgd.Layout.Tile = 'north';
        drawnow;
        valid = ~( all(isnan([corr_est, corr_sic, corr_mom, corr_geo, corr_mm]), 2) & all(isnan([NSE_est, NSE_sic, NSE_mom, NSE_geo, NSE_mm ]), 2) &  all(isnan([rRMSE_est,rRMSE_sic,rRMSE_mom,rRMSE_geo,rRMSE_mm]), 2) & all(isnan([rB_est, rB_sic, rB_mom, rB_geo, rB_mm ]), 2) );
        if isfield(data_KF_out(ib),'paths') && numel(data_KF_out(ib).paths) >= p && ~isempty(data_KF_out(ib).paths{p})
            reach_ids = data_KF_out(ib).paths{p};
        end
        print_id = reach_ids(valid);
        xlabel(tl, sprintf('%d', print_id(1)),'FontSize', fontSize+1, 'FontWeight', 'normal');
        end

    end
end


function style_bar_series_dynamic(b,colors)

for k = 1:min(numel(b),numel(colors))
    b(k).FaceColor = colors{k};
    b(k).EdgeColor = 'none';
end

end


function S = get_vali_struct(Q_one,fieldname,p)

S = [];

if ~isfield(Q_one,fieldname)
    return
end

C = Q_one.(fieldname);

if isempty(C) || numel(C)<p || isempty(C{1,p})
    return
end

S = C{1,p};

end


function v = get_metric_from_struct(S,name)

v = [];

if isempty(S) || ~isfield(S,name)
    return
end

v = S.(name);

if ~isnumeric(v)
    v = [];
end

v = v(:);

end


function c2 = lighten_color(c1,a)

c2 = c1 + (1-c1)*a;

end

%% =========================================================
function yl = get_ylim_metric(Y, metric_name)

vals = Y(:);
vals = vals(~isnan(vals) & ~isinf(vals));

if isempty(vals)
    switch lower(metric_name)
        case 'corr'
            yl = [-0.5 1];
        case 'nse'
            yl = [-2 1];
        otherwise
            yl = [0 100];
    end
    return;
end

switch lower(metric_name)

    case 'corr'
        lo = min(vals);
        hi = max(vals);
        lo = min(lo, -0.1);
        hi = max(hi, 1.0);
        pad = 0.08 * max(hi-lo, 0.5);
        yl = [lo-pad, hi+pad];

    case 'nse'
        lo = min(vals);
        hi = max(vals);
        hi = max(hi, 1.0);
        pad = 0.10 * max(hi-lo, 1.0);
        yl = [lo-pad, hi+pad];

    case 'rrmse'
        hi = max(vals);
        hi = max(hi, 50);
        yl = [0, hi*1.15];

    case 'rb'
        lo = min(vals);
        hi = max(vals);
        if lo >= 0
            yl = [0, hi*1.15 + eps];
        else
            pad = 0.12 * max(hi-lo, 50);
            yl = [lo-pad, hi+pad];
        end

    otherwise
        lo = min(vals);
        hi = max(vals);
        if lo == hi
            lo = lo - 1;
            hi = hi + 1;
        end
        yl = [lo hi];
end
end