function setupPaths(cfg)
%SETUPPATHS Add external toolbox/data helper folders used by the pipeline.

arguments
    cfg (1,1) struct
end

addIfFolder(cfg.paths.devSetDir);
addWithSubfolders(getLegacyDir(cfg));
addIfFolder(cfg.paths.riverSpDir);
addIfFolder(cfg.paths.swordDir);
addIfFolder(cfg.paths.sosDir);
end

function addIfFolder(folderPath)
if isfolder(folderPath)
    addpath(folderPath);
end
end

function addWithSubfolders(folderPath)
if isfolder(folderPath)
    addpath(genpath(folderPath));
end
end

function legacyDir = getLegacyDir(cfg)
if isfield(cfg.paths, 'legacyDir')
    legacyDir = cfg.paths.legacyDir;
else
    legacyDir = fullfile(cfg.paths.devSetDir, 'legacy');
end
end
