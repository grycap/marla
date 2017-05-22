 
def mapper(chunk, Pairs):
    #chunk is the raw text from data file
    #Names and Values are empty 1D lists, you must
    #store the pairs Name, Value into this lists
    for line in chunk.split('\n'):
        data = line.strip().split(",")
        if len(data) == 6:
            zip_code, latitude, longitude, city, state, country = data
            Pairs.append((str(country), 1))
    return

def reducer(Pairs, Results):
    #Pairs is a list of 2D tuples [(a,b),(c,d),...]
    #sorted by "Name".
    #Pairs estructure: Pairs[i][0] -> Name[i], Pairs[i][1] -> Value[i]
    #Results is a empty 2D list to store de reducer results.
    #Has the same structure of "Pairs"
    actualName = None
    resultsIndex = -1
    for name, value in Pairs:
        if actualName != str(name):
            actualName = str(name)
            Results.append([str(name),int(value)])
            resultsIndex = resultsIndex + 1
        else:
            Results[resultsIndex][1] = int(Results[resultsIndex][1]) + int(value)
