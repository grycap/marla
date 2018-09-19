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

def handler(event, context):
    for record in event['Records']:
        #extract bucket and key name
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']        
        event = record['eventName']

        memoryLimit = 0.30
        
        #check if event type is "ObjectCreated"
        if event.find("ObjectCreated:") != 0:
            print("not ObjectCreated event")
            return

        print("Bucket = " + bucket)
        print("Key = " + key)
        
        #load environment variables
        BUCKET = str(os.environ['BUCKET'])
        BUCKETOUT = str(os.environ['BUCKETOUT'])
        PREFIX = str(os.environ['PREFIX'])
        MAPPERNUMBER = int(os.environ['MAPPERNUMBER'])
        MINBLOCKSIZE = int(os.environ['MINBLOCKSIZE'])
        MAXBLOCKSIZE = int(os.environ['MAXBLOCKSIZE'])
        MEMORY = float(os.environ['MEMORY'])*1048576.0
        
        #check bucket and prefix
        if bucket != BUCKET:
            print("wrong bucket")
            return
        if key.find(PREFIX) != 0:
            print("wrong key")
            return
        #check if the key have only 1 slash (/)
        if key.find('/') != key.rfind('/'):
            print("this file is in a folder")
            return

        #Extract file name
        filename = os.path.splitext(os.path.basename(key))[0]
        
        #check file size
        lambda_client = boto3.client('lambda')
        s3_client = boto3.client('s3')
        response = s3_client.head_object(Bucket=BUCKET, Key=key)
        fileSize = response['ContentLength']
        print("FileSize = " + str(fileSize))

        #Calculate the chunk size
        chunkSize = int(fileSize/(MAPPERNUMBER-1))
        numberMappers = MAPPERNUMBER
        if chunkSize < MINBLOCKSIZE:
            print("chunk size to small (" + str(chunkSize) + " bytes), changing to " + str(MINBLOCKSIZE) + " bytes")
            chunkSize = MINBLOCKSIZE
            numberMappers = int(fileSize/chunkSize)+1

        #Ensure that chunk size is smaller than lambda function memory
        secureMemorySize = int(MEMORY*memoryLimit)
        if chunkSize > secureMemorySize:
            print("chunk size to large (" + str(chunkSize) + " bytes), changing to " + str(secureMemorySize) + " bytes")
            chunkSize = secureMemorySize
            numberMappers = int(fileSize/chunkSize)+1

        if MAXBLOCKSIZE > 0:
            if chunkSize > MAXBLOCKSIZE:
                print("chunk size to big (" + str(chunkSize) + " bytes), changing to " + str(MAXBLOCKSIZE) + " bytes")
                chunkSize = MAXBLOCKSIZE
                numberMappers = int(fileSize/chunkSize)+1
        
        print("Using chunk size of " + str(chunkSize) + " bytes, and " + str(numberMappers) + " nodes")


        #create a dummy file in output folder
        keyDummy= PREFIX + '/' + filename + '/dummy'
        s3_client.put_object(Body=str(numberMappers),Bucket=BUCKETOUT, Key=keyDummy)        
        
        #launch first mapper
        payload = {}
        payload["FileName"]=str(filename)
        payload["NodeNumber"]=str(0)
        payload["TotalNodes"]=str(numberMappers)
        payload["ChunkSize"]=str(chunkSize)
        payload["FileSize"]=str(fileSize)
        payload["KeyIn"]=str(key)
        response_invoke = lambda_client.invoke(
            ClientContext='ClusterHD-'+BUCKET,
            FunctionName='HC-'+PREFIX+'-lambda-mapper',
            InvocationType='Event',
            LogType='Tail',
            Payload=json.dumps(payload),
        )            
            
    return
