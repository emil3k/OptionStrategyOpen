function weights = computeSortWeights(sortVariable, nLongs, nShorts, longHighValues)

% Generates porfolio weights based on sortVariable. 
% The function ignores assets for which the sort variable is missing (NaN).
% All such assets get a weight of zero in the portfolio.
% nLongs and nShorts denote the number of assets held long and short. 
% When longHighValues is 1, assets that have the highest values for
% sortVariable are held long and those with the lowest values are held
% short. Otherwise the opposite holds.


[~, sortIndex] = sort(sortVariable);
nAssets = length(sortVariable);
nNonMissings = sum(isfinite(sortVariable));
nLongs = min(nLongs, nNonMissings);
nShorts = min(nShorts, nNonMissings);
weights = zeros(1, nAssets);

% When sorting, elements with NaN are at the end of the array. So we only
% consider the first nNonMissings elements of sortIndex for the portfolio.
if (longHighValues)
    % Remember that the first entries in the index variable correspond to 
    % the lowest values in the original array. So the assets at the beginning
    % of the index variable are held short and those at the end are held long.
    weights(sortIndex(nNonMissings - nLongs + 1 :  nNonMissings)) = 1 / nLongs;
    weights(sortIndex(1 : nShorts)) = -1 / nShorts;
else
    % Here the opposite behavior arises, i.e. assets at the beginning of
    % the index variable long, those at the end short.
    weights(sortIndex(1 : nLongs)) = 1 / nLongs;
    weights(sortIndex(nNonMissings - nShorts + 1 :  nNonMissings)) = -1 / nShorts;
end