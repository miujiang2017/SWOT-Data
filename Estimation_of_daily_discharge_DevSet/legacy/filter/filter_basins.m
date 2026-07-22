function basins_out = filter_basins(basins, option)
% FILTER_BASINS 删除无效 path 和空 basin
%
% option = 1:
%   删除没有 gauge 的 path；
%   删除 Q_MOMMA / Q_SIC4DVar / Q_geoBAM / Q_SADS / Q_MetroMan 全空的 path。
%
% option = 2:
%   删除没有 gauge 的 path；
%   删除没有 Q_SVS 的 path。
%
% 用法：
%   basins_out = filter_basins(basins, 1);
%   basins_out = filter_basins(basins, 2);

if nargin < 2
    option = 1;
end

basins_out = basins;

nB = numel(basins_out);

gauge_fields = {'USGS','WSC','MEFCCWP'};

if option == 1
    q_fields = {'Q_MOMMA','Q_SIC4DVar','Q_geoBAM','Q_SADS','Q_MetroMan'};
elseif option == 2
    q_fields = {'Q_SVS'};
else
    error('option must be 1 or 2');
end

keep_basin = true(nB,1);

for ib = 1:nB

    if isfield(basins_out(ib),'paths') && iscell(basins_out(ib).paths)
        n_paths = numel(basins_out(ib).paths);
    else
        n_paths = basins_out(ib).n_paths;
    end

    if isempty(n_paths) || n_paths == 0
        keep_basin(ib) = false;
        continue
    end

    keep_flags = false(n_paths,1);

    for p = 1:n_paths

        % ---------- 条件1：必须有 gauge ----------
        has_any_gauge = false;

        for k = 1:numel(gauge_fields)
            fld = gauge_fields{k};

            if isfield(basins_out(ib), fld) && ...
                    iscell(basins_out(ib).(fld)) && ...
                    numel(basins_out(ib).(fld)) >= p

                g_path = basins_out(ib).(fld){p};

                if ~isempty(g_path)
                    if iscell(g_path)
                        if any(~cellfun('isempty', g_path(:)))
                            has_any_gauge = true;
                            break
                        end
                    else
                        has_any_gauge = true;
                        break
                    end
                end
            end
        end

        if ~has_any_gauge
            continue
        end

        % ---------- 条件2：option 控制 ----------
        has_any_Q = false;

        for k = 1:numel(q_fields)
            fld = q_fields{k};

            if ~isfield(basins_out(ib), fld) || ...
                    ~iscell(basins_out(ib).(fld)) || ...
                    numel(basins_out(ib).(fld)) < p
                continue
            end

            q_path = basins_out(ib).(fld){p};

            if isempty(q_path)
                continue
            end

            if iscell(q_path)
                if any(~cellfun('isempty', q_path(:)))
                    has_any_Q = true;
                    break
                end
            else
                has_any_Q = true;
                break
            end
        end

        if ~has_any_Q
            continue
        end

        keep_flags(p) = true;

    end

    if ~any(keep_flags)
        keep_basin(ib) = false;
        continue
    end

    % ---------- 同步删 path ----------
    flds = fieldnames(basins_out(ib));

    for f = 1:numel(flds)
        fld = flds{f};
        val = basins_out(ib).(fld);

        if iscell(val) && numel(val) == n_paths
            basins_out(ib).(fld) = val(keep_flags);
        end
    end

    if isfield(basins_out(ib),'n_paths') && isnumeric(basins_out(ib).n_paths)
        basins_out(ib).n_paths = sum(keep_flags);
    end

end

basins_out = basins_out(keep_basin);

end