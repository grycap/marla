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
import math
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
    NREDUCERS = int(os.environ['NREDUCERS'])

    if NodeNumber == 0:
        launcherNodes = 1 # Only this mapper is launching at this time
    else:
        launcherNodes = int(pow(2,int(math.log(NodeNumber,2))+1))   # Calculate the number of nodes launching mappers

    # The first node identifier to launch in this iteration is equal to "launcherNodes"
    # because index begins by 0. Each launcher node will launch his position beginning
    # in this position.
    myNextLaunch = launcherNodes + NodeNumber

    while myNextLaunch < TotalNodes:

            #launch lambda function mapper
            payload = {}
            payload["FileName"]=str(FileName)
            payload["NodeNumber"]=str(myNextLaunch)
            payload["TotalNodes"]=str(TotalNodes)
            payload["ChunkSize"]=str(ChunkSize)
            payload["FileSize"]=str(FileSize)
            payload["KeyIn"]=str(KeyIn)
            lambda_client = boto3.client('lambda')
            response_invoke = lambda_client.invoke(
                ClientContext='ClusterHD-'+BUCKET,
                FunctionName='HC-'+PREFIX+'-lambda-mapper',
                InvocationType='Event',
                LogType='Tail',
                Payload=json.dumps(payload),
            )
            # In each iteration, the number of launcher nodes
            # will be multiplied by 2
            launcherNodes = 2*launcherNodes
            myNextLaunch = launcherNodes + NodeNumber
    
    #download partition from data file
    bucketIn = BUCKET
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
                chunk = chunk + extraChunk[:posEndLine+1]
                break
            else:
                #save downloaded text and continue with next iteration
                chunk = chunk + extraChunk
                initRange = limitRange
                limitRange = limitRange + extraRange

         ##################
    ####### USER MAPPING #######
         ##################

    Pairs = user_functions.mapper(chunk)

    ############################

    del chunk
    # I'm not sure if this is necessary ...
    # Convert to string
    #Pairs = list(map(lambda pair:(str(pair[0]),str(pair[1])), Pairs))
    # Sort Pairs for name
    Pairs.sort()

         #################
    ####### USER REDUCE #######
         #################

    Results = user_functions.reducer(Pairs)
    del Pairs

    ###########################

    Results.sort()
    
    #upload results
    results = ""
    ASCIIinterval = (130-32)/NREDUCERS
    ASCIIlimit = ASCIIinterval+32
    ASCIInumInterval = 0       # Actual interval
    partialKey = PREFIX + "/" + FileName + "/"
    for name, value in Results:

        # take ASCII value of first "name" character
        ASCIIval = ord(str(name)[0])

        if ASCIIval >= 999:
            #Invalid data
            print("Name: " + str(name) + " out of range")
            continue
        
        # Add pairs to results until ASCII limit has been reached
        if ASCIIval < ASCIIlimit:
            results += "{0},{1}\n".format(name, value)
        else:
            while ASCIIval >= ASCIIlimit:
                print("ASCII group " + str(ASCIInumInterval) + " (" + str(name) +")")
                # Upload results
                resultsKey = partialKey + str(ASCIInumInterval) + "_" + str(NodeNumber)
                s3_client.put_object(Body=results,Bucket=BUCKETOUT,Key=resultsKey)
                
                # Update ASCII interval
                ASCIIlimit +=ASCIIinterval

                # Last ASCII interval chunk will contain
                # all extended characters too
                if ASCIIlimit > 126:
                    ASCIIlimit = 999
                
                # Clear results
                results = ""
                ASCIInumInterval += 1
            results += "{0},{1}\n".format(name, value)
        

    # Create remaining interval files
    for i in range (ASCIInumInterval,NREDUCERS):
        print("ASCII group " + str(i) + " (remaining)")
        # Upload results
        resultsKey = partialKey + str(i) + "_" + str(NodeNumber)
        s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)
        results = ""
                
    #check if this is the last partition.
    if NodeNumber == TotalNodes-1:
        #launch lambda functions reducers
        print("launching reducer functions")
        for i in range(0,NREDUCERS):
            lambda_client = boto3.client('lambda')
            payload = {}
            payload["ReducerNumber"] = str(i)
            payload["FileName"]=str(FileName)
            payload["TotalNodes"]=str(TotalNodes)
            response_invoke = lambda_client.invoke(
                ClientContext='ClusterHD-'+BUCKETOUT,
                FunctionName='HC-'+PREFIX+'-lambda-reducer',
                InvocationType='Event',
                LogType='Tail',
                Payload=json.dumps(payload),
            )
        
