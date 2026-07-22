function [H,z,R,z_idx,comb_tmp,path_id_of_obs] = build_H_obs_SWOT_dA(sg_path, ep, state_ep)
% [H,z,R,z_idx,comb_tmp,path_id_of_obs] = build_H_obs_SWOT_KFout(data_KF_out, ib, ep, state_ep)
%
% data_KF_out : 1×Nb struct array（每个元素一个 basin）
% ib          : basin index
% ep,state_ep : 与原函数一致
%
% basin 内部字段（每个通常是 nPath×1 cell）:
%   rch_len
%   dA_RiverSP
%   dA_unc_RiverSP
%   Q_prior
%
% 输出：
%   H : (#obs_total) × (state_ep * sum(nR_each_path))  (按 path block 拼接)
%   z : #obs_total × 1
%   R : #obs_total × #obs_total (block diagonal)
%   z_idx : 每条观测对应“该 path 内第几个 reach(j)”
%   comb_tmp : 每条观测使用的 (t1,t2) 组合（按原逻辑累积）
%   path_id_of_obs : 每条观测属于第几条 path（1..nPath）

    % ---------- 1) 取出并标准化为 cell 列表（每条 path 一个 cell） ----------
    L     = sg_path.rch_len{:};
    dA    = sg_path.dA_RiverSP{:};
    dAunc = sg_path.dA_unc_RiverSP{:};
    Q     = sg_path.Q_prior{:};

 nR = length(L);
nR_dA = size(dA,1);
H = zeros(1,state_ep*nR);
R = [];
z_idx = [];
% H = zeros(nR_dA,2*nR);
% R = zeros(nR_dA,nR_dA);
z = [];
dt = 86400;
m = 1;
emp = cellfun(@isempty,dA(:,ep+1:ep+state_ep));
idx = [];
comb_tmp = [];
for j = 1:nR_dA
    if sum(emp(j,:))<=state_ep-2
        idx = find(emp(j,:)==0);
        comb = nchoosek(idx,2);
        %             comb = [1,state_ep];
        % %          comb = [1:state_ep-1;2:state_ep]';
        % %         comb = [(1:state_ep-1)',ones(state_ep-1,1)*state_ep];
        comb_tmp = [comb_tmp;comb];
        for i = 1: size(comb,1)
            if j == 1
                
                b = 1/(L(j)+L(j+1));
                c = b;
                H(m,j+nR*(comb(i,1)-1):j+nR*(comb(i,1)-1)+1) = 0.5*[-c, b];
                H(m,j+nR*(comb(i,2)-1):j+nR*(comb(i,2)-1)+1) = 0.5*[-c, b];
                
                
            else if j == nR_dA
                    a = 1/(L(j)+L(j-1));
                    c = -a;
                    H(m,j-1+nR*(comb(i,1)-1):j+nR*(comb(i,1)-1)) = 0.5*[-a, -c];
                    H(m,j-1+nR*(comb(i,2)-1):j+nR*(comb(i,2)-1)) = 0.5*[-a, -c];
                else
                    a = 1/(L(j)+L(j-1));
                    b = 1/(L(j)+L(j+1));
                    c = (L(j-1)-L(j+1))/((L(j)+L(j-1))*(L(j)+L(j+1)));
                    H(m,j-1+nR*(comb(i,1)-1):j+1+nR*(comb(i,1)-1)) = 0.5*[-a, -c, b];
                    H(m,j-1+nR*(comb(i,2)-1):j+1+nR*(comb(i,2)-1)) = 0.5*[-a, -c, b];
                end
            end
            z_idx(m) = j;
            
            %         H = 1/2*H;
            
            z = [z;-(dA{j,ep+comb(i,2)}-dA{j,ep+comb(i,1)})/(dt*diff(comb(i,:)))];
            dt_comb = comb(i,2)-comb(i,1);
            %             R(m,m) = (z_cal{dt_comb}(j,ep+comb(i,1))-z_true{dt_comb}(j,ep+comb(i,1))).^2;
                R(m,m) = (dAunc{j,ep+comb(i,2)}.^2+dAunc{j,ep+comb(i,1)}.^2)/(dt* dt_comb).^2;
            % 
            %                dt_comb = dt{j,ep+comb(i,2)}-dt{j,ep+comb(i,1)};
            % z = [z;-(dA{j,ep+comb(i,2)}-dA{j,ep+comb(i,1)})/(dt_comb)];
            % % 
            % % %             R(m,m) = (z_cal{dt_comb}(j,ep+comb(i,1))-z_true{dt_comb}(j,ep+comb(i,1))).^2;
            %     R(m,m) = (dAunc{j,ep+comb(i,2)}.^2+dAunc{j,ep+comb(i,1)}.^2)/(dt_comb).^2;
                m = m+1;
        end
    end
    %     if i >= 2
    %         H(i-1,i-1:i) = [-1/L(i), 1/L(i)];
    %         H(i-1,i-1+nR:i+nR) = [-1/L(i), 1/L(i)];
    %         z = [z;-(dA(i,ep+2)-dA(i,ep+1))/dt];
    %         R(i-1,i-1) = (dAunc(i,ep+2).^2+dAunc(i,ep+1).^2)/dt^2;
    %     end
    %     H = 1/2*H;
    
    
end

    % z 校正
    if ~isempty(z)
        z = z - H * repmat(Q(:,1), state_ep, 1);
    else
        H = [];
    end

end
