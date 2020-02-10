clear;
clc;

Prices1 = readtable('OptionPrices1.xlsx');
Prices2 = readtable('OptionPrices2.xlsx');
Prices3 = readtable('OptionPrices3.xlsx');
Prices4 = readtable('OptionPrices4.xlsx');
Prices5 = readtable('OptionPrices5.xlsx');
Prices6 = readtable('OptionPrices6.xlsx');


Prices = [Prices1; Prices2; Prices3; Prices4; Prices5; Prices6];

clear Prices1
clear Prices2
clear Prices3
clear Prices4
clear Prices5
clear Prices6

save Prices
