function [ R ] = corrModel_AD_eq( par , dt , dx )
%% Spatial temporal correlation model of river discharge.
% Analitic solution
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

g=@(t,a,b) -exp(-2*a*b)*(erfc( (b-a*t)/sqrt(t) ) + exp(4*a*b)*erfc( (b+a*t)/sqrt(t) ) -2); 
R=zeros(n1,n2);

for i1=1:n1
    for i2=1:n2
        k=dt(i1,i2);
        h=dx(i1,i2);
        h=max(h,0);
        % Coeficients:    
        a=sqrt(c^2/(4*D) + 1/talT);
        al=sqrt(c^2/(4*D) - 1/talT);
        b=h/(2*D^0.5);
        
        if k<=0
            % Negative time lag:
            R(i1,i2) = exp(-abs(k)/talT +0.5*h*c/D -2*a*b);
        else
            % Positive time lag:
            % Check if talT>=4*D/c^2:
            if talT>=4*D/c^2
                r1=exp(-abs(k)/talT-2*al*b);
                r2=0.5*(exp(k/talT)*g(k,a,b)-exp(-k/talT)*g(k,al,b));
                R(i1,i2) = exp(0.5*h*c/D)*(r1+r2);
            end    
            if talT<4*D/c^2 || isnan(R(i1,i2))
                % Use numeric solution:
                R(i1,i2) = corrModel_AD( [c D talT] , k , h );
%                 'Use numeric solution for R. talT<4*D/c^2'
%                 c , D , talT/24/60/60
            end
        end
    end
end
return