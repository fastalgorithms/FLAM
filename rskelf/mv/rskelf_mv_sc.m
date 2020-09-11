% RSKELF_MV_SC  Dispatch for RSKELF_MV with F.SYMM = 'S' and TRANS = 'C'.

function X = rskelf_mv_sc(F,X)

  % initialize
  n = F.lvp(end);

  % upward sweep
  for i = 1:n
    sk = F.factors(i).sk;
    rd = F.factors(i).rd;
    X(sk,:) = X(sk,:) + conj(F.factors(i).T)*X(rd,:);
    X(rd,:) = F.factors(i).L'*X(rd(F.factors(i).p),:);
    X(rd,:) = X(rd,:) + F.factors(i).E'*X(sk,:);
  end

  % downward sweep
  for i = n:-1:1
    sk = F.factors(i).sk;
    rd = F.factors(i).rd;
    X(sk,:) = X(sk,:) + F.factors(i).F'*X(rd,:);
    X(rd,:) = F.factors(i).U'*X(rd,:);
    X(rd,:) = X(rd,:) + F.factors(i).T'*X(sk,:);
  end
end