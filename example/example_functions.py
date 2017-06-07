 
def mapper(chunk):
    """
    The mapper function: process the raw text and returns the pairs name-value.
    Args:
    - chunk(str): the raw text from data file
    Return(list of tuples): a list of 2D tuples with the pairs name-value. 
    """
    Pairs = []
    for line in chunk.split('\n'):
        data = line.strip().split(",")
        if len(data) == 6:
            zip_code, latitude, longitude, city, state, country = data
            Pairs.append((str(country), 1))
    return Pairs

def reducer(Pairs):
    """
    The reducer function: reduces the Pairs.
    Args:
    - Pairs(list of tuples): a sorted list of 2D tuples with the pairs name-value.
    Return(list of tuples): a list of 2D tuples with the pairs name-value. 
    """
    Results = []
    actualName = None
    resultsIndex = -1
    for name, value in Pairs:
        if actualName != str(name):
            actualName = str(name)
            Results.append([str(name),int(value)])
            resultsIndex = resultsIndex + 1
        else:
            Results[resultsIndex][1] = int(Results[resultsIndex][1]) + int(value)
    return Results