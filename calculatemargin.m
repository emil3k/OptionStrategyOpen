function margin = calculatemargin(Price, Strike, Underlying)

    margin = Price + max(0.15 * Underlying - (Strike - Underlying), 0.1 * Strike);
    
end

