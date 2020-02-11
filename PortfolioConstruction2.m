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

%Find Signal and Construction Dates
dates_time = datetime(OptionPricesArray(:, 1), 'ConvertFrom', 'yyyyMMdd');
dateVec    = datevec(dates_time);
monthVec   = dateVec(:, 2);
dayVec     = dateVec(:, 3);
nObs       = size(OptionPricesArray, 1);

isSignalDay        = zeros(nObs, 1);
isLastDay         = zeros(nObs, 1);
isConstructionDay = zeros(nObs, 1);
monthVec = [0; monthVec];

%Get Construction dates takes into account that signal dates may be
%weekedn

for i = 1:nObs - 1
    if monthVec(i) ~= monthVec(i + 1)         %Check for month changes
        days = dayVec(i + 1 : i + 500, 1);    %Grab arbitrary numbers of dates moving forward
        isDayChange = zeros(length(days), 1); %Preallocate
        
        for j = 1:length(days) - 1            %New loop looking at day changes
            if days(j) ~= days(j + 1)          
                isDayChange(j + 1) = 1;
            end
        end
        
        dayList = find(isDayChange);          %Find index for day changes
        construction = dayList(1);            %Grab index of first day changes
        
        isConstructionDay(construction + i) = 1; %Save construction dates
        
    end
end

OptionDates = OptionPricesArray(:, 1); %grab option dates
[FirstDayList, LastDayList] = getFirstAndLastDayInPeriod(OptionDates, 2);

ConstructionDayList = find(isConstructionDay);
SignalDates  = OptionDates(FirstDayList);
ConstructionDates = OptionDates(ConstructionDayList);

%Identify monthchanges for uniqe dates
[uniqueFirstDayList, uniqueLastDayList] = getFirstAndLastDayInPeriod(datesUnique, 2);



%% Portfolio Construction
%nShorts = 5;
nShortsIV = 5;
nAssets = 15;
nMonths = size(FirstDayList, 1);
lag = 1;
PL = zeros(nMonths, 1);
contractSize = 100;
monthlyXsReturns = zeros(nMonths, 1);
SignalDayOptionsArray = ones(1, 9);
nOptions = zeros(nMonths, 1);
IVSort = 0;

%Identify Options to trade
for i = 1:nMonths 
    SignalDay = SignalDates(i);   %Grab signal day (lagged)
    ConstructionDay = ConstructionDates(i); %Grab construction day (unlagged)
    
    %Get option data on Signal Day 
    isSignalDay      = ismember(OptionPricesArray(:, 1), SignalDay); %Identify days corresponding to signal date
    SignalDayOptions = OptionPricesArray .* isSignalDay;             %Set irrelevant prices to zero
    SignalDayOptions(SignalDayOptions(:,1) == 0, :) = [];            %Delete irrelevant prices
   
    %Get option data on construction day
    isConstructionDay      = ismember(OptionPricesArray(:, 1), ConstructionDay); %Identify days corresponding to signal date
    ConstructionDayOptions = OptionPricesArray .* isConstructionDay;             %Set irrelevant prices to zero
    ConstructionDayOptions(ConstructionDayOptions(:,1) == 0, :) = [];            %Delete irrelevant prices
    
    %Sort on OTM
    OTM    = SignalDayOptions(:, end);                               %Grab OTM Flag
    OTM    = (OTM == 1);                                             %Create Logical
    SignalDayOptions = SignalDayOptions(OTM, :);                     %Kill ITM and ATM Options from portfolio construction
   
    %Delete options with too low price
    bidPrices = SignalDayOptions(:, 4);                         %Grab Bid Prices
    PriceOverMin = (bidPrices > 0.1);                           %Identify Options with high enough bid price to trade
    SignalDayOptions = SignalDayOptions(PriceOverMin, :);       %Kill options with too low price
   
    %Store all signal day options for check
    SignalDayOptionsArray = [SignalDayOptionsArray; SignalDayOptions];
    
    
    %Grab sorting data necessary for signal
    SignalIV           = SignalDayOptions(:, 7);               %Grab Implied Volatility
    SignalVolume       = SignalDayOptions(:, 6);               %Grab volume from first day
    SignalID           = SignalDayOptions(:, 8);               %Grab ID's from first day
   
    %Grab ID and prices from construction day
    ConstructionID = ConstructionDayOptions(:, 8);             %Grab option IDs
    bidPrices      = ConstructionDayOptions(:, 4);             %Grab bids
    strikePrices   = ConstructionDayOptions(:, 3) ./1000;      %Grab strikes and divide by 1000 to match index
    expDate        = ConstructionDayOptions(1, 2);             %Grab expiration date
    
    %Dynamic Liquidity Screening
    %Conduct liquidity screening 
    highVolume = sort(SignalVolume, 'descend');
    if length(highVolume) <= 5
        nShortsVolume = length(highVolume);
    else
        nShortsVolume = floor(0.25 .* length(highVolume));
    end
    
    %Remove duplicates at end point
    if length(SignalVolume) > nShortsVolume
        if highVolume(nShortsVolume) == highVolume(nShortsVolume + 1)
            duplicate = highVolume(nShortsVolume + 1);
            duplicateIndex = find(ismember(SignalVolume, duplicate)); 
            SignalVolume(duplicateIndex(end)) = [];
        end
    end
    
    optionListVolume = find(ismember(SignalVolume, highVolume(1:nShortsVolume))); %Get index of highest volume option
    
    %Static Liquidity Screening 
    %{
    highVolume = maxk(volume, nShorts);                        %Identify highest volume among options
    optionListVolume = find(ismember(volume, highVolume));     %Get index of highest volume options
    %}
    
    MostLiquidID  = SignalID(optionListVolume);                %Grab IDs of most liquid options 
    %Get the index position of the signal day most liquid option on construction day
    
    %Sort on Implied Volatility
    nShortsIV    = min(nShortsVolume, 5);                     %Make sure we do not exceed 5 options in each period
    MostLiquidIV = SignalIV(optionListVolume);                %Grab IV of most liquid options
    highIV       = maxk(MostLiquidIV, nShortsIV);             %Identify highest IV options
    optionListIV = find(ismember(SignalIV, highIV));          %Get index of highest volume options
    highIVID     = SignalID(optionListIV);                    %Grab option ID of 5 highest IV of the 15 highest volume optio
    
    if IVSort == 1   
        optionListID = find(ismember(ConstructionID, highIVID));
    else
        optionListID = find(ismember(ConstructionID, MostLiquidID));
    end
        
    bids         = bidPrices(optionListID);                %Grab bid prices corresponding to selected options
    strikes      = strikePrices(optionListID);             %Grab strike prices for selected options
    
    %Get SP500 on day of portfolio construction
    SPIndex = (SP500Trading(:, 1) == ConstructionDay);
    SP500   = SP500Trading(:, 2);
    SP500   = SP500(SPIndex);
    
    %Calculate margin needed
    MarginVec = bids + max(0.15 .* SP500 - (SP500 - strikes), (0.1 .* strikes)); %Compute margin needed based on formula from Interactive Brokers
    TotalMargin = sum(MarginVec);                                                %Compute total margin for all options sold
    
    %Calculate monthly account changes
    %Check if sorting on IV or liquidity to determine matrix dim
    if IVSort == 1
        nShorts = nShortsIV;
    else
        nShorts = nShortsVolume;
    end
    
    settlePrice = ones(nShorts, 1) .* SettlementPrice(i);                       %Grab settlement price and match dimension
    payoff      = max(zeros(nShorts, 1), strikes - settlePrice);                %Compute settlement payoff from sold options 
   
    weight      = 1./nShorts;                   %Weight held in each option
    PL(i)       = sum(payoff);                  %For tracking PL at settlement over time (not needed for return calculation)
    nOptions(i, 1) = nShorts;
    
    start = find(datesUnique == SignalDay);      %Grab start time of sold option
    stop  = find(datesUnique == expDate);        %Grab expiration date index
    RfInvested = prod(1 + RfDaily(start:stop));  %Compute cumulative risk free rate over time when options are sold
    
    
    %returns = (-payoff + bids .* RfInvested + MarginVec .* RfInvested - MarginVec) ./ (MarginVec); %Compute returns for given month of shorted options   
    returns = ((-payoff + bids) ./ bids) .* 0.01;
    monthlyXsReturns(i) = nansum(weight .* returns);   %Save this return in MonthlyXsReturn vector
   
    
    
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

%Compute factor exposure
regTable = table();
regTable.MktRf = FactorsMonthly(:,1);
regTable.SMB   = FactorsMonthly(:,2);
regTable.HML   = FactorsMonthly(:,3);
regTable.Strategy = monthlyXsReturns;


regression = fitlm(regTable, 'Strategy ~ MktRf + SMB + HML')

%% Drawdowns
worst = min(monthlyXsReturns);
best  = max(monthlyXsReturns);



%% Plot Results
%Compute equity lines
MktXsNAV    = cumprod(1 + FactorsMonthly(:, 1));
PUTXsNAV    = cumprod(1 + PUTMonthlyXs);
StrategyNAV = cumprod(1 + monthlyXsReturns);
dates4fig   = datetime(datesUnique(uniqueFirstDayList), 'ConvertFrom', 'yyyyMMdd');

%For legends and titles
load DaysInvested
OptionStrategyLegend = strcat({'-'}, string(DaysInvested), {' Days Before Exp'});

if IVSort == 1 
   titleText = {'Sorted on Implied Volatility'};
else
   titleText = {'Sorted on Liquidity'};
end

sharpeArithmetic = sqrt(12) .* mean(monthlyXsReturns) ./ std(monthlyXsReturns);

%Plots
figure(1)
plot(dates4fig, StrategyNAV, 'k', dates4fig, MktXsNAV, 'b--', dates4fig, PUTXsNAV, 'r--')
title(titleText);
legend( OptionStrategyLegend, 'MktRf', 'Put Index', 'location', 'northwest')
%ylim([0.5, max(max([StrategyNAV, MktXsNAV, PUTXsNAV]))]);
ylabel('Cumulative Excess Returns');
%yticks(0:0.5:max(StrategyNAV))
str = strcat({'Sharpe Ratio: '}, string(sharpeArithmetic));
dim = [.65 .2 .3 .0];
annotation('textbox',dim,'String',str,'FitBoxToText','on');







