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
import time
import json
import sys
import user_functions
import resource
import botocore
import hashlib


def downloadPairs(filesSize,usedMemory, maxUsedMemory, actualPartition, TotalNodes, BUCKETOUT, PREFIX, FileName, ReducerNumber, s3_client):

    chunk = ""
    init = actualPartition
    for j in range(init, TotalNodes):
        #download partition file
        bucket = BUCKETOUT
        key = PREFIX + "/" + FileName + "/" + str(ReducerNumber) + "_" + str(j)

        #Add hash prefix
        key = str(hashlib.md5(key.encode()).hexdigest()) + "/" + key                
        
        #Get corresponding file size
        fileSize = filesSize[j]
        #check the used memory
        usedMemory = usedMemory + fileSize
        if usedMemory > maxUsedMemory and j != init:
            print("Using more memory than MaxMemory. Do not read more data.")
            break

        # Try to download file a maximum of 5 times
        for i in range(5):
            try:
                obj = s3_client.get_object(Bucket=bucket, Key=key)
                break
            except botocore.exceptions.ClientError as e:
                print("Can't download " + str(auxName) + ", try num " + str(i))
                time.sleep(0.2)
                if i == 4:
                    print("Unable to download + " + str(auxName) + " aborting reduce")
                    sys.exit()
            
        
        
        print("downloaded " + bucket + "/" + key)
        print("used memory: {0}".format(usedMemory))
        
        chunk = chunk + str(obj['Body'].read().decode('utf-8'))
        actualPartition +=1
        obj = None

    del obj

    #extract Names and values
    print("Spliting lines")
    auxPairs = []
    chunkList = chunk.split('\n')
    chunk = ""
    del chunk

    print("Extract columns")
    for line in chunkList:
        #extract data
        data = line.strip().split(",")
        if len(data) == 2:
            auxPairs.append(data)
        else:
            print("Incorrect formatted line ignoring: {0}".format(line))

    chunkList = ""
    del chunkList   
    return auxPairs, actualPartition

def handler(event, context):
    #extract filename and the partition number
    FileName = event["FileName"]
    TotalNodes = int(event["TotalNodes"])
    ReducerNumber = int(event["ReducerNumber"])
    memoryLimit = 0.03
    
    #load environment variables
    BUCKETOUT = str(os.environ['BUCKETOUT'])
    PREFIX = str(os.environ['PREFIX'])
    MEMORY = int(os.environ['MEMORY'])*1048576

    #Check invocation number
    Invocation = int(event["Invocation"])

    print("Invocation number " + str(Invocation) + " of reduce function " + str(ReducerNumber))
    
    if ReducerNumber >= 0 and Invocation > 20:
        print("Too many invocations. Abort reduce.")
        return
    elif ReducerNumber < 0 and Invocation > 70:
        print("Too many invocations. Abort reduce.")
        return        
    
    tester=False
    if ReducerNumber < 0:
        tester = True
        NREDUCERS = int(os.environ['NREDUCERS'])
        ReducerNumber = NREDUCERS-1
    

    #Get boto3 s3 client
    s3_client = boto3.client('s3')

        
    #check if all partitions are mapped
    #this function will check that 5 times
    keyPrefix = PREFIX + "/" + FileName + "/" + str(ReducerNumber) + "_"
    filesSize = [] # Store mapped files size
    for i in range(5):
        allMapped = True
        for j in range(len(filesSize),TotalNodes):
            auxName = keyPrefix + str(j)

            #Add hash prefix
            auxName = str(hashlib.md5(auxName.encode()).hexdigest()) + "/" + auxName
            
            try:
                response = s3_client.head_object(Bucket=BUCKETOUT, Key=auxName)
                filesSize.append(int(response['ContentLength']))
            except botocore.exceptions.ClientError as e:
                print("mapping of " + str(auxName) + " not finished")
                allMapped = False
                break
        if allMapped == True:
            break
        time.sleep( 0.5 )

    #if mapping is not finished, the function
    #invoke another reduce function and termines
    if allMapped == False:
        #lunch lambda function reducer
        if tester == True:
            ReducerNumber = -1
            time.sleep( 2 )
        lambda_client = boto3.client('lambda')
        payload = {}
        payload["Invocation"] = str(Invocation+1)
        payload["ReducerNumber"] = str(ReducerNumber)
        payload["FileName"]=str(FileName)
        payload["TotalNodes"]=str(TotalNodes)
        response_invoke = lambda_client.invoke(
            ClientContext='ClusterHD-'+BUCKETOUT,
            FunctionName='HC-'+PREFIX+'-lambda-reducer',
            InvocationType='Event',
            LogType='Tail',
            Payload=json.dumps(payload),
        )
        return

    if len(filesSize) != TotalNodes:
        print("Error: number of file sizes stored (" + str(len(filesSize)) + ") not equal to total mapper nodes (" + str(TotalNodes) + ")")
        print("Reduce aborted")
        return
    
    #if mapping is finished, begin the reduce.

    #If this reducer is the tester reduce, launch all reducer functions
    if tester == True:
        for i in range(NREDUCERS):
            lambda_client = boto3.client('lambda')
            payload = {}
            payload["Invocation"] = '0'
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
        return
    
    #create lists to store results
    Pairs = []
    #iterate for all mapped partitions    
    maxUsedMemory = int(MEMORY*memoryLimit)
    i=0
    print("Max memory to download data: {0} B".format(maxUsedMemory))
    while (i < TotalNodes):

        #download and extract pairs
        usedMemory = sys.getsizeof(Pairs)
        auxPairs, i = downloadPairs(filesSize,usedMemory,maxUsedMemory, i, TotalNodes, BUCKETOUT, PREFIX, FileName, ReducerNumber, s3_client)
        
        #Merge with previous pairs and sort
        print("Sorting data")
        auxPairs += Pairs

        Pairs = []
        auxPairs.sort()
        print("Reducing data")
            #################
        ####### USER REDUCE #######
            #################
        #Save new results for the next iteration
        Pairs = user_functions.reducer(auxPairs)

        auxPairs = []

    #upload results
    print("Stringify data")

    results = ""
    numPairs = len(Pairs)
    PairsSize = sys.getsizeof(Pairs)
    print("Results size {0}".format(PairsSize))

    if sys.getsizeof(Pairs) > maxUsedMemory/2:

        print("Spliting huge results")
        Pairs1 = Pairs[0:int(numPairs/2)]
        del Pairs[0:int(numPairs/2)]

        for x in Pairs1:
            results += "{0},{1}\n".format(x[0], x[1])

        del Pairs1
        
        for x in Pairs:
            results += "{0},{1}\n".format(x[0], x[1])
        
    else:
        i = 0
        while i < numPairs:
            results += "{0},{1}\n".format(Pairs[i][0], Pairs[i][1])
            i=i+1
        
    del Pairs
    print("Uploading data")
    resultsKey = os.path.join(PREFIX,FileName,str(ReducerNumber) + "_results")
    s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)

    #remove all partitions
    for i in range(TotalNodes):
        bucket = BUCKETOUT
        key = PREFIX + "/" + FileName + "/" + str(ReducerNumber) + "_" + str(i)

        #Add hash prefix
        key = str(hashlib.md5(key.encode()).hexdigest()) + "/" + key                
        
        s3_client.delete_object(Bucket=BUCKETOUT, Key=key)
