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

    print("donwloaded {0}/{1}".format(bucket, key))
    chunk = obj['Body'].read().decode('utf-8')

    #declare variables to store
    #mapping results.
    Pairs = []
    
         ##################
    ####### USER MAPPING #######
         ##################

    user_functions.mapper(chunk, Pairs)
         
    ############################

    # I'm not sure if this is necessary ...
    # Convert to string
    Pairs = list(map(lambda pair:(str(pair[0]),str(pair[1])), Pairs))
    #Sort Pairs for name
    Pairs = sorted(Pairs)

         #################
    ####### USER REDUCE #######
         #################
         
    Results = []
    user_functions.reducer(Pairs, Results)
    
    ###########################
    
    #upload results
    results = ""
    for name, value in Results:
        results += "{0},{1}\n".format(name, value)

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
        
