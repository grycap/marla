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

def downloadPairs(usedMemory, maxUsedMemory, actualPartition, TotalNodes, BUCKETOUT, PREFIX, FileName, s3_client):

    chunk = ""
    init = actualPartition
    for j in range(init, TotalNodes):
        #download partition file
        bucket = BUCKETOUT
        key = PREFIX + "/" + FileName + "/" + str(j) + "_mapped"
        
        #extract file size
        response = s3_client.head_object(Bucket=bucket, Key=key)
        fileSize = int(response['ContentLength'])
        #check the used memory
        usedMemory = usedMemory + fileSize
        if usedMemory > maxUsedMemory and j != init:
            print("Using more memory than MaxMemory. Do not read more data.")
            break
        
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        
        print("downloaded " + bucket + "/" + key)
        print("used memory: {0}".format(usedMemory))
        
        chunk = chunk + str(obj['Body'].read().decode('utf-8'))
        actualPartition +=1

    del obj

    #extract Names and values
    print("Spliting lines")
    auxPairs = []
    chunkList = chunk.split('\n')
    chunk = None
    del chunk

    print("Extract columns")
    for line in chunkList:
        #extract data
        data = line.strip().split(",")
        if len(data) == 2:
            auxPairs.append(data)
        else:
            print("Incorrect formatted line ignoring: {0}".format(line))
        
    del chunkList   
    return auxPairs, actualPartition

def handler(event, context):
    #extract filename and the partition number
    FileName = event["FileName"]
    TotalNodes = int(event["TotalNodes"])

    memoryLimit = 0.06
    
    #load environment variables
    BUCKETOUT = str(os.environ['BUCKETOUT'])
    PREFIX = str(os.environ['PREFIX'])
    MEMORY = int(os.environ['MEMORY'])*1048576

    #limit memory usage (soft,hard)
    resource.setrlimit(resource.RLIMIT_AS, (MEMORY, MEMORY))

    soft,hard = resource.getrlimit(resource.RLIMIT_AS)

    print("Setting memory limtis, Soft: {0} B  Hard: {1} B".format(soft,hard))
    
    #take the file names from the mapped folder
    prefixFiles= PREFIX + '/' + FileName
    s3_client = boto3.client('s3')
    filesInBucket = []
    for fileDir in s3_client.list_objects(Bucket=BUCKETOUT, Prefix=prefixFiles)['Contents']:    
        data = fileDir['Key'].strip().split("/")
        posName = len(data)
        filesInBucket.append(str(data[posName-1]))

    #check if all partitions are mapped
    #this function will check that 5 times
    for i in range(5):
        allMapped = True
        for j in range(TotalNodes):
            auxName = str(j) + "_mapped"
            if auxName in filesInBucket:
                print(str(auxName) + " is mapped")
            else:
                print("mapping is not finished")
                allMapped = False
                break
        if allMapped == True:
            break
        time.sleep( 0.1 )

    #if mapping is not finished, the function
    #invoke another reduce function and termines
    if allMapped == False:
        #lunch lambda function reducer
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
        return

    #if mapping is finished, begin the reduce.
    
    #create lists to store results
    Pairs = []
    #iterate for all mapped partitions    
    maxUsedMemory = int(MEMORY*memoryLimit)
    print("Max memory to download data: {0} B".format(maxUsedMemory))
    while (i < TotalNodes):

        #download and extract pairs
        usedMemory = sys.getsizeof(Pairs)
        auxPairs, i = downloadPairs(usedMemory,maxUsedMemory, i, TotalNodes, BUCKETOUT, PREFIX, FileName, s3_client)
        
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
    resultsKey = os.path.join(PREFIX,FileName,"results")
    s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)
    
    #remove all partitions
    for i in range(TotalNodes):
        bucket = BUCKETOUT
        key = PREFIX + "/" + FileName + "/" + str(i) + "_mapped"
        s3_client.delete_object(Bucket=BUCKETOUT, Key=key)
