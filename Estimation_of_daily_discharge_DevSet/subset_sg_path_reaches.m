function sg_path_sub = subset_sg_path_reaches(sg_path, first_reach, last_reach)
% subset_sg_path_reaches
%
% Keep only selected reaches from one sg_path structure.
%
% Usage:
%   sg_path_sub = subset_sg_path_reaches(sg_path, 3, 8);
%   sg_path_sub = subset_sg_path_reaches(sg_path, [3 5 8]);
%
% The function preserves the original field names and only subsets values
% whose reach dimension matches the number of reaches in sg_path.

if nargin < 2
    error('subset_sg_path_reaches:NotEnoughInputs', ...
        'Provide sg_path and either a reach range or a reach index vector.');
end

nR = local_infer_nR(sg_path);

if nargin < 3
    reach_idx = first_reach(:)';
else
    reach_idx = first_reach:last_reach;
end

if isempty(reach_idx) || any(reach_idx < 1) || any(reach_idx > nR) || ...
        any(reach_idx ~= round(reach_idx))
    error('subset_sg_path_reaches:InvalidReachIndex', ...
        'reach index must be integer values within 1..%d.', nR);
end

sg_path_sub = sg_path;
fields = fieldnames(sg_path);

for k = 1:numel(fields)
    fld = fields{k};
    val = sg_path.(fld);
    sg_path_sub.(fld) = local_subset_value(val, reach_idx, nR);
end

end


function nR = local_infer_nR(sg_path)

if isfield(sg_path, 'rch_len') && ~isempty(sg_path.rch_len) && ...
        iscell(sg_path.rch_len) && ~isempty(sg_path.rch_len{1})
    nR = numel(sg_path.rch_len{1});
elseif isfield(sg_path, 'paths') && ~isempty(sg_path.paths) && ...
        iscell(sg_path.paths) && ~isempty(sg_path.paths{1})
    nR = numel(sg_path.paths{1});
else
    error('subset_sg_path_reaches:CannotInferReachCount', ...
        'Cannot infer number of reaches from sg_path.rch_len or sg_path.paths.');
end

end


function val_out = local_subset_value(val, reach_idx, nR)

val_out = val;

if iscell(val)
    if numel(val) == 1
        inner = val{1};
        val_out{1} = local_subset_inner(inner, reach_idx, nR);
    elseif size(val, 1) == nR
        val_out = val(reach_idx, :);
    elseif size(val, 2) == nR
        val_out = val(:, reach_idx);
    end
else
    val_out = local_subset_inner(val, reach_idx, nR);
end

end


function inner_out = local_subset_inner(inner, reach_idx, nR)

inner_out = inner;

if isempty(inner)
    return
end

if iscell(inner)
    if size(inner, 1) == nR
        inner_out = inner(reach_idx, :);
    elseif size(inner, 2) == nR
        inner_out = inner(:, reach_idx);
    elseif isvector(inner) && numel(inner) == nR
        inner_out = inner(reach_idx);
    end
elseif isnumeric(inner) || islogical(inner) || isstring(inner) || iscategorical(inner)
    if size(inner, 1) == nR
        inner_out = inner(reach_idx, :);
    elseif size(inner, 2) == nR
        inner_out = inner(:, reach_idx);
    elseif isvector(inner) && numel(inner) == nR
        inner_out = inner(reach_idx);
    end
end

end
