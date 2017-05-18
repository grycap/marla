import boto3
import os
import json
import user_functions

def handler(event, context):
    #extract filename and the partition number
    FileName = event["FileName"]
    NodeNumber = event["NodeNumber"]
    TotalNodes = event["TotalNodes"]

    #load environment variables
    BUCKETOUT = str(os.environ['BUCKETOUT'])
    PREFIX = str(os.environ['PREFIX'])

    #donwload partition file
    bucket = BUCKETOUT
    key = PREFIX + "/" + FileName + "/" + str(NodeNumber)
    s3_client = boto3.client('s3')
    obj = s3_client.get_object(Bucket=bucket, Key=key)

    print("donwloaded " + bucket + "/" + key)
    chunk = obj['Body'].read().decode('utf-8')
    del obj

    #declare variables to store
    #mapping results.
    Names = []
    Values = []
    nPairs = 0
    
         ##################
    ####### USER MAPPING #######
         ##################

    user_functions.mapper(chunk, Names, Values)
         
    ############################

    del chunk
    nPairs = len(Names)
    Names = list(map(str, Names))
    Values = list(map(str, Values))
    #Sort Pairs for name
    Pairs = sorted(zip(Names,Values))
    del Names
    del Values

         #################
    ####### USER REDUCE #######
         #################
         
    Results = []
    user_functions.reducer(Pairs, Results)
    del Pairs
    
    ###########################
    
    #upload results
    results = ""
    nResults = len(Results)
    for i in range(0, nResults):
        results = results + str(Results[i][0]) + "," + str(Results[i][1]) + "\n"

    resultsKey = str(key) + "_mapped"
    s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)

    #remove partition
    s3_client.delete_object(Bucket=BUCKETOUT, Key=key)

    #check if this is the last partition.
    if int(NodeNumber) == int(TotalNodes)-1:
        #lunch lambda function reducer
        print("lunching reducer function")
        lambda_client = boto3.client('lambda')
        payload = {}
        payload["FileName"]=str(FileName)
        payload["TotalNodes"]=str(TotalNodes)
        response_invoke = lambda_client.invoke(
            ClientContext='ClusterHD-'+BUCKETOUT,
            FunctionName='HC-'+PREFIX+'-lambda-reducer',
            InvocationType='Event',
            LogType='Tail',
            Payload=json.dumps(payload),
        )
        
