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
import user_functions

def handler(event, context):
    #extract filename and the partition number
    FileName = event["FileName"]
    TotalNodes = event["TotalNodes"]

    #load environment variables
    BUCKETOUT = str(os.environ['BUCKETOUT'])
    PREFIX = str(os.environ['PREFIX'])
    MEMORY = int(os.environ['MEMORY'])*1048576

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
    allMapped = True
    for i in range(0, 5):
        for j in range(0, int(TotalNodes)):
            auxName = str(j) + "_mapped"
            if auxName in filesInBucket:
                print(str(auxName) + " is mapped")
            else:
                print("mapping is not finished")
                allMapped = False
                break
        if allMapped == True:
            break
        time.sleep( 5 )

    #if mapping is not finished, the function
    #invoke another reduce function and termines
    if allMapped == False:
        #lunch lambda function reducer
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
    maxUsedMemory = MEMORY*0.45
    while (i < int(TotalNodes)):
        chunk = ""
        usedMemory = 0
        init = i
        for j in range (init, int(TotalNodes)):
            #donwload partition file
            bucket = BUCKETOUT
            key = PREFIX + "/" + FileName + "/" + str(j) + "_mapped"
            
            #extract file size
            response = s3_client.head_object(Bucket=bucket, Key=key)
            fileSize = response['ContentLength']
            del response
            #check the used memory
            usedMemory = int(usedMemory) + int(fileSize)
            if int(usedMemory) > int(maxUsedMemory):
                break
            
            obj = s3_client.get_object(Bucket=bucket, Key=key)
            
            print("donwloaded " + bucket + "/" + key)
        
            chunk = chunk + str(obj['Body'].read().decode('utf-8'))
            del obj
            i +=1

            
        #extract Names and values
        auxPairs = []
        for line in chunk.split('\n'):
            data = line.strip().split(",")
            if len(data) == 2:
                auxPairs.append(data)
            else:
                print("Incorrect formatted line ignoring: {0}".format(line))

        del chunk

        #Merge with previous pairs and sort
        auxPairs += Pairs
        auxPairs.sort()
            #################
        ####### USER REDUCE #######
            #################
         
        Results = []
        user_functions.reducer(auxPairs, Results)
        del auxPairs
        
        ###########################

        #Save new results for the next iteration        
        for name, value in Results:
            Pairs.append([str(name), str(value)])
        del Results

    #upload results
    results = ""
    for name, value in Pairs:
        results += "{0},{1}\n".format(name, value)

    resultsKey = os.path.join(PREFIX,FileName,"results")
    s3_client.put_object(Body=results,Bucket=BUCKETOUT, Key=resultsKey)
    
    #remove all partitions
    for i in range (0, int(TotalNodes)):
        bucket = BUCKETOUT
        key = PREFIX + "/" + FileName + "/" + str(i) + "_mapped"
        s3_client.delete_object(Bucket=BUCKETOUT, Key=key)
