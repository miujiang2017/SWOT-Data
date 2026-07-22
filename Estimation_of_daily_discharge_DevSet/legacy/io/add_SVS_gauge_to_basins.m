function basins = add_SVS_gauge_to_basins(basins)

ncfile = 'SVS_v1_0_1.nc';

time = ncread(ncfile, 'time');
Q = ncread(ncfile, 'Q');
reach_id_v16 = ncread(ncfile, 'reach_id_v16');

time_origin = datenum(2023, 1, 1);
time_datenum = time_origin + double(time(:));

for i = 1:length(basins)

    basins(i).Q_SVS = cell(basins(i).n_paths, 1);

    for p = 1:basins(i).n_paths

        path_reaches = basins(i).paths{p};

        if iscell(path_reaches)
            path_reaches = cellfun(@str2double, path_reaches);
        elseif isstring(path_reaches) || ischar(path_reaches)
            path_reaches = str2double(path_reaches);
        else
            path_reaches = double(path_reaches);
        end

        n_reaches = length(path_reaches);
        basins(i).Q_SVS{p, 1} = cell(n_reaches, 1);

        for r = 1:n_reaches

            reach_id = path_reaches(r);

            idx = find(reach_id_v16 == reach_id);

            if isempty(idx)
                basins(i).Q_SVS{p, 1}{r, 1} = [];
            else
                idx = idx(1);  % 如果一个 reach 对应多个 SVS gauge，先取第一个
                basins(i).Q_SVS{p, 1}{r, 1} = [time_datenum, Q(:, idx)];
            end

        end
    end
end

end