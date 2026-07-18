function Qest_med = local_pad_Qest_to_full_time(Qest_med_run, nR, nt, start_day_idx)

Q_full = nan(nR, max(nt - 1, 0));

if isempty(Qest_med_run) || isempty(Qest_med_run{1}) || isempty(Q_full)
    Qest_med = {Q_full};
    return
end

Q_run = Qest_med_run{1};
start_col = max(start_day_idx - 1, 1);
if start_col > size(Q_full, 2)
    Qest_med = {Q_full};
    return
end

n_insert = min(size(Q_run, 2), size(Q_full, 2) - start_col + 1);
if n_insert > 0
    Q_full(:, start_col:start_col+n_insert-1) = Q_run(:, 1:n_insert);
end

Qest_med = {Q_full};

end
