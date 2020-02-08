%% Compute Option Returns
clc;
clear;
close all;

load OptionPricesClean;
load datesUnique;
load SettlementPrice;
load RfDaily;
load SP500Trading;
load FFDaily
load PutIndex

%identify month changes for Option Prices matrix
DatesTrimmed = round(OptionPricesArray(:, 1)./100);

isFirstDay = zeros(size(OptionPricesArray, 1), 1);
isLastDay  = zeros(size(OptionPricesArray, 1), 1);

for i = 1:size(OptionPricesArray, 1) - 1
    if DatesTrimmed(i) < DatesTrimmed(i + 1)
        isFirstDay(i + 1) = 1;
        isLastDay(i)      = 1;
    end
end

isFirstDay(1) = 1;
isLastDay(end) = 1;

FirstDayList = find(isFirstDay);
LastDayList  = find(isLastDay);

OptionDates = OptionPricesArray(:,1);
RolloverDates  = OptionDates(FirstDayList);

%Identify monthchanges for uniqe dates
[uniqueFirstDayList, uniqueLastDayList] = getFirstAndLastDayInPeriod(datesUnique, 2);




%% Portfolio Construction
nShorts = 5;
nAssets = 15;
nMonths = size(FirstDayList, 1);
lag = 1;
cash = 500000; %set initial margin
PL = zeros(nMonths, 1);
contractSize = 100;
monthlyXsReturns = zeros(nMonths, 1);
firstDayOptionsArray = ones(1, 9);

%Identify Options to trade
for i = 1:nMonths 
    day = RolloverDates(i);  %Grab rollover date, should be lagged!!
    
    %Get option data on first day of new month
    isFirstDay      = ismember(OptionPricesArray(:, 1), day); %Identify days corresponding to rollover date
    firstDayOptions = OptionPricesArray .* isFirstDay;        %Set irrelevant prices to zero
    firstDayOptions(firstDayOptions(:,1) == 0, :) = [];       %Delete irrelevant prices
   
    %Sort on OTM
    OTM    = firstDayOptions(:, end);                         %Grab OTM Flag
    OTM    = (OTM == 1);                                      %Create Logical
    firstDayOptions = firstDayOptions(OTM, :);                %Kill ITM Options from portfolio construction
   
    %Sort on minimum price
    bidPrices = firstDayOptions(:, 4);                        %Grab Bid Prices
    PriceOverMin = (bidPrices > 0.1);                         %Identify Options with high enough bid price to trade
    firstDayOptions = firstDayOptions(PriceOverMin, :);       %Kill options with too low price
   
    firstDayOptionsArray = [firstDayOptionsArray; firstDayOptions];
    
    
    %Grab sorting data necessary for portfolio construction
    IV           = firstDayOptions(:, 7);                     %Grab Implied Volatility
    volume       = firstDayOptions(:, 6);                     %Grab volume from first day
    FirstDayID   = firstDayOptions(:, 8);                     %Grab ID's from first day
    bidPrices    = firstDayOptions(:, 4);                     %Grab cleaned Bid Prices from first day
    strikePrices = firstDayOptions(:, 3) ./1000;              %Grab strikes and divide by 1000 to match index
    expDate      = firstDayOptions(1, 2);                     %Grab expiration date
   
    %{
    %Conduct liquidity screening
    %highVolume = sort(volume, 'descend');                       %Identify 15 highest volume options
    %nShorts = floor(0.25 .* length(highVolume));
    
    %{
    if length(volume) > nShorts
        if highVolume(nShorts) == highVolume(nShorts + 1)
            duplicate = highVolume(nShorts + 1);
            duplicateIndex = find(ismember(volume, duplicate)); 
            volume(duplicateIndex(end)) = [];
        end
    end
     %}
   
    %optionListIndex  = ismember(volume, highVolume(1:nShorts));    %Get index of highest volume options
    %optionListVolume = find(optionListIndex);                      %Get index of highest volume option
    
    %}
    
    %Liquidity Screening
    highVolume = maxk(volume, nShorts);                       %Identify highest volume among options
    optionListVolume = find(ismember(volume, highVolume));    %Get index of highest volume options

    %Sort on Implied Volatility
    %optionIV     = IV(optionListVolume);                      %Grab IV of most liquid options
    %highIV       = maxk(optionIV, nShorts);                   %Identify 5 highest IV options
    %optionListIV = find(ismember(IV, highIV));                %Get index of highest volume options
    %optionID     = FirstDayID(optionListIV);                  %Grab option ID of 5 highest IV of the 15 highest volume optio
    
    bids         = bidPrices(optionListVolume);                %Grab bid prices corresponding to selected options
    strikes      = strikePrices(optionListVolume);             %Grab strike prices for selected options
    
    %Get SP500 on day of portfolio construction
    SPIndex = (SP500Trading(:, 1) == day);
    SP500   = SP500Trading(:, 2);
    SP500   = SP500Trading(SPIndex);
    
    %Calculate margin needed
    MarginVec = bids + max(0.15 .* SP500 - (SP500 - strikes), (0.1 .* strikes)); %Compute margin needed based on formula from Interactive Brokers
    TotalMargin = sum(MarginVec);                                                %Compute total margin for all options sold
    
    %Calculate monthly account changes
    settlePrice = ones(nShorts, 1) .* SettlementPrice(i);                        %Grab settlement price and match dimension
    payoff      = max(zeros(nShorts, 1), strikes - settlePrice);                 %Compute settlement payoff from sold options 
   
    weight      = 1./nShorts;                   %Weight held in each option
    PL(i)       = sum(payoff);                  %For tracking PL at settlement over time (not needed for return calculation)
    weightedMargin = weight * TotalMargin;      %Weighted margin? What do we need this for?
    
    start = find(datesUnique == day);           %Grab start time of sold option
    stop  = find(datesUnique == expDate);       %Grab expiration date index
    RfInvested = prod(1 + RfDaily(start:stop)); %Compute cumulative risk free rate over time when options are sold
    
    returns = (-payoff + bids .* RfInvested + MarginVec .* RfInvested - MarginVec) ./ MarginVec; %Compute returns for given month of shorted options   
    monthlyXsReturns(i) = sum(weight .* returns);   %Save this return in MonthlyXsReturn vector
   
end

%monthlyXsReturns

%% Compound Factor Returns
FactorsDaily      = table2array(FFDaily(:,2:4)) ./100;
FactorsDailyTotal = FactorsDaily +  RfDaily * ones(1, 3);
nFactors = size(FactorsDaily, 2);

PUTDailyTotal = tick2ret(PutIndex);

FactorsMonthlyTotal  = zeros(nMonths, nFactors);
PUTMonthlyTotal      = zeros(nMonths, 1);
RfMonthly            = zeros(nMonths, 1);

for i = 1:nMonths
    start = uniqueFirstDayList(i);
    stop  = uniqueLastDayList(i);
    
    FactorsMonthlyTotal(i, :) = prod(1 + FactorsDailyTotal(start:stop, :)) - 1;
    PUTMonthlyTotal(i, 1) = prod(1 + PUTDailyTotal(start:stop)) - 1;
    RfMonthly(i) = prod(1 + RfDaily(start:stop)) - 1;
end

FactorsMonthly = FactorsMonthlyTotal - RfMonthly;
PUTMonthlyXs   = PUTMonthlyTotal - RfMonthly;

%% Plot Results
%Compute equity lines
MktXsNAV    = cumprod(1 + FactorsMonthly(:, 1));
PUTXsNAV    = cumprod(1 + PUTMonthlyXs);
StrategyNAV = cumprod(1 + monthlyXsReturns);
dates4fig   = datetime(datesUnique(uniqueFirstDayList), 'ConvertFrom', 'yyyyMMdd');

%For legends and titles
load DaysInvested
OptionStrategyLegend = strcat({'-'}, string(DaysInvested), {' Days Before Exp'});

if exist('optionIV', 'var') == 1 
   titleText = {'Sorted on Implied Volatility'};
else
   titleText = {'Sorted on Liquidity'};
end

sharpeArithmetic = sqrt(12) .* mean(monthlyXsReturns) ./ std(monthlyXsReturns);


figure(1)
plot(dates4fig, StrategyNAV, 'k', dates4fig, MktXsNAV, 'b--', dates4fig, PUTXsNAV, 'r--')
title(titleText);
legend( OptionStrategyLegend, 'MktRf', 'Put Index', 'location', 'northwest')
ylim([0.5, max(max([StrategyNAV, MktXsNAV, PUTXsNAV]))]);
ylabel('Cumulative Excess Returns');
yticks(0:0.5:10)
str = strcat({'Sharpe Ratio: '}, string(sharpeArithmetic));
dim = [.65 .2 .3 .0];
annotation('textbox',dim,'String',str,'FitBoxToText','on');







