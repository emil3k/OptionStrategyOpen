%% Compute Option Returns
clc;
clear;
close all;

load OptionPricesClean;
load datesUnique;
load SettlementPrice;
load RfDaily;

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
   
   %Grab sorting data necessary for portfolio construction
    IV           = firstDayOptions(:, 7);                     %Grab Implied Volatility
    volume       = firstDayOptions(:, 6);                     %Grab volume from first day
    FirstDayID   = firstDayOptions(:, 8);                     %Grab ID's from first day
    bidPrices    = firstDayOptions(:, 4);                     %Grab cleaned Bid Prices from first day
    strikePrices = firstDayOptions(:, 3) ./1000;              %Grab strikes and divide by 1000 to match index
    expDate      = firstDayOptions(1, 2);                     %Grab expiration date
   
   %Conduct liquidity screening
    highVolume = maxk(volume, nAssets);                       %Identify 15 highest volume options
    optionListVolume = find(ismember(volume, highVolume));    %Get index of highest volume options
    optionIV   = IV(optionListVolume);
   
   %Sort on Implied Volatility
    highIV       = maxk(optionIV, nShorts);                   %Identify 5 highest IV options
    optionListIV = find(ismember(IV, highIV));                %Get index of highest volume options
    optionID     = FirstDayID(optionListIV);                  %Grab option ID of 5 highest IV of the 15 highest volume optio
    bids         = bidPrices(optionListIV);                   %Grab bid prices corresponding to selected options
    netDebit     = sum(bids) .* contractSize;                 %Compute netDebit as sum of bids
    strikes      = strikePrices(optionListIV);                %Grab strike prices for selected options
   
   
   %Calculate monthly account changes
    settlePrice = ones(nShorts, 1) .* SettlementPrice(i);     %Grab settlement price and match dimension
    payoff      = max(0, strikes - settlePrice);              %Compute settlement payoff from sold options
    PL(i)       = sum(payoff) .* contractSize;                                %Compute PL as the sum of settlement payoffs for sold options
   
    startOfMonth = uniqueFirstDayList(i);                     %Grab start of month index
    endOfMonth   = uniqueLastDayList(i);                      %Grab end of month index
   
    MonthLength = endOfMonth - startOfMonth + 1;
    datesUniqueMonthly = datesUnique(startOfMonth:endOfMonth);
    
    monthlyAccount = zeros(MonthLength, 1);
    
   
    for j = 1:MonthLength
        if j == 1
            monthlyAccount(j) = cash(end).*(1 + RfDaily(startOfMonth + j - 1));
        elseif datesUniqueMonthly(j) == day
            monthlyAccount(j) = monthlyAccount(j - 1) .* (1 + RfDaily(startOfMonth + j - 1)) + netDebit;         
        elseif datesUniqueMonthly(j) == expDate       
            monthlyAccount(j) = monthlyAccount(j - 1) .* (1 + RfDaily(startOfMonth + j - 1)) - PL(i);        
        else
            monthlyAccount(j) = monthlyAccount(j - 1) .* (1 + RfDaily(startOfMonth + j - 1));
        end
    end
   
    cash = [cash; monthlyAccount];
   
   
end


%% plot
   
datesUniqueTime = datetime(datesUnique, 'ConvertFrom', 'yyyyMMdd');
semilogy(datesUniqueTime, cash(2:end))