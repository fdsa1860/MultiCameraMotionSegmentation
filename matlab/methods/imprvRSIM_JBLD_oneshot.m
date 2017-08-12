function [missrate, grp, bestRank,W, index] = imprvRSIM_JBLD_oneshot(X, s, UpperD, LowerD, camID)
% Input: X --  data matrix, s -- groundtruth label, UpperD -- largest rank
% Pan Ji, pan.ji@anu.edu.au

% improved RSIM
if(nargin<4)
    LowerD = 1;
end
if(nargin<3)
    UpperD = 4;
end
K = max(s);

X1 = X(:,camID==1);
X2 = X(:,camID==2);
s1 = s(camID==1);
s2 = s(camID==2);
[e1,~, r1]  = rsim(X1, s1, K, UpperD, LowerD);
[e2,~, r2]  = rsim(X2, s2, K, UpperD, LowerD);
rnk = round((r1+r2)/2);
% rnk = r2;

[~,~,VR1] = svd(X1,'econ'); % take the right singular vector of X
[~,~,VR2] = svd(X2,'econ'); % take the right singular vector of X
V1 = VR1(:,1:rnk); V1 = normr(V1);
V2 = VR2(:,1:rnk); V2 = normr(V2);
n1 = size(V1, 1);
n2 = size(V2, 1);
if n1 > n2
    M = V2' * V1(1:n2, :);
    [Um, Sm, Vm] = svd(M);
    R = Um * Vm';
    V2t = V2 * R;
    W = [V1; V2t] * [V1', V2t'];
%     W = V2t * V2t';
else
    M = V1' * V2(1:n1, :);
    [Um, Sm, Vm] = svd(M);
    R = Um * Vm';
    V1t = V1 * R;
    W = [V1t; V2] * [V1t', V2'];
end
%     W = W / max(W(:));
W = real(W.^3.5);


% JBLD
features = cell(1, size(X, 2));
for j=1:size(X, 2)
    t = reshape(X(:, j), 3, []);
    t(3, :) = [];
    v = diff(t,1,2);
    %         v = diff(v,1,2);
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

% combine W
W = W .* Wj;

% KNN on W12 and W21
kNN = 5;
W1 = Wj(camID==1, camID==2);
for j = 1:size(W1, 1)
    [~,ind] = sort(W1(j,:),'descend');
    W1(j, ind(kNN+1:end)) = 0;
end
W2 = Wj(camID==1, camID==2);
for j = 1:size(W2, 2)
    [~,ind] = sort(W2(:,j),'descend');
    W2(ind(kNN+1:end),j) = 0;
end
W3 = (W1 + W2) / 2;
%     W3 = min(W1, W2);
%     W3 = W3.^30;
W(camID==1, camID==2) = W3;
W(camID==2, camID==1) = W3';

grp = ncutW(W,K); % install your ncutW function

bestRank = rnk;

% s = s2;
ind = (s~=0);
grp = (grp(ind,:));
s = s(ind);

% missrate = ErrorRate(grp, s); % calculate the error rate
[missrate, index] = ErrorRate2(grp, s); % calculate the error rate

end

function [missrate, grp, bestRank, minNcutValue,W]  = rsim(X, s, K, UpperD, LowerD)
if(nargin<4)
    LowerD = 1;
end
if(nargin<3)
    UpperD = 4;
end
% K = max(s);
r = LowerD*K:UpperD*K; % rank from lower bound K to upper bound 4K
[~,~,VR] = svd(X,'econ'); % take the right singular vector of X
clusterLabel = {};
approxBound = [];
Aff = {};
eigenValues = [];

for ii = 1:length(r)
    rnk = r(ii);
    V = VR(:,1:rnk);
    
    V = normr(V); % normalize each row
    
    Z = V*V'; % new shape interaction matrix
    
    W = real(Z.^3.5); % enhance block-diagonal structure;
    %	On hopkins155, average err = 0.79% with powering value gamma = 3.8.
    % You can also try other powering values in [3,4].
    
    Aff{ii} = W;
    [clusterLabel{ii},~,~] = ncutW(W,K); % install your ncutW function
    % from https://www.cis.upenn.edu/~jshi/software/
    
    D = diag(1./sum(W));
    L = D*W;
    eigenValues = eigs(L,K+1);	% you can also easily modify the ncutW function and
    % let it output the eignvalues to save the above three steps
    approxBound(ii) = ComputeNcutValue(W,clusterLabel{ii})/(eigenValues(K)-eigenValues(K+1));
end

[minNcutValue, idx] = min(approxBound);
W = Aff{idx};
grp = clusterLabel{idx};
bestRank = r(idx);
missrate = ErrorRate(grp, s); % calculate the error rate

end