% Source-target evaluations on the unit cube, Laplace kernel.
%
% This example computes the interactions between random source and target points
% on the unit cube via the Laplace kernel. The associated matrix is rectangular
% and real.
%
% This demo does the following in order:
%
%   - compress the matrix
%   - check multiply error/time
%   - check adjoint multiply error/time

function mv_cube1(M,N,occ,p,rank_or_tol,near,store)

  % set default parameters
  if nargin < 1 || isempty(M), M = 16384; end  % number of row points
  if nargin < 2 || isempty(N), N =  8192; end  % number of col points
  if nargin < 3 || isempty(occ), occ = 512; end
  if nargin < 4 || isempty(p), p = 512; end  % number of proxy points
  if nargin < 5 || isempty(rank_or_tol), rank_or_tol = 1e-6; end
  if nargin < 6 || isempty(near), near = 0; end  % no near-field compression
  if nargin < 7 || isempty(store), store = 'n'; end  % no storage

  % initialize
  rx = rand(3,M);  % row points
  cx = rand(3,N);  % col points
  % proxy points are quasi-uniform sampling of scaled 1.5-radius sphere
  proxy = trisphere_subdiv(p,'v'); r = randperm(size(proxy,2));
  proxy = proxy(:,r(1:p));  % reference proxy points are for unit box [-1, 1]^3

  % compress matrix
  Afun = @(i,j)Afun_(i,j,rx,cx);
  pxyfun = @(rc,rx,cx,slf,nbr,l,ctr)pxyfun_(rc,rx,cx,slf,nbr,l,ctr,proxy);
  opts = struct('near',near,'store',store,'verb',1);
  tic; F = ifmm(Afun,rx,cx,occ,rank_or_tol,pxyfun,opts); t = toc;
  w = whos('F'); mem = w.bytes/1e6;
  fprintf('ifmm time/mem: %10.4e (s) / %6.2f (MB)\n',t,mem)

  % test matrix apply accuracy
  X = rand(N,1); X = X/norm(X);
  tic; ifmm_mv(F,X,Afun,'n'); t = toc;  % for timing
  X = rand(N,16); X = X/norm(X);  % test against 16 vectors for robustness
  r = randperm(M); r = r(1:min(M,128));  % check up to 128 rows in result
  Y = ifmm_mv(F,X,Afun,'n');
  Z = Afun(r,1:N)*X;
  err = norm(Z - Y(r,:))/norm(Z);
  fprintf('ifmm_mv:\n')
  fprintf('  multiply err/time: %10.4e / %10.4e (s)\n',err,t)

  % test matrix adjoint apply accuracy
  X = rand(M,1); X = X/norm(X);
  tic; ifmm_mv(F,X,Afun,'c'); t = toc;  % for timing
  X = rand(M,16); X = X/norm(X);  % test against 16 vectors for robustness
  r = randperm(N); r = r(1:min(N,128));  % check up to 128 rows in result
  Y = ifmm_mv(F,X,Afun,'c');
  Z = Afun(1:M,r)'*X;
  err = norm(Z - Y(r,:))/norm(Z);
  fprintf('  adjoint multiply err/time: %10.4e / %10.4e (s)\n',err,t)
end

% kernel function
function K = Kfun(x,y)
  dx = x(1,:)' - y(1,:);
  dy = x(2,:)' - y(2,:);
  dz = x(3,:)' - y(3,:);
  K = 1/(4*pi)./sqrt(dx.^2 + dy.^2 + dz.^2);
end

% matrix entries
function A = Afun_(i,j,rx,cx)
  A = Kfun(rx(:,i),cx(:,j));
end

% proxy function
function [Kpxy,nbr] = pxyfun_(rc,rx,cx,slf,nbr,l,ctr,proxy)
  pxy = proxy.*l + ctr;  % scale and translate reference points
  if rc == 'r'
    Kpxy = Kfun(rx(:,slf),pxy);
    dr = cx(:,nbr) - ctr;
  else
    Kpxy = Kfun(pxy,cx(:,slf));
    dr = rx(:,nbr) - ctr;
  end
  % proxy points form ellipsoid of scaled "radius" 1.5 around current box
  % keep among neighbors only those within ellipsoid
  nbr = nbr(sum((dr./l).^2) < 1.5^2);
end