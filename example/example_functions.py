 
def mapper(chunk, Names, Values):
    #chunk is the raw text from data file
    #Names and Values are empty 1D lists, you must
    #store the pairs Name, Value into this lists
    for line in chunk.split('\n'):
        data = line.strip().split(",")
        if len(data) == 6:
            zip_code, latitude, longitude, city, state, country = data
            Names.append(str(country))
            Values.append(1)
    return

def reducer(Pairs, Results):
    #Pairs is a list of 2D tuples [(a,b),(c,d),...]
    #sorted by "Name".
    #Pairs estructure: Pairs[i][0] -> Name[i], Pairs[i][1] -> Value[i]
    #Results is a empty 2D list to store de reducer results.
    #Has the same structure of "Pairs"
    nPairs = len(Pairs)
    actualName = None
    resultsIndex = -1
    for i in range(0, nPairs):
        if actualName != str(Pairs[i][0]):
            actualName = str(Pairs[i][0])
            Results.append([str(Pairs[i][0]),int(Pairs[i][1])])
            resultsIndex = int(resultsIndex) + 1
        else:
            Results[resultsIndex][1] = int(Results[resultsIndex][1]) + int(Pairs[i][1])
            
        
