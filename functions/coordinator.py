import boto3
import os
import json

def handler(event, context):
    for record in event['Records']:
        #extract bucket and key name
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']        
        event = record['eventName']

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
        MEMORY = int(os.environ['MEMORY'])*1048576

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
        pointPos = key.find('.')
        if int(pointPos) < 0:
            pointPos = len(key)

        slashPos = key.rfind('/')+1            
        filename = key[slashPos:pointPos]
        
        #check file size
        lambda_client = boto3.client('lambda')
        s3_client = boto3.client('s3')
        response = s3_client.head_object(Bucket=BUCKET, Key=key)
        fileSize = response['ContentLength']
        print("FileSize = " + str(fileSize))

        #Calculate the chunk size
        chunkSize = int(int(fileSize)/int(MAPPERNUMBER))
        numberMappers = int(MAPPERNUMBER)
        if int(chunkSize) < int(MINBLOCKSIZE):
            print("chunk size to small (" + str(chunkSize) + " bytes), changing to " + str(MINBLOCKSIZE) + " bytes")
            chunkSize = MINBLOCKSIZE
            numberMappers = int(int(fileSize)/int(chunkSize))+1

        #Ensure that chunk size is smaller than lambda function memory
        secureMemorySize = int(float(MEMORY)*float(0.45))
        if int(chunkSize) > int(secureMemorySize):
            print("chunk size to large (" + str(chunkSize) + " bytes), changing to " + str(secureMemorySize) + " bytes")
            chunkSize = int(secureMemorySize)
            numberMappers = int(int(fileSize)/int(chunkSize))+1
            
        print("Using chunk size of " + str(chunkSize) + " bytes, and " + str(numberMappers) + " nodes")
        chunk = ""
        for i in range(0, numberMappers):
            #download chunk number i            
            limitRange = str((int(i)+1)*int(chunkSize)-1)
            if int(limitRange) > int(fileSize):
                limitRange = fileSize

            initRange = int(i)*int(chunkSize)
            chunkRange = 'bytes=' + str(initRange) + '-' + str(limitRange)
            obj = s3_client.get_object(Bucket=BUCKET, Key=key, Range=chunkRange)

            print("processing range " + str(initRange) + "-" + str(limitRange) + " bytes")

            #Extract body from the recived object
            chunk = chunk + obj['Body'].read().decode('utf-8') 
            #find the last '\n' of the chunk
            lastN = chunk.rfind('\n')

            if lastN < 0:
                #because we find the end of file and this chunck is empty
                print("End of file")
                break

            #upload all the content until last \n or until eof if this 
            #is the last partition
            chunkKey = PREFIX + "/" + filename + "/" + str(i)
            print("chunkKey = " + str(chunkKey))
            
            if int(i) < int(numberMappers)-1:
                s3_client.put_object(Body=chunk[:lastN],Bucket=BUCKETOUT, Key=chunkKey)
            else:
                s3_client.put_object(Body=chunk,Bucket=BUCKETOUT, Key=chunkKey)

            #lunch lambda function mapper
            payload = {}
            payload["FileName"]=str(filename)
            payload["NodeNumber"]=str(i)
            payload["TotalNodes"]=str(numberMappers)
            response_invoke = lambda_client.invoke(
                ClientContext='ClusterHD-'+BUCKET,
                FunctionName='HC-'+PREFIX+'-lambda-mapper',
                InvocationType='Event',
                LogType='Tail',
                Payload=json.dumps(payload),
            )            
            
            #save last incomplete line    
            chunk = chunk[lastN+1:]
    return
