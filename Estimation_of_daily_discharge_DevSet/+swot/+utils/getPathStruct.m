function sg_path = getPathStruct(basin, ip)
%GETPATHSTRUCT Extract one path from a basin struct.

arguments
    basin (1,1) struct
    ip (1,1) double {mustBeInteger, mustBePositive}
end

if ~isfield(basin, 'paths') || isempty(basin.paths)
    error('getPathStruct:NoPaths', ...
        'Input basin struct does not contain a non-empty paths field.');
end

nPath = numel(basin.paths);
if ip > nPath
    error('getPathStruct:IndexOutOfRange', ...
        'ip=%d exceeds available path count 1..%d.', ip, nPath);
end

sg_path = struct();
fns = fieldnames(basin);
for k = 1:numel(fns)
    fld = fns{k};
    val = basin.(fld);
    if iscell(val) && numel(val) == nPath
        sg_path.(fld) = val(ip);
    else
        sg_path.(fld) = val;
    end
end
end
