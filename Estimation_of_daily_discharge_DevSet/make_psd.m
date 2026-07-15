function R_psd = make_psd(R, eps_diag)
    if nargin<2, eps_diag = 1e-6; end
    R = (R+R')/2;                 % 强制对称
    [V,D] = eig(R);
    D = max(diag(D), eps_diag);   % clip 小/负特征值
    R_psd = V*diag(D)*V';
    R_psd = (R_psd+R_psd')/2;     % 再次对称化
end
