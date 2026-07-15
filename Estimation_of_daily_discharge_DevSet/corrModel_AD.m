function [ R ] = corrModel_AD( par , dt , dx )
%% Spatial temporal correlation model of river discharge.
% Uses unit response (green function) of diffusive model for a 
% semi-infinite channel (see Brutsaert book)
% Assumes that upstream boundary is a noise with known temporal correlation
% Computes cross correlation between upstream and downstream discharges
% See Papoulis boook (eq. 10-84)
% The diffusive model for 1 D open channel flow: 
%  dQ/dt + c*dQ/dx - D*d2Q/dx2      =    0
%         advection     difusion    
%
%  Rodrigo Paiva, September 2013.
% Input vars:
% par(.) = model parameters [c D talT]
%     c = celerity (m/s)
%     D = diffusivity (m2/s)
%     talT = temporal decorrelation lenthg of the noise term (sec)
% dt(.,.) = time intervals (s)
% dx(.,.) = x distances (m) (only positive dx)
% Output vars:
% R(.,.) = correlation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for i=0:10,c=.5;D=20000;talT=15*24*60*60; [ R ] = corrModel_AD( [c D talT] , ones(31,1)*12*i*60*60 , (0:10000:300000)' );plot((0:10000:300000)',R), hold on,end,hold off
% for i=1:10,c=1;D=50000*i;talT=15*24*60*60; [ R ] = corrModel_AD( [c D talT] , (-30:30)'*24*60*60 , ones(61,1)*200000 );plot((-30:30)',R), hold on,end,hold off


%%
c=par(1);D=par(2);talT=par(3);

[n1,n2]=size(dt);

func=@(v,t,x,c,D,talT) exp(-abs(v)/talT).*x./(4*pi*D*(t-v).^3).^0.5 .* exp (- (x-c*(t-v)).^2 ./ (4*D*(t-v)));

for i1=1:n1
    for i2=1:n2
        
        k=dt(i1,i2);
        h=dx(i1,i2);
        h=max(h,0);
%         dinc=1*60*60; % function of distance
% 
% 
%         tmax=dt(i1,i2)-dinc;
%         tmin=tmax - 365*24*60*60; % Ideally, it should be -Inf.
%         t = (tmin:dinc:tmax)';
%         
%         %% Correlation function of the noise:
%         v = exp(-abs(t)/talT);
%         %% Unit response of difusive model:
%         u = green_AD( c, D , k - t , h );
%         
%         %% Convolution:
%         C(i1,i2) = v'*u * dinc; % Papoulis book eq. 10-84.

        %% Convolution:
       R(i1,i2) = integral(@(v)func(v,k,h,c,D,talT),-Inf,k);%,'RelTol',10^-3);
        %R(i1,i2) = integral(@(v)func(v,k,h,c,D,talT),-Inf,k,'RelTol',10^-3);
    end
end
return