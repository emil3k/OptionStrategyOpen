%This function obtains an OTM flag for Option data
%Option Strikes should be a matrix containing dates and strike prices
%Underlying should be a matrix containing price of underlying and
%corresponding dates
%If data is not synced, function will sync data by selecting underlying
%price from dates corresponding to option strikes dates
%CallPut toggle to separate between call and put, Call = 1, Put = 0

function [ITMCheck, OTMCheck, ATMCheck] = MoneynessFlag(OptionStrikes, OptionStrikeDates, Underlying, UnderlyingDates, CallPutToggle)

tradingDates = unique(OptionStrikeDates);                          %Find unique dates where options will be traded
tradingDatesIndex = find(ismember(UnderlyingDates, tradingDates)); %Compare unique trading dates to dates of underlying and find index

UnderlyingTrading = Underlying(tradingDatesIndex);     %Extract values of underlying on dates when options will be traded
UnderlyingTrading = [tradingDates, UnderlyingTrading]; %Sync underlying to trading dates and create new matrix

% Get OTM Flag 
nTradingDays = size(UnderlyingTrading, 1);             %Number of trading days
OptionPricesArray = table2array(OptionPrices);         %Transform Option Prices to array

OTMFlag = 20;                                          %Set OTM vector start value, to be deleted later
ITMFlag = 20;
ATMFlag = 20;

for i = 1:nTradingDays
     day    = UnderlyingTrading(i, 1); %Grab day
     Asset  = UnderlyingTrading(i, 2); %Grab Underlying Values 
     
     isTradingDay = ismember(OptionStrikeDates, day);      %Identify days corresponding to grabbed date
     relevantStrikes = OptionStrikes .* isTradingDay;      %Set irrelevant prices to zero
     relevantStrikes(relevantStrikes(:, 1) == 0, :) = [];  %Delete irrelevant prices
     
     nPrices = size(relevantStrikes, 1);                   %Get number of relevant prices
     AssetVec   = Asset .* ones(nPrices, 1);               %Create vector of udnerlying value
     Strikes = relevantStrikes ./ 1000;                    %Get strikes of relevant options and divide by 1000 to match index
     
     if CallPutToggle == 0 
        %For Puts
        OTMCheck = ((AssetVec - Strikes) > 0);                     %Identify OTM options
        OTMFlag = [OTMFlag; OTMCheck];                             %Create OTM indicator vector
     
        ITMCheck = ((AssetVec - Strikes) < 0);                     %Identify ITM options
        ITMFlag = [ITMFlag; ITMCheck];                             %Create ITM indicator vector
        
        ATMCheck = ((AssetVec - Strikes) == 0);                    %Identify ATM options
        ATMFlag = [ITMFlag; ITMCheck];                             %Create ATM indicator vector
     
     else 
        %For Calls
        OTMCheck = ((AssetVec - Strikes) < 0);                     %Identify OTM options
        OTMFlag = [OTMFlag; OTMCheck];                             %Create OTM indicator vector
     
        ITMCheck = ((AssetVec - Strikes) > 0);                     %Identify ITM options
        ITMFlag = [ITMFlag; ITMCheck];                             %Create ITM indicator vector
        
        ATMCheck = ((AssetVec - Strikes) == 0);                    %Identify ATM options
        ATMFlag = [ITMFlag; ITMCheck];                             %Create ATM indicator vector
     end
     
         
     
end

%Delete inital value
OTM = OTMFlag(2:end); 
ITM = ITMFlag(2:end);
ATM = ATMFLag(2:end);



