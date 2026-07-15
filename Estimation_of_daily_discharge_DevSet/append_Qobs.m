function [H, zn, R] = append_Qobs(H, zn, R, H_q, z_q, R_q)
% 只在 z_q 非空时，把对应 H_q, z_q, R_q 拼接到 H, zn, R
if ~isempty(z_q)
    size_R  = size(R,1);
    size_Rq = size(R_q,1);
    H  = [H;  H_q];
    zn = [zn; z_q];
    R  = [R, zeros(size_R, size_Rq);
          zeros(size_Rq, size_R), R_q];
end
end
