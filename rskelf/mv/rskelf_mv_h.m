% RSKELF_MV_H  Dispatch for RSKELF_MV with F.SYMM = 'H'.

function X = rskelf_mv_h(F,X)

  % initialize
  n = F.lvp(end);

  % upward sweep
  for i = 1:n
    sk = F.factors(i).sk;
    rd = F.factors(i).rd;
    X(sk,:) = X(sk,:) + F.factors(i).T*X(rd,:);
    X(rd,:) = F.factors(i).L'*X(rd,:);
    X(rd,:) = X(rd,:) + F.factors(i).E'*X(sk,:);
    X(rd,:) = F.factors(i).U*X(rd,:);
  end

  % downward sweep
  for i = n:-1:1
    sk = F.factors(i).sk;
    rd = F.factors(i).rd;
    X(sk,:) = X(sk,:) + F.factors(i).E*X(rd,:);
    X(rd,:) = F.factors(i).L*X(rd,:);
    X(rd,:) = X(rd,:) + F.factors(i).T'*X(sk,:);
  end
end