function setupPaths(cfg)
%SETUPPATHS Add external toolbox/data helper folders used by the pipeline.

arguments
    cfg (1,1) struct
end

addIfFolder(cfg.paths.riverSpDir);
addIfFolder(cfg.paths.swordDir);
addIfFolder(cfg.paths.sosDir);
end

function addIfFolder(folderPath)
if isfolder(folderPath)
    addpath(folderPath);
end
end
