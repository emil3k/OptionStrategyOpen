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

isFirstDay        = zeros(nObs, 1);
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
RolloverDates  = OptionDates(FirstDayList);
ConstructionDates = OptionDates(ConstructionDayList);

%Identify monthchanges for uniqe dates
[uniqueFirstDayList, uniqueLastDayList] = getFirstAndLastDayInPeriod(datesUnique, 2);



%% Portfolio Construction
nShorts = 5;
nAssets = 15;
nMonths = size(FirstDayList, 1);
lag = 1;
PL = zeros(nMonths, 1);
contractSize = 100;
monthlyXsReturns = zeros(nMonths, 1);
SignalDayOptionsArray = ones(1, 9);

%Identify Options to trade
for i = 1:nMonths 
    SignalDay = RolloverDates(i);   %Grab signal day (lagged)
    ConstructionDay = ConstructionDates(i); %Grab construction day (unlagged)
    
    %Get option data on Signal Day 
    isFirstDay      = ismember(OptionPricesArray(:, 1), SignalDay); %Identify days corresponding to signal date
    SignalDayOptions = OptionPricesArray .* isFirstDay;             %Set irrelevant prices to zero
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
    IV           = SignalDayOptions(:, 7);                     %Grab Implied Volatility
    volume       = SignalDayOptions(:, 6);                     %Grab volume from first day
    SignalID     = SignalDayOptions(:, 8);                     %Grab ID's from first day
   % bidPrices    = SignalDayOptions(:, 4);                    %Grab cleaned Bid Prices from first day
   
   
    %Grab ID and prices from construction day
    ConstructionID = ConstructionDayOptions(:, 8);             %Grab option IDs
    bidPrices      = ConstructionDayOptions(:, 4);             %Grab bids
    strikePrices   = ConstructionDayOptions(:, 3) ./1000;      %Grab strikes and divide by 1000 to match index
    expDate        = ConstructionDayOptions(1, 2);             %Grab expiration date
    
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
    highVolume = maxk(volume, nShorts);                        %Identify highest volume among options
    optionListVolume = find(ismember(volume, highVolume));     %Get index of highest volume options
    MostLiquidID  = SignalID(optionListVolume);                %Grab IDs of most liquid options 
    
    optionListID = find(ismember(ConstructionID, MostLiquidID)); %Get the index position of the signal day most liquid option on construction day
    
    %Sort on Implied Volatility
    %{
    %optionIV     = IV(optionListVolume);                      %Grab IV of most liquid options
    %highIV       = maxk(optionIV, nShorts);                   %Identify 5 highest IV options
    %optionListIV = find(ismember(IV, highIV));                %Get index of highest volume options
    %optionID     = FirstDayID(optionListIV);                  %Grab option ID of 5 highest IV of the 15 highest volume optio
    
    %}
   
    bids         = bidPrices(optionListID);                %Grab bid prices corresponding to selected options
    strikes      = strikePrices(optionListID);             %Grab strike prices for selected options
    
    
    %Get SP500 on day of portfolio construction
    SPIndex = (SP500Trading(:, 1) == ConstructionDay);
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
    
    start = find(datesUnique == SignalDay);           %Grab start time of sold option
    stop  = find(datesUnique == expDate);       %Grab expiration date index
    RfInvested = prod(1 + RfDaily(start:stop)); %Compute cumulative risk free rate over time when options are sold
    
    returns = (-payoff + bids .* RfInvested + MarginVec .* RfInvested - MarginVec) ./ (MarginVec); %Compute returns for given month of shorted options   
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

%Compute factor exposure
regTable = table();
regTable.MktRf = FactorsMonthly(:,1);
regTable.SMB   = FactorsMonthly(:,2);
regTable.HML   = FactorsMonthly(:,3);
regTable.Strategy = monthlyXsReturns;


regression = fitlm(regTable, 'Strategy ~ MktRf') % + SMB + HML')


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

%Plots
figure(1)
plot(dates4fig, StrategyNAV, 'k', dates4fig, MktXsNAV, 'b--', dates4fig, PUTXsNAV, 'r--')
title(titleText);
legend( OptionStrategyLegend, 'Mkt_Rf', 'Put Index', 'location', 'northwest')
ylim([0.5, max(max([StrategyNAV, MktXsNAV, PUTXsNAV]))]);
ylabel('Cumulative Excess Returns');
yticks(0:0.5:10)
str = strcat({'Sharpe Ratio: '}, string(sharpeArithmetic));
dim = [.65 .2 .3 .0];
annotation('textbox',dim,'String',str,'FitBoxToText','on');







