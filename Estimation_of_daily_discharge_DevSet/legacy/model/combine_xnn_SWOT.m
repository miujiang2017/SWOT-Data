function [Q_tmp,Qest_med] = combine_xnn_SWOT(xnn,Pnn,nR,nt,state_ep,sg_path)
%% Q prior as Q_true
Q_true = sg_path.Q_prior{1, 1}(:,1);

%% Q SWOT as Q_true
% Q_true = weighted_SWOTQ(sg_path, nR);
%% without combine, single epoch
for i = 1:length(xnn)
    Q(:,i) = xnn{i};
end
for i = 1:state_ep   
    if i ==1
        Q_tmp{i}=[Q((i-1)*nR+1:(i-1)*nR+nR,:),reshape(Q(i*nR+1:end,end),nR,state_ep-1)];
    else if i ==  state_ep
            Q_tmp{i}=[reshape(Q(1:end-nR,1),nR,state_ep-1),Q((i-1)*nR+1:(i-1)*nR+nR,:)];
        else
          Q_tmp{i}=[reshape(Q(1:(i-1)*nR,1),nR,i-1),Q((i-1)*nR+1:(i-1)*nR+nR,:),reshape(Q(i*nR+1:end,end),nR,state_ep-i)];
        end
    end
    Q_tmp{i} = Q_tmp{i}+mean(Q_true,2);
end

%% median value
for j = 1:nt-1
    tmp=[];
    for i = 1:state_ep
        
        tmp = [tmp,Q_tmp{1,i}(:,j)];
    end
    Qest_med{1}(:,j) = median(tmp,2);
end
%% weighted and arithmetic mean
% weighted =1, arithmetic = 2
% [Qest_weight,Qest_cov_weight] = build_weighted_arith(xnn,Pnn,nR,nt,state_ep,1);
% Qest_weight{1} = Qest_weight{1}+mean(Q_true,2);
% [Qest_arith,Qest_cov_arith] = build_weighted_arith(xnn,Pnn,nR,nt,state_ep,2);
% Qest_arith{1} = Qest_arith{1}+mean(Q_true,2);




%
