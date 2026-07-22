function idx = resolveIndices(requested, nAvailable)
%RESOLVEINDICES Return requested indices or all indices when requested is empty.

arguments
    requested
    nAvailable (1,1) double {mustBeInteger, mustBeNonnegative}
end

if isempty(requested)
    idx = 1:nAvailable;
else
    idx = requested(:)';
end

idx = idx(idx >= 1 & idx <= nAvailable);
if isempty(idx) && nAvailable > 0
    error('No requested indices are available.');
end
end
