function [missrate, label, gt] = LRR_MDD(X, s)
% Inputs:
% X: data matrix
% s: groundtruth labels

X(3:3:end-1, :) = []; % retain the last row of ones
lambda = 4;
K = max(s);

%run lrr
Z = solve_lrr(X,lambda);
%post processing
[U,S,V] = svd(Z,'econ');
S = diag(S);
r = sum(S>1e-4*S(1));
U = U(:,1:r);S = S(1:r);
U = U*diag(sqrt(S));
U = normr(U);
L = (U*U').^4;

% JBLD
X(end, :) = [];
features = cell(1, size(X, 2));
for j=1:size(X, 2)
    t = reshape(X(:, j), 2, []);
    v = diff(t,1,2);
    features{j} = v;
end

opt.metric = 'JBLD';
opt.sigma = 10^-4;
opt.H_structure = 'HtH';
opt.H_rows = 10;

HHt  = getHH(features,opt);
D = HHdist(HHt, [], opt);
D = D / max(D(:));
Wj = exp(-D / 1);


L = L .* Wj;

% spectral clustering
D = diag(1./sqrt(sum(L,2)));
L = D*L*D;
[U,S,V] = svd(L);
V = U(:,1:K);
V = D*V;
grps = kmeans(V,K,'emptyaction','singleton','replicates',20,'display','off');
[miss, index] = missclassGroups(grps,s,K);
missrate =  miss/length(grps);
[~, labelIndex] = sort(index);
label = labelIndex(grps)';
gt = s;

end