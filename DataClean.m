%% Clean 
clc;
clear;
close all;
load Prices

Prices1 = Prices1(1:1047533, :); %Delete the overlapping observations
Prices  = [Prices1 ; Prices2];    %Create one table with all data
SP500   = xlsread('SPX_BBG.xlsx');

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

AMSettlement = (table2array(OptionPrices(:, end)) == 1);  %Create logical for AM-Settlement
OptionPrices = OptionPrices(AMSettlement, :);             %Keep Option Prices of AM-settled options









return 

Headers = OptionPrices.Properties.VariableNames;

%Get rid of PM settled options
OptionPrices = table2array(OptionPrices);
