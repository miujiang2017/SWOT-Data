function basins_out = loadBasinsOutCache(cfg)
%LOADBASINSOUTCACHE Load basinsv16_*.mat files into one basins_out array.

arguments
    cfg (1,1) struct
end

basins_out = [];
for i = 1:numel(cfg.cache.basinsOutFiles)
    filePath = fullfile(cfg.paths.devSetDir, cfg.cache.basinsOutFiles{i});
    S = load(filePath);
    vars = fieldnames(S);
    if isempty(vars)
        error('Cache file has no variables: %s', filePath);
    end
    basins_out = [basins_out, S.(vars{1})]; %#ok<AGROW>
end
end
