# MARLA - MApReduce on AWS Lambda
# Copyright (C) GRyCAP - I3M - UPV 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License. 

import boto3
import os
import json
import user_functions

def handler(event, context):
    #extract filename and the partition number
    FileName = event["FileName"]
    NodeNumber = int(event["NodeNumber"])
    TotalNodes = int(event["TotalNodes"])
    ChunkSize = int(event["ChunkSize"])
    FileSize = int(event["FileSize"])
    KeyIn = event["KeyIn"]

    #load environment variables
    BUCKET = str(os.environ['BUCKET'])
    BUCKETOUT = str(os.environ['BUCKETOUT'])
    PREFIX = str(os.environ['PREFIX'])

    #download partition from data file
    bucketIn = BUCKET
    key = PREFIX + "/" + FileName + "/" + str(NodeNumber)
    s3_client = boto3.client('s3')

    #calculate the partition range
    initRange = NodeNumber*ChunkSize
    limitRange = initRange + ChunkSize - 1
    if NodeNumber == TotalNodes-1:
        limitRange = FileSize
    
    chunkRange = 'bytes=' + str(initRange) + '-' + str(limitRange)
    obj = s3_client.get_object(Bucket=bucketIn, Key=KeyIn, Range=chunkRange)

    print("donwloaded partition {0} from {1}/{2}".format(NodeNumber ,bucketIn, KeyIn))
    print("range {0}-{1}".format(initRange ,limitRange))
    chunk = obj['Body'].read().decode('utf-8')
    del obj

    if NodeNumber > 0:
        #delete first line until '\n' (inclusive)
        chunk=chunk.split('\n', 1)[-1]
    
    if NodeNumber < TotalNodes-1:
        #download next text until '\n'
        #calculate the size of extra text
        linelen = chunk.find('\n')
        if linelen < 0:
            print("\ n not found in mapper chunk")
            return
        extraRange = 2*(linelen+20)
        initRange = limitRange + 1
        limitRange = limitRange + extraRange
        
        while limitRange < FileSize:
            chunkRange = 'bytes=' + str(initRange) + '-' + str(limitRange)
            obj = s3_client.get_object(Bucket=bucketIn, Key=KeyIn, Range=chunkRange)

            extraChunk = obj['Body'].read().decode('utf-8')
            posEndLine = extraChunk.find('\n')
            #check if end of line is found
            if  posEndLine != -1:
                #add extra text until '\n' and exit from loop
                chunk = chunk + extraChunk[:posEndLine]
                break
            else:
                #save downloaded text and continue with next iteration
                chunk = chunk + extraChunk
                initRange = limitRange
                limitRange = limitRange + extraRange
                

        
    #declare variables to store
    #mapping results.
    Pairs = []

         ##################
    ####### USER MAPPING #######
         ##################

    user_functions.mapper(chunk, Pairs)

    ############################

    del chunk
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
    del Pairs

    ###########################

    #upload results
    results = ""
    for name, value in Results:
        results += "{0},{1}\n".format(name, value)

    resultsKey = str(key) + "_mapped"
    s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)

    #check if this is the last partition.
    if NodeNumber == TotalNodes-1:
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
        
