function tf = hasBasinsOutCache(cfg)
%HASBASINSOUTCACHE True when every configured basin cache file exists.

arguments
    cfg (1,1) struct
end

tf = true;
for i = 1:numel(cfg.cache.basinsOutFiles)
    tf = tf && isfile(fullfile(cfg.paths.devSetDir, cfg.cache.basinsOutFiles{i}));
end
end
