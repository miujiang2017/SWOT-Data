function sg_path_run = local_slice_sic_daily_cells(sg_path, start_day_idx)

sg_path_run = sg_path;

if ~isfield(sg_path_run, 'Q_SIC4DVar') || isempty(sg_path_run.Q_SIC4DVar) || ...
        isempty(sg_path_run.Q_SIC4DVar{1, 1})
    return
end

daily_cell = sg_path_run.Q_SIC4DVar{1, 1};
if ~iscell(daily_cell) || start_day_idx > size(daily_cell, 2)
    return
end

sg_path_run.Q_SIC4DVar{1, 1} = daily_cell(:, start_day_idx:end);

end
