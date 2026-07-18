function start_day_idx = local_first_sic_path_day_idx(sg_path, nR)

start_day_idx = nan;

if ~isfield(sg_path, 'day_index_SIC4DVar') || isempty(sg_path.day_index_SIC4DVar) || ...
        isempty(sg_path.day_index_SIC4DVar{1, 1})
    return
end

day_idx = sg_path.day_index_SIC4DVar{1, 1};

for r = 1:nR
    if numel(day_idx) < r || isempty(day_idx{r})
        continue
    end

    valid_days = day_idx{r}(:);
    valid_days = valid_days(isfinite(valid_days));
    if isempty(valid_days)
        continue
    end

    candidate = min(valid_days);
    if isnan(start_day_idx) || candidate < start_day_idx
        start_day_idx = candidate;
    end
end

end
