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

FFDaily = readtable('FFDaily.xlsx');
FFDaily = FFDaily(19170:24515, :);

PutIndex = readtable('PUT_INDEX_BBG.xlsx');
PutIndex = table2array(PutIndex(50:end, 2));


%% Set parameters and fix Rf
RfDaily = table2array(FFDaily(:, end)) ./100;
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

%Amend expiration dates that are for some reason quoted on saturdays
isSaturday = (day(expDates_time, 'dayofweek') == 7); %Identify when exp dates are saturdays
expDatesAmended = isSaturday .* (expDates - 1) + (1 - isSaturday) .* expDates; %Lag saturday expiries by one day

expDatesNumeric = datenum(datetime(expDatesAmended, 'ConvertFrom', 'yyyyMMdd')); %Create datenum object for amended exp dates

OptionPrices = [Prices(:, 1:7), Prices(:, end)]; %Save data needed for return computations
OptionPricesArray = table2array(OptionPrices);   %Transform Option Prices to array
OptionPricesArray(:, 2) = expDatesAmended;       %Replace exp dates in Option array with amended exp dates


%Clean Option Prices
DaysInvested = 7;
isCloseToMat = ((expDatesNumeric - datesNumeric) <= DaysInvested);    %Identify Options close to maturity
OptionPricesArray = OptionPricesArray(isCloseToMat, :);    %Keep Option Prices of options that are close to maturity

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
OTMFlag = 20;                                  %Set OTM vector start value, to be deleted later

for i = 1:nTradingDays
     day = SP500Trading(i, 1); %Grab day
     SP  = SP500Trading(i, 2); %Grab Index Values 
     
     isTradingDay = ismember(OptionPricesArray(:, 1), day); %Identify days corresponding to grabbed date
     relevantPrices = OptionPricesArray .* isTradingDay;   %Set irrelevant prices to zero
     relevantPrices(relevantPrices(:,1) == 0, :) = [];     %Delete irrelevant prices
     
     nPrices = size(relevantPrices, 1);                    %Get number of relevant prices
     SPVec   = SP .* ones(nPrices, 1);                     %Create vector of SP Index value
     Strikes = relevantPrices(:, 3) ./ 1000;               %Get strikes of relevant options and divide by 1000 to match index
     
     OTM = ((SPVec - Strikes) > 0);                        %Identify OTM options
     OTMFlag = [OTMFlag; OTM];                             %Create OTM indicator vector
     
end

OTMFlag = OTMFlag(2:end); %Delete inital value
isOTM   = (OTMFlag == 1); %Create logical

OptionPricesArray = [OptionPricesArray, OTMFlag]; %Add OTM flag to option prices matrix

%OTMOptionPrices = OptionPricesArray(isOTM, :); %Keep OTM Options

save('OptionPricesClean', 'OptionPricesArray');
save('datesUnique', 'datesUnique'); 
save('SettlementPrice', 'SettlementPrice');
save('RfDaily', 'RfDaily');
save('SP500Trading', 'SP500Trading');
save('DaysInvested', 'DaysInvested');
save('FFDaily', 'FFDaily');
save('PutIndex', 'PutIndex');

return

