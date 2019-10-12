% Second-kind integral equation on the unit cube, Laplace single-layer.
%
% This is basically the 3D analogue of IE_SQUARE.

function ie_cube(n,occ,p,rank_or_tol,near,store,symm)

  % set default parameters
  if nargin < 1 || isempty(n), n = 32; end  % number of points in each dimension
  if nargin < 2 || isempty(occ), occ = 1024; end
  if nargin < 3 || isempty(p), p = 512; end  % number of proxy points
  if nargin < 4 || isempty(rank_or_tol), rank_or_tol = 1e-6; end
  if nargin < 5 || isempty(near), near = 0; end  % no near-field compression
  if nargin < 6 || isempty(store), store = 'a'; end  % store all interactions
  if nargin < 7 || isempty(symm), symm = 's'; end  % symmetric

  % initialize
  [x1,x2,x3] = ndgrid((1:n)/n); x = [x1(:) x2(:) x3(:)]';  % grid points
  clear x1 x2 x3
  N = size(x,2);
  % proxy points are quasi-uniform sampling of scaled 1.5-radius sphere
  proxy = trisphere_subdiv(p); r = randperm(size(proxy,2));
  proxy = proxy(:,r(1:p));  % reference proxy points are for unit box [-1, 1]^3

  % compute diagonal quadratures
  h = 1/n;
  intgrl = 8*triplequad(@(x,y,z)(1/(4*pi)./sqrt(x.^2 + y.^2 + z.^2)), ...
                        0,h/2,0,h/2,0,h/2);

  % compress matrix
  Afun = @(i,j)Afun_(i,j,x,intgrl);
  pxyfun = @(rc,rx,cx,slf,nbr,l,ctr)pxyfun_(rc,rx,cx,slf,nbr,l,ctr,proxy);
  opts = struct('near',near,'store',store,'symm',symm,'verb',1);
  tic; F = ifmm(Afun,x,x,occ,rank_or_tol,pxyfun,opts); t = toc;
  w = whos('F'); mem = w.bytes/1e6;
  fprintf('ifmm time/mem: %10.4e (s) / %6.2f (MB)\n',t,mem)

  % set up reference FFT multiplication
  a = reshape(Afun(1:N,1),n,n,n);
  B = zeros(2*n-1,2*n-1,2*n-1);  % zero-pad
  B(  1:n  ,  1:n  ,  1:n  ) = a;
  B(  1:n  ,  1:n  ,n+1:end) = a(:,:,2:n);
  B(  1:n  ,n+1:end,  1:n  ) = a(:,2:n,:);
  B(  1:n  ,n+1:end,n+1:end) = a(:,2:n,2:n);
  B(n+1:end,  1:n  ,  1:n  ) = a(2:n,:,:);
  B(n+1:end,  1:n  ,n+1:end) = a(2:n,:,2:n);
  B(n+1:end,n+1:end,  1:n  ) = a(2:n,2:n,:);
  B(n+1:end,n+1:end,n+1:end) = a(2:n,2:n,2:n);
  B(:,:,n+1:end) = flipdim(B(:,:,n+1:end),3);
  B(:,n+1:end,:) = flipdim(B(:,n+1:end,:),2);
  B(n+1:end,:,:) = flipdim(B(n+1:end,:,:),1);
  G = fftn(B);
  mv = @(x)mv_(G,x);

  % test accuracy using randomized power method
  X = rand(N,1);
  X = X/norm(X);

  % NORM(A - F)/NORM(A)
  tic; ifmm_mv(F,X,Afun); t = toc;  % for timing
  err = snorm(N,@(x)(mv(x) - ifmm_mv(F,x,Afun)),[],[],1);
  err = err/snorm(N,mv,[],[],1);
  fprintf('ifmm_mv err/time: %10.4e / %10.4e (s)\n',err,t)

  % run GMRES
  B = mv(X);
  tic; [Y,~,~,iter] = gmres(@(x)ifmm_mv(F,x,Afun),B,[],1e-12,32); t = toc;
  err1 = norm(X - Y)/norm(X);
  err2 = norm(B - mv(Y))/norm(B);
  fprintf('gmres:\n')
  fprintf('  soln/resid err: %10.4e / %10.4e\n',err1,err2)
  fprintf('  iter/time: %d / %10.4e (s)\n',iter(2),t)
end

% kernel function
function K = Kfun(x,y)
  dx = x(1,:)' - y(1,:);
  dy = x(2,:)' - y(2,:);
  dz = x(3,:)' - y(3,:);
  K = -1/(4*pi)*log(sqrt(dx.^2 + dy.^2 + dz.^2));
end

% matrix entries
function A = Afun_(i,j,x,intgrl)
  N = size(x,2);
  A = Kfun(x(:,i),x(:,j))/N;  % area-weighted point interaction
  [I,J] = ndgrid(i,j);
  A(I == J) = 1 + intgrl;  % replace diagonal with identity + precomputed values
end

% proxy function
function [Kpxy,nbr] = pxyfun_(rc,rx,cx,slf,nbr,l,ctr,proxy)
  pxy = proxy*l + ctr';  % scale and translate reference points
  % proxy interaction is kernel evaluation between proxy points and row/column
  % points being compressed, scaled to match the matrix scale
  N = size(rx,2);
  if rc == 'r'
    Kpxy = Kfun(rx(:,slf),pxy)/N;
    dx = cx(1,nbr) - ctr(1);
    dy = cx(2,nbr) - ctr(2);
    dz = cx(3,nbr) - ctr(3);
  else
    Kpxy = Kfun(pxy,cx(:,slf))/N;
    dx = rx(1,nbr) - ctr(1);
    dy = rx(2,nbr) - ctr(2);
    dz = rx(3,nbr) - ctr(3);
  end
  % proxy points form sphere of scaled radius 1.5 around current box
  % keep among neighbors only those within sphere
  dist = sqrt(dx.^2 + dy.^2 + dz.^2);
  nbr = nbr(dist/l < 1.5);
end

% FFT multiplication
function y = mv_(F,x)
  N = length(x);
  n = round(N^(1/3));
  y = ifftn(F.*fftn(reshape(x,n,n,n),[2*n-1 2*n-1 2*n-1]));
  y = reshape(y(1:n,1:n,1:n),N,1);
end