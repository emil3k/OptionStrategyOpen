%% Clean 
clc;
clear;
close all;
load Prices

Prices1 = Prices1(1:1047533, :); %Delete the overlapping observations
Prices  = [Prices1 ; Prices2];    %Create one table with all data
SP500   = readtable('SPX_BBG.xlsx');

%Extract data we need
Greeks = Prices(:, 9:12); %Save greeks separately
IV     = Prices(:, 8);    %Save IV separately

%Get dates
dates_time    = datetime(table2array(Prices(:, 1)), 'ConvertFrom', 'yyyyMMdd');
dates         = yyyymmdd(dates_time);
datesNumeric  = datenum(dates_time);

%Get unique dates
datesUnique = unique(dates);

%Get expiration dates
expDates_time    =  datetime(table2array(Prices(:, 2)), 'ConvertFrom', 'yyyyMMdd');
expDates         = yyyymmdd(expDates_time);
expDatesNumeric  = datenum(expDates_time);

OptionPrices = [Prices(:, 1:2), Prices(:, 4:7) Prices(:, 12:13)]; %Save data needed for return computations

%Clean Option Prices
isCloseToMat = ((expDatesNumeric - datesNumeric) <= 8);   %Identify Options close to maturity
OptionPrices = OptionPrices(isCloseToMat, :);             %Keep Option Prices of options that are close to maturity

AMSettlement = (table2array(OptionPrices(:, end)) == 1);   %Create logical for AM-Settlement
OptionPrices = OptionPrices(AMSettlement, :);              %Keep Option Prices of AM-settled options

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
isOTM   = (OTMFlag == 1);

OTMOptionPrices = OptionPricesArray(isOTM, :); %Keep OTM Options


%% Compute Option Returns
%identify month changes for OTM Option Prices array
DatesTrimmed = round(OTMOptionPrices(:, 1)./100);

isFirstDay = zeros(size(OTMOptionPrices, 1), 1);
isLastDay  = zeros(size(OTMOptionPrices, 1), 1);

for i = 1:size(OTMOptionPrices, 1) - 1
    if DatesTrimmed(i) < DatesTrimmed(i + 1)
        isFirstDay(i + 1) = 1;
        isLastDay(i)      = 1;
    end
end

isFirstDay(1) = 1;
isLastDay(end) = 1;


FirstDayList = find(isFirstDay);
LastDayList  = find(isLastDay);

OTMOptionDates = OTMOptionPrices(:,1);
RolloverDates  = OTMOptionDates(FirstDayList);




%% Sort Options on volume on every first trading day
nAssets = 5;

%Test without loop
   day = RolloverDates(1);  %Grab rollover date
   
   isFirstDay     = ismember(OTMOptionPrices(:,1), day);     %Identify days corresponding to grabbed date
   relevantPrices = OTMOptionPrices .* isFirstDay;           %Set irrelevant prices to zero
   relevantPrices(relevantPrices(:,1) == 0, :) = [];         %Delete irrelevant prices
   
   volume = relevantPrices(:, 6);
   FirstDayID     = relevantPrices(:, 7);
   
   high = maxk(volume, nAssets);
   optionList = find(ismember(volume, high));
   optionID = FirstDayID(optionList);
   
   start = FirstDayList(1);
   stop  = LastDayList(1);
   
   OptionPrices = OTMOptionPrices(start:stop, :); %grab option prices for one month
   ID = OptionPrices(:, 7);                       %Grab option IDs
   
   isRightOption  = ismember(ID, optionID);                   %Identify options based on ID
   relevantPrices = OptionPrices .* isRightOption;            %Set irrelevant prices to zero
   relevantPrices(relevantPrices(:,1) == 0, :) = [];          %delete irrelevant prices
   
   
   

   
   
   
   
   
   
return     
   
   


nDays = size(datesUnique, 1);
nAssets = 10;
optionXsReturns = zeros(nDays, nAssets);






















return 

Headers = OptionPrices.Properties.VariableNames;


