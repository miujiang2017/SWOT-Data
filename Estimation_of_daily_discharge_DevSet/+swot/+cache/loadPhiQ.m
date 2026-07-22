function [Phi_save, Q_save] = loadPhiQ(cfg)
%LOADPHIQ Load cached transition and process-noise matrices.

arguments
    cfg (1,1) struct
end

phiPath = fullfile(cfg.paths.devSetDir, cfg.cache.phiFile);
qPath = fullfile(cfg.paths.devSetDir, cfg.cache.qFile);

if ~isfile(phiPath) || ~isfile(qPath)
    if cfg.kf.buildMissingPhiQ
        Phi_save = {};
        Q_save = {};
        return
    end
    error('Missing Phi/Q cache files: %s and/or %s', phiPath, qPath);
end

phiData = load(phiPath, 'Phi_save');
qData = load(qPath, 'Q_save');
Phi_save = phiData.Phi_save;
Q_save = qData.Q_save;
end
