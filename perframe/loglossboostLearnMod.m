function [scores model] = loglossboostLearnMod(data,labels,numIters,initWt)

numEx = size(data,1);
if(nargin<4)
  wt = ones(numEx,1)/numEx;
else
  wt = initWt;
end
model = struct('dim',{},'error',{},'dir',{},'tr',{},'alpha',{});
scores = zeros(numEx,1);

for itt = 1:numIters
  wkRule = findWeakRule(data,labels,wt,itt);
  wkRule.alpha = 1-2*wkRule.error;
  model(itt) = wkRule;
  scores = myBoostClassify(data,model(1:itt));
  tt = scores.*labels;
  wt = initWt./(1+exp(tt));
  wt = wt./sum(wt);
  fprintf('%0.3f ',wkRule.alpha);
  if(mod(itt,15)==0); fprintf(' %d\n',itt); end
end
fprintf('\n');
end

