function aggregate_sic22_chunk_details(pattern, tag)
%AGGREGATE_SIC22_CHUNK_DETAILS Merge chunked SIC22 detail outputs.

if nargin < 1 || isempty(pattern)
    pattern = 'sic22_compare_rts_fullchunk_*.mat';
end
if nargin < 2 || isempty(tag)
    tag = 'rts_full_merged';
end

files = dir(pattern);
if isempty(files)
    error('No chunk detail files matched pattern: %s', pattern);
end

all_kf = init_metric_arrays_local();
all_interp = init_metric_arrays_local();
for i = 1:numel(files)
    S = load(files(i).name, 'detail');
    if ~isfield(S, 'detail') || ~isfield(S.detail, 'kf') || ~isfield(S.detail, 'interp')
        error('File lacks detail.kf/detail.interp: %s', files(i).name);
    end
    all_kf = concat_metric_arrays_local(all_kf, S.detail.kf);
    all_interp = concat_metric_arrays_local(all_interp, S.detail.interp);
end

stats = struct();
stats.Name = string(tag);
[kf, interp, n_common] = paired_summary_local(all_kf, all_interp);
stats.N_common = n_common;
stats.corr_kf = kf.corr;
stats.corr_interp = interp.corr;
stats.NSE_kf = kf.NSE;
stats.NSE_interp = interp.NSE;
stats.rRMSE_kf = kf.rRMSE;
stats.rRMSE_interp = interp.rRMSE;
stats.rB_kf = kf.rB;
stats.rB_interp = interp.rB;

summary_table = build_comparison_summary_local(all_kf, all_interp, "all");
group_summary_table = build_group_comparison_summary_local(all_kf, all_interp);

stamp = datestr(now, 'yyyymmdd_HHMMSS');
base = sprintf('sic22_compare_%s_%s', regexprep(tag, '[^A-Za-z0-9_]+', '_'), stamp);
save([base '.mat'], 'all_kf', 'all_interp', 'stats', 'summary_table', 'group_summary_table', 'files', '-v7.3');
writetable(summary_table, [base '_summary.csv']);
writetable(group_summary_table, [base '_group_summary.csv']);
plot_sic22_cdf_local(all_kf, all_interp, stats);
savefig(gcf, [base '_cdf.fig']);
exportgraphics(gcf, [base '_cdf.png'], 'Resolution', 220);

fprintf('Merged %d chunk files.\n', numel(files));
fprintf('Saved merged outputs:\n');
fprintf('  %s\n', [base '.mat']);
fprintf('  %s\n', [base '_cdf.png']);
fprintf('  %s\n', [base '_cdf.fig']);
fprintf('  %s\n', [base '_summary.csv']);
fprintf('  %s\n', [base '_group_summary.csv']);
disp(struct2table(stats, 'AsArray', true));
end

function all = init_metric_arrays_local()
all.corr = [];
all.NSE = [];
all.rRMSE = [];
all.rB = [];
all.qprior = [];
all.qgroup = [];
all.task = [];
all.ib = [];
all.ip = [];
all.reach = [];
end

function out = concat_metric_arrays_local(out, in)
fields = fieldnames(out);
for i = 1:numel(fields)
    fld = fields{i};
    if isfield(in, fld)
        out.(fld) = [out.(fld); in.(fld)(:)];
    end
end
end

function [kf, interp, n_common] = paired_summary_local(all_kf, all_interp)
[kf.corr, interp.corr, n_common.corr] = paired_metric_local(all_kf.corr, all_interp.corr);
[kf.NSE, interp.NSE, n_common.NSE] = paired_metric_local(all_kf.NSE, all_interp.NSE);
[kf.rRMSE, interp.rRMSE, n_common.rRMSE] = paired_metric_local(all_kf.rRMSE, all_interp.rRMSE);
[kf.rB, interp.rB, n_common.rB] = paired_metric_local(all_kf.rB, all_interp.rB);
n_common = min([n_common.corr, n_common.NSE, n_common.rRMSE, n_common.rB]);
end

function [ma, mb, n] = paired_metric_local(a, b)
n0 = min(numel(a), numel(b));
a = a(1:n0);
b = b(1:n0);
mask = isfinite(a) & isfinite(b);
ma = median(a(mask), 'omitnan');
mb = median(b(mask), 'omitnan');
n = nnz(mask);
end

function T = build_comparison_summary_local(kf, interp, group_name)
metrics = {'corr', 'NSE', 'rRMSE', 'rB'};
rows = cell(numel(metrics), 13);
for i = 1:numel(metrics)
    m = metrics{i};
    [a, b] = paired_vectors_local(kf.(m), interp.(m));
    if strcmp(m, 'rRMSE') || strcmp(m, 'rB')
        wins = a < b;
    else
        wins = a > b;
    end
    rows(i, :) = {char(group_name), m, numel(a), median(a, 'omitnan'), median(b, 'omitnan'), ...
        median(a, 'omitnan') - median(b, 'omitnan'), mean(a, 'omitnan'), mean(b, 'omitnan'), ...
        prctile(a, 25), prctile(a, 75), prctile(b, 25), prctile(b, 75), mean(wins, 'omitnan')};
end
T = cell2table(rows, 'VariableNames', {'group','metric','N','kf_median','interp_median', ...
    'delta_median','kf_mean','interp_mean','kf_p25','kf_p75','interp_p25','interp_p75','win_rate'});
end

function T = build_group_comparison_summary_local(kf, interp)
names = {'low', 'mid', 'high'};
tables = cell(1, numel(names));
for ig = 1:3
    n = min(numel(kf.qgroup), numel(interp.qgroup));
    mask = kf.qgroup(1:n) == ig & interp.qgroup(1:n) == ig;
    kfg = mask_metric_arrays_local(kf, mask);
    intg = mask_metric_arrays_local(interp, mask);
    tables{ig} = build_comparison_summary_local(kfg, intg, string(names{ig}));
end
T = vertcat(tables{:});
end

function out = mask_metric_arrays_local(in, mask)
out = init_metric_arrays_local();
fields = {'corr', 'NSE', 'rRMSE', 'rB', 'qprior', 'qgroup', 'task', 'ib', 'ip', 'reach'};
for i = 1:numel(fields)
    fld = fields{i};
    if isfield(in, fld)
        vals = in.(fld);
        n = min(numel(mask), numel(vals));
        out.(fld) = vals(1:n);
        out.(fld) = out.(fld)(mask(1:n));
    end
end
end

function [a, b] = paired_vectors_local(a, b)
n = min(numel(a), numel(b));
a = a(1:n);
b = b(1:n);
mask = isfinite(a) & isfinite(b);
a = a(mask);
b = b(mask);
end

function plot_sic22_cdf_local(kf, interp, stats)
figure('Color', 'w', 'Position', [100, 100, 1500, 950]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
plot_one_cdf_local(kf.corr, interp.corr, 'Correlation', '[-]', false);
plot_one_cdf_local(kf.NSE, interp.NSE, 'NSE', '[-]', false);
plot_one_cdf_local(kf.rRMSE, interp.rRMSE, 'rRMSE', '[%]', true);
plot_one_cdf_local(kf.rB, interp.rB, 'rBias', '[%]', true);
sgtitle(sprintf('%s vs interpolated SIC4DVar, N=%d', string(stats.Name), stats.N_common), ...
    'Interpreter', 'none');
end

function plot_one_cdf_local(kf_vals, interp_vals, ttl, xlab, lower_is_better)
[kf_vals, interp_vals] = paired_vectors_local(kf_vals, interp_vals);
if isempty(kf_vals)
    return;
end
nexttile;
[x1, y1] = ecdf_xy_local(interp_vals);
[x2, y2] = ecdf_xy_local(kf_vals);
plot(x1, y1, '--', 'Color', [0.65 0.1 0.15], 'LineWidth', 2); hold on;
plot(x2, y2, '-', 'Color', [0 0.3 0.7], 'LineWidth', 2);
grid on;
title(ttl);
xlabel(xlab);
ylabel('F(x)');
legend(sprintf('SIC interp median %.4g', median(interp_vals, 'omitnan')), ...
    sprintf('SIC22 RTS median %.4g', median(kf_vals, 'omitnan')), 'Location', 'best');
if lower_is_better
    xlim([max(0, prctile([kf_vals; interp_vals], 1) - 5), prctile([kf_vals; interp_vals], 99) + 5]);
else
    xlim([max(-2, prctile([kf_vals; interp_vals], 1) - 0.05), min(1, prctile([kf_vals; interp_vals], 99) + 0.05)]);
end
end

function [x, y] = ecdf_xy_local(vals)
vals = sort(vals(isfinite(vals)));
n = numel(vals);
x = vals(:);
y = (1:n)' ./ n;
end
