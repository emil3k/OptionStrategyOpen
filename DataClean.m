%% Clean 
clc;
clear;
close all;
load Prices

Prices = Prices(12069:end, :);

SP500   = readtable('SPX_BBG.xlsx');
SP500   = SP500(51:end, :);

Settlement = readtable('SettlementData.xlsx');
SettlementPrice = table2array(Settlement(1:255, 4));

%FFDaily = readtable('F-F_Research_Data_Factors_daily.CSV');



contractSize = 100;


%Extract data we need
Delta  = Prices.DeltaOfTheOption; %Save greeks separately
IV     = Prices.ImpliedVolatilityOfTheOption;    %Save IV separately

%Get dates
dates_time    = datetime(table2array(Prices(:, 1)), 'ConvertFrom', 'yyyyMMdd');
dates         = yyyymmdd(dates_time);
datesNumeric  = datenum(dates_time);

%Get unique dates
datesUnique = unique(dates);

%Get expiration dates
expDates_time    = datetime(table2array(Prices(:, 2)), 'ConvertFrom', 'yyyyMMdd');
expDates         = yyyymmdd(expDates_time);
expDatesNumeric  = datenum(expDates_time);

OptionPrices = [Prices(:, 1:7), Prices(:, end)]; %Save data needed for return computations


%Clean Option Prices
isCloseToMat = ((expDatesNumeric - datesNumeric) <= 8);    %Identify Options close to maturity
OptionPrices = OptionPrices(isCloseToMat, :);              %Keep Option Prices of options that are close to maturity

%AMSettlement = (table2array(OptionPrices(:, end)) == 1);   %Create logical for AM-Settlement
%OptionPrices = OptionPrices(AMSettlement, :);              %Keep Option Prices of AM-settled options


%Get trading dates 
tradingDates = unique(OptionPrices(:,1));                 %Find unique dates where options will be traded
tradingDates = table2array(tradingDates);                 %Convert to array
tradingDatesIndex = find(ismember(datesUnique, tradingDates)); %Compare unique trading dates to unique dates and find index

SP500        = table2array(SP500(:,2));
SP500Trading = SP500(tradingDatesIndex);    %Extract values of S&P 500 on dates when options will be traded
SP500Trading = [tradingDates, SP500Trading];


%% Get OTM Flag 

nTradingDays = size(SP500Trading, 1);          %Number of trading days
OptionPricesArray = table2array(OptionPrices); %Transform Option Prices to array
OTMFlag = 20;                                  %Set OTM vector start value, to be deleted later

for i = 1:nTradingDays
     day = SP500Trading(i, 1); %Grab day
     SP  = SP500Trading(i, 2); %Grab Index Values 
     
     isTradingDay = ismember(OptionPricesArray(:,1), day); %Identify days corresponding to grabbed date
     relevantPrices = OptionPricesArray .* isTradingDay;   %Set irrelevant prices to zero
     relevantPrices(relevantPrices(:,1) == 0, :) = [];     %Delete irrelevant prices
     
     nPrices = size(relevantPrices, 1);                    %Get number of relevant prices
     SPVec   = SP .* ones(nPrices, 1);                     %Create vector of SP Index value
     Strikes = relevantPrices(:, 3) ./ 1000;               %Get strikes of relevant options and divide by 1000 to match index
     
     OTM = (SPVec - Strikes) > 0;                          %Identify OTM options
     OTMFlag = [OTMFlag; OTM];                             %Create OTM indicator vector
     
end

OTMFlag = OTMFlag(2:end); %Delete inital value
isOTM   = (OTMFlag == 1); %Create logical

OptionPricesArray = [OptionPricesArray, OTMFlag]; %Add OTM flag to option prices matrix

%OTMOptionPrices = OptionPricesArray(isOTM, :); %Keep OTM Options


%% Compute Option Returns

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


%% Sort Options on volume on every first trading day
nShorts = 5;
nAssets = 15;
SortedOptions = ones(1, 10);
nMonths = size(FirstDayList, 1);
lag = 1;

%Identify Options to trade
%for i = 1:nMonths 
   day = RolloverDates(1);  %Grab rollover date
   
   isFirstDay     = ismember(OptionPricesArray(:, 1), day);  %Identify days corresponding to rollover date
   firstDayOptions = OptionPricesArray .* isFirstDay;        %Set irrelevant prices to zero
   firstDayOptions(firstDayOptions(:,1) == 0, :) = [];       %Delete irrelevant prices
   
   OTM    = firstDayOptions(:, end);                         %Grab OTM Flag
   OTM    = (OTM == 1);                                      %Create Logical
   firstDayOptions = firstDayOptions(OTM, :);                %Kill ITM Options from portfolio construction
   
   bidPrices = firstDayOptions(:, 4);                        %Grab Bid Prices
   PriceOverMin = (bidPrices > 0.1);                         %Identify Options with high enough bid price to trade
   firstDayOptions = firstDayOptions(PriceOverMin, :);       %Kill options with too low price
   
   IV         = firstDayOptions(:, 7);                       %Grab Implied Volatility
   volume     = firstDayOptions(:, 6);                       %Grab volume from first day
   FirstDayID = firstDayOptions(:, 8);                       %Grab ID's from first day
   bidPrices  = firstDayOptions(:, 4);                       %Grab cleaned Bid Prices from first day
   strikePrices = firstDayOptions(:, 3) ./1000;              %Grab strikes and divide by 1000 to match index
   
   highVolume = maxk(volume, nAssets);                       %Identify 15 highest volume options
   optionListVolume = find(ismember(volume, highVolume));    %Get index of highest volume options
   optionIV   = IV(optionListVolume);
   
   highIV     = maxk(optionIV, nShorts);                     %Identify 5 highest IV options
   optionListIV = find(ismember(IV, highIV));                %Get index of highest volume options
   optionID   = FirstDayID(optionListIV);                    %Grab option ID of 5 highest IV of the 15 highest volume optio
   bids       = bidPrices(optionListIV);
   strikes    = strikePrices(optionListIV);
      
   %Compute settlement payoff
   settlePrice = ones(nShorts, 1) .* SettlementPrice(1);     %Grab settlement price and match dimension
   payoff      = max(0, strikes - settlePrice);              %Compute settlement payoff from sold options
   
   
   
   
   
   
   %Settlement = max(0, SettlePrice - Strike)
   
   
   
   
   
   return
  
   
   %{
   
   %Get Options for each month based on ID 
   start = FirstDayList(1);                                  %Grab first day of month index
   stop  = LastDayList(1);                                   %Grab last day of month index
   
   Options = OptionPricesArray(start:stop, :);               %grab option prices for one month
   ID = Options(:, 8);                                       %Grab option IDs for one month
   
   isRightOption  = ismember(ID, optionID);                  %Identify options based on ID
   relevantPrices = Options .* isRightOption;                %Set irrelevant prices to zero
   relevantPrices(relevantPrices(:,1) == 0, :) = [];         %delete irrelevant prices
   
   bids = relevantPrices(:, 4);
   
   
   return
   %bidPrices = zeros(4, 5);
   fin = size(relevantPrices, 1);
   startIndex = (1: 5 :fin);
   stopIndex  = [startIndex(2:end) - 1, fin];
   bidmat = nan(1, 5);
   
   for i = 1:4
      start = startIndex(i);
      stop  = stopIndex(i);
      
      bidPrices = bids(start:stop)' ;
      bidmat = [bidmat; bidPrices];
      bidmat = [holdingDays, bidmat];
   
   end

   
    %bidmat = bidmat(2:end,:);
    %holdingDays = unique(relevantPrices(:,1));
    %bidmat = [holdingDays, bidmat];

    %nHoldingDays = size(holdingDays, 1);   
   
   
   %SortedOptions = [SortedOptions; relevantPrices];
%end

%SortedOptions = SortedOptions(2:end, :);
%}




return
BidPrices = zeros(nDays, nShorts);
   
   
   
   
   
return     
   
   


nDays = size(datesUnique, 1);
nShorts = 10;
optionXsReturns = zeros(nDays, nShorts);






















return 

Headers = OptionPrices.Properties.VariableNames;


