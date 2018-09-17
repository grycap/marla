#!/bin/bash

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


if [ $# -ne 1 ]; then
  echo "Usage: $0 config.in"
  exit -1
fi

CONFIGFILE=$1

missingParameter="false"

#check if configuration file exists
if [ ! -f $CONFIGFILE ]; then
    echo -e "\e[31mConfiguration file not found!\e[39m"
    exit 1
fi

CLUSTERNAME=`sed -n 's/^ClusterName:[[:space:]]*//p' $CONFIGFILE`
FUNCTIONSDIR=`sed -n 's/^FunctionsDir:[[:space:]]*//p' $CONFIGFILE`
FUNCTIONSFILE=`sed -n 's/^FunctionsFile:[[:space:]]*//p' $CONFIGFILE`
REGION=`sed -n 's/^Region:[[:space:]]*//p' $CONFIGFILE`
BUCKETIN=`sed -n 's/^BucketIn:[[:space:]]*//p' $CONFIGFILE`
BUCKETOUT=`sed -n 's/^BucketOut:[[:space:]]*//p' $CONFIGFILE`
ROLE=`sed -n 's/^RoleARN:[[:space:]]*//p' $CONFIGFILE`
MAXMAPPERNODES=`sed -n 's/^MapperNodes:[[:space:]]*//p' $CONFIGFILE`
MINBLOCKSIZE=`sed -n 's/^MinBlockSize:[[:space:]]*//p' $CONFIGFILE`
MINBLOCKSIZE=$(($MINBLOCKSIZE*1024))
MAXBLOCKSIZE=`sed -n 's/^MaxBlockSize:[[:space:]]*//p' $CONFIGFILE`
MAXBLOCKSIZE=$(($MAXBLOCKSIZE*1024))
KMSKEYARN=`sed -n 's/^KMSKeyARN:[[:space:]]*//p' $CONFIGFILE`
MAPPERMEMORY=`sed -n 's/^MapperMemory:[[:space:]]*//p' $CONFIGFILE`
REDUCERMEMORY=`sed -n 's/^ReducerMemory:[[:space:]]*//p' $CONFIGFILE`
TIMEOUT=`sed -n 's/^TimeOut:[[:space:]]*//p' $CONFIGFILE`

USEKMSKEY=0

echo "----Parameter list----"
#check if some parameter is missing
if [[ $CLUSTERNAME = *[!\ ]* ]]
then
    echo "ClusterName: $CLUSTERNAME "
else
    echo -e "\e[31mMissing 'ClusterName:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $FUNCTIONSDIR = *[!\ ]* ]]
then
    echo "FunctionsDir: $FUNCTIONSDIR "
else
    echo -e "\e[31mMissing 'FunctionsDir:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $FUNCTIONSFILE = *[!\ ]* ]]
then
    echo "FunctionsFile: $FUNCTIONSFILE "
else
    echo -e "\e[31mMissing 'FunctionsFile:' in configuration file \e[39m"
    missingParameter="true"
fi


if [[ $REGION = *[!\ ]* ]]
then
    echo "Region: $REGION "
else
    echo -e "\e[31mMissing 'Region:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $BUCKETIN = *[!\ ]* ]]
then
    echo "BucketIn: $BUCKETIN "
else
    echo -e "\e[31mMissing 'BucketIn:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $BUCKETOUT = *[!\ ]* ]]
then
    echo "BucketOut: $BUCKETOUT "
else
    echo -e "\e[31mMissing 'BucketOut:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $ROLE = *[!\ ]* ]]
then
    echo "Role: $ROLE "
else
    echo -e "\e[31mMissing 'Role:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $MAXMAPPERNODES = *[!\ ]* ]]
then
    echo "MapperNodes: $MAXMAPPERNODES "
else
    echo -e "\e[31mMissing 'MaxMapperNodes:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $MINBLOCKSIZE = *[!\ ]* ]]
then
    echo "MinBlockSize: $MINBLOCKSIZE Bytes"
else
    echo -e "\e[31mMissing 'MinBlockSize:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $MAXBLOCKSIZE = *[!\ ]* ]]
then
    echo "MaxBlockSize: $MAXBLOCKSIZE Bytes"
else
    echo -e "\e[31mMissing 'MaxBlockSize:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $KMSKEYARN = *[!\ ]* ]]
then
    echo "KMSKeyARN: $KMSKEYARN "
    USEKMSKEY=1
else
    echo -e "Missing 'KMSKeyARN:' in configuration file, default service key will be used."
    USEKMSKEY=0
fi

if [[ $MAPPERMEMORY = *[!\ ]* ]]
then
    echo "MapperMemory: $MAPPERMEMORY "
else
    echo -e "\e[31mMissing 'MapperMemory:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $REDUCERMEMORY = *[!\ ]* ]]
then
    echo "ReducerMemory: $REDUCERMEMORY "
else
    echo -e "\e[31mMissing 'ReducerMemory:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $TIMEOUT = *[!\ ]* ]]
then
    echo "TimeOut: $TIMEOUT "
else
    echo -e "\e[31mMissing 'TimeOut:' in configuration file \e[39m"
    missingParameter="true"
fi

if [ $missingParameter == "true" ]
then
    exit 1
fi

echo "----------------------"

PWD=`pwd`

#Check for secure bucket input/output configuration
if [ "$BUCKETIN" == "$BUCKETOUT" ]
then
    echo -e "\e[31mYou are trying to use the same bucket as input and output"
    echo "this can be so dangerous, please reconsider your buckets choice."
    echo -e "If you want to continue, remove this 'if' statment in the script by your own responsability.\e[39m"
    exit 1
fi

#Extract role name
roleName=`echo "$ROLE" | cut -d "/" -f 2`
echo ""
echo -e "\e[36mMake sure that role '$roleName' has permissions to use"
echo -e "buckets '$BUCKETIN' and '$BUCKETOUT' and to execute 'lambda:InvokeFunction'\e[39m"
echo ""

echo "#####################################"
echo "##CREATE AND UPLOAD PACKAGES SECTION#"
echo "#####################################"

echo "----Creating packages...----"

#remove (if exists) previous cluster lambda packages
aws s3 rm s3://$BUCKETIN/$CLUSTERNAME/coordinator.zip &> /dev/null
aws s3 rm s3://$BUCKETIN/$CLUSTERNAME/mapper.zip &> /dev/null
aws s3 rm s3://$BUCKETIN/$CLUSTERNAME/reducer.zip &> /dev/null

#check if in FunctionsDir exists som reserved filename
fileCount=$(find $FUNCTIONSDIR -name marla_mapper_CH.py | wc -l)

if [[ $file_count -gt 0 ]]
then
    echo -e "\e[31mError: you are using reserved name 'marla_mapper_CH.py' in some of files in $FUNCTIONSDIR."
    echo -e "Please, change this filename\e[39m"
fi

fileCount=$(find $FUNCTIONSDIR -name marla_reducer_CH.py | wc -l)

if [[ $file_count -gt 0 ]]
then
    echo -e "\e[31mError: you are using reserved name 'marla_reducer_CH.py' in some of files in $FUNCTIONSDIR."
    echo -e "Please, change this filename\e[39m"
fi

#Create a directory in $HOME/.marla/ to store created files

if [ ! -d $HOME/.marla/ ]; then
    echo -e "Creating $HOME/.marla directory."
    mkdir $HOME/.marla
fi

rm -r $HOME/.marla/$CLUSTERNAME/ &> /dev/null

mkdir $HOME/.marla/$CLUSTERNAME &> /dev/null

#Check existence of directory
if [ ! -d $HOME/.marla/$CLUSTERNAME/ ]; then
    echo -e "\e[31mError: can't create '$HOME/.marla/$CLUSTERNAME/' directory."
    exit 1
fi

mkdir $HOME/.marla/$CLUSTERNAME/functions &> /dev/null
mkdir $HOME/.marla/$CLUSTERNAME/functions/mapper &> /dev/null
mkdir $HOME/.marla/$CLUSTERNAME/functions/reducer &> /dev/null

##Mapper##

#copy user functions to mapper directory
if cp $FUNCTIONSDIR/* $HOME/.marla/$CLUSTERNAME/functions/mapper/
then
    echo -e "\e[32mUser functions copied to mapper package\e[39m"
else
    echo -e "\e[31mError coping user functions\e[39m"
    exit 1
fi

#change user functions filename
if mv $HOME/.marla/$CLUSTERNAME/functions/mapper/$FUNCTIONSFILE $HOME/.marla/$CLUSTERNAME/functions/mapper/user_functions.py
then
    echo -e "\e[32mUser functions filename changed\e[39m"
else
    echo -e "\e[31mError changing filename of user functions\e[39m"
    exit 1
fi

#copy mapper cluster function to mapper directory
if cp functions/marla_mapper_CH.py $HOME/.marla/$CLUSTERNAME/functions/mapper/marla_mapper_CH.py
then
    echo -e "\e[32mCluster mapper function copied to mapper package\e[39m"
else
    echo -e "\e[31mError coping cluster mapper function\e[39m"
    exit 1
fi

##Reducer##

#copy user functions to reducer directory
if cp $FUNCTIONSDIR/* $HOME/.marla/$CLUSTERNAME/functions/reducer/
then
    echo -e "\e[32mUser functions copied to reducer package\e[39m"
else
    echo -e "\e[31mError coping user functions\e[39m"
    exit 1
fi

#change user functions filename
if mv $HOME/.marla/$CLUSTERNAME/functions/reducer/$FUNCTIONSFILE $HOME/.marla/$CLUSTERNAME/functions/reducer/user_functions.py
then
    echo -e "\e[32mUser functions filename changed\e[39m"
else
    echo -e "\e[31mError changing filename of user functions\e[39m"
    exit 1
fi

#copy reducer cluster function to reducer directory
if cp functions/marla_reducer_CH.py $HOME/.marla/$CLUSTERNAME/functions/reducer/marla_reducer_CH.py
then
    echo -e "\e[32mCluster reducer function copied to reducer package\e[39m"
else
    echo -e "\e[31mError coping cluster reducer function\e[39m"
    exit 1
fi

#####Create packages#####

#zip the coordinator code
if zip -j9 $HOME/.marla/$CLUSTERNAME/coordinator.zip functions/coordinator.py &> /dev/null
then
    echo -e "\e[32mCoordinator package created\e[39m"
else
    echo -e "\e[31mError creating coordinator package\e[39m"
    exit 1
fi

#zip the mapper code
if zip -j9 $HOME/.marla/$CLUSTERNAME/mapper.zip $HOME/.marla/$CLUSTERNAME/functions/mapper/* &> /dev/null
then
    echo -e "\e[32mMapper package created\e[39m"
else
    echo -e "\e[31mError creating mapper package\e[39m"
    exit 1
fi

#zip the reducer code
if zip -j9 $HOME/.marla/$CLUSTERNAME/reducer.zip $HOME/.marla/$CLUSTERNAME/functions/reducer/* &> /dev/null
then
    echo -e "\e[32mReducer package created\e[39m"
else
    echo -e "\e[31mError creating reducer package\e[39m"
    exit 1
fi


echo "-------------------------"

echo "----Uploading packages...----"

#Upload code for cluster functions to the cluster bucket
if aws s3 cp $HOME/.marla/$CLUSTERNAME/mapper.zip s3://$BUCKETIN/$CLUSTERNAME/mapper.zip &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mMapper code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading mapper code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr    
    exit 1
fi

rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws s3 cp $HOME/.marla/$CLUSTERNAME/reducer.zip s3://$BUCKETIN/$CLUSTERNAME/reducer.zip &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mReducer code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading reducer code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr    
    exit 1
fi

rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws s3 cp $HOME/.marla/$CLUSTERNAME/coordinator.zip s3://$BUCKETIN/$CLUSTERNAME/coordinator.zip &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mCoordinator code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading coordinator code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"

echo "###############################"
echo "##COORDINATOR FUNCTION SECTION#"
echo "###############################"

echo "----Creating coordinator function...----"

#Generate cli json for coordinator function
echo '{' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-coordinator",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Runtime": "python3.6",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Role": "'$ROLE'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Handler": "coordinator.handler",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Code": {' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '      "S3Key": "'$CLUSTERNAME'/coordinator.zip"' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
#echo '      "S3ObjectVersion": "0.1"' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   },' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Timeout": '$TIMEOUT',' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "MemorySize": 128,' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
#echo '   "Publish": true,' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '   "Environment": {' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '       "Variables": {' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "BUCKET": "'$BUCKETIN'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "MAPPERNUMBER": "'$MAXMAPPERNODES'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "MINBLOCKSIZE": "'$MINBLOCKSIZE'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "MAXBLOCKSIZE": "'$MAXBLOCKSIZE'",' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '           "MEMORY": "'$MAPPERMEMORY'"' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
echo '       }' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
if [ $USEKMSKEY == 1 ]
then
    echo '   },' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
    echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
else
    echo '   }' >> $HOME/.marla/$CLUSTERNAME/coordinator.json
fi
echo '}' >> $HOME/.marla/$CLUSTERNAME/coordinator.json


#Create lambda coordinator function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://$HOME/.marla/$CLUSTERNAME/coordinator.json &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mLambda coordinator function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda coordinator function.\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for coordinator function...----"


#Add permission to lambda coordinator function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-coordinator" --statement-id "HC-"$CLUSTERNAME"-coordinator-stateID" --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn "arn:aws:s3:::"$BUCKETIN &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mPermission to S3 added for coordinator function\e[39m"
else
    echo -e "\e[31mError adding permission to S3 for coordinator function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

#Extract coordinator function arn
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if coordinatorARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-coordinator" | grep -o 'arn:aws:lambda:\S*' | sed -e 's/",//g'` &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mARN of coordinator function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of coordinator function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

#Add a bucket notification configuration to "BUCKETIN"

echo '{' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '	"LambdaFunctionConfigurations": [' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '  {' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      "Id": "'$BUCKETIN'-'$CLUSTERNAME'-TRIGGERID",' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      "LambdaFunctionArn": "'$coordinatorARN'",' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      "Events": [' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '         "s3:ObjectCreated:*"' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      ],' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      "Filter": {' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '         "Key": {' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '             "FilterRules": [' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '                 {' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '                    "Name": "prefix",' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '                    "Value": "'$CLUSTERNAME'/"' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '                 }' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '             ]' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '         }' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '      }' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '  }' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo ' ]' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json
echo '}' >> $HOME/.marla/$CLUSTERNAME/coordinator_notification.json

rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws s3api put-bucket-notification-configuration --bucket $BUCKETIN --notification-configuration file://$HOME/.marla/$CLUSTERNAME/coordinator_notification.json &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mBucket notification configuration added\e[39m"
else
    echo -e "\e[31mError adding bucket notification configuration\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"

echo "###############################"
echo "##  MAPPER FUNCTION SECTION   #"
echo "###############################"

echo "----Creating mapper function...----"

#Generate cli json for mapper function
echo '{' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-mapper",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Runtime": "python3.6",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Role": "'$ROLE'",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Handler": "marla_mapper_CH.handler",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Code": {' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '      "S3Key": "'$CLUSTERNAME'/mapper.zip"' >> $HOME/.marla/$CLUSTERNAME/mapper.json
#echo '      "S3ObjectVersion": "0.1"' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   },' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Timeout": '$TIMEOUT',' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "MemorySize": '$MAPPERMEMORY',' >> $HOME/.marla/$CLUSTERNAME/mapper.json
#echo '   "Publish": true,' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '   "Environment": {' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '       "Variables": {' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '           "BUCKET": "'$BUCKETIN'",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '           "MEMORY": "'$MAPPERMEMORY'"' >> $HOME/.marla/$CLUSTERNAME/mapper.json
echo '       }' >> $HOME/.marla/$CLUSTERNAME/mapper.json
if [ $USEKMSKEY == 1 ]
then
    echo '   },' >> $HOME/.marla/$CLUSTERNAME/mapper.json
    echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> $HOME/.marla/$CLUSTERNAME/mapper.json
else
    echo '   }' >> $HOME/.marla/$CLUSTERNAME/mapper.json
fi    
echo '}' >> $HOME/.marla/$CLUSTERNAME/mapper.json

#Create lambda mapper function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://$HOME/.marla/$CLUSTERNAME/mapper.json &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mLambda mapper function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda mapper function.\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for mapper function...----"

#Add permission to lambda mapper function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-mapper" --statement-id "HC-"$CLUSTERNAME"-mapper-stateID" --action "lambda:InvokeFunction" --principal lambda.amazonaws.com --source-arn $coordinatorARN &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mPermission to coordination function added for mapper function\e[39m"
else
    echo -e "\e[31mError adding permission to coordinator function for mapper function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

#Extract mapper function arn
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if mapperARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-mapper" | grep -o 'arn:aws:lambda:\S*'` &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mARN of mapper function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of mapper function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"


echo "################################"
echo "##  REDUCER FUNCTION SECTION   #"
echo "################################"

echo "----Creating reducer function...----"

#Generate cli json for reducer function
echo '{' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-reducer",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Runtime": "python3.6",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Role": "'$ROLE'",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Handler": "marla_reducer_CH.handler",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Code": {' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '      "S3Key": "'$CLUSTERNAME'/reducer.zip"' >> $HOME/.marla/$CLUSTERNAME/reducer.json
#echo '      "S3ObjectVersion": "0.1"' >> reducer.json
echo '   },' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Timeout": '$TIMEOUT',' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "MemorySize": '$REDUCERMEMORY',' >> $HOME/.marla/$CLUSTERNAME/reducer.json
#echo '   "Publish": true,' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '   "Environment": {' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '       "Variables": {' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '           "MEMORY": "'$REDUCERMEMORY'"' >> $HOME/.marla/$CLUSTERNAME/reducer.json
echo '       }' >> $HOME/.marla/$CLUSTERNAME/reducer.json
if [ $USEKMSKEY == 1 ]
then
    echo '   },' >> $HOME/.marla/$CLUSTERNAME/reducer.json
    echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> $HOME/.marla/$CLUSTERNAME/reducer.json
else
    echo '   }' >> $HOME/.marla/$CLUSTERNAME/reducer.json    
fi
echo '}' >> $HOME/.marla/$CLUSTERNAME/reducer.json

#Create lambda reducer function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://$HOME/.marla/$CLUSTERNAME/reducer.json &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mLambda reducer function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda reducer function.\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for reducer function...----"

#Add permission to lambda mapper function to invoke reducer function
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-reducer" --statement-id "HC-"$CLUSTERNAME"-reducer-stateID" --action "lambda:InvokeFunction" --principal lambda.amazonaws.com --source-arn $mapperARN &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mPermission to mapper function added for reducer function\e[39m"
else
    echo -e "\e[31mError adding permission to mapper function for reducer function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi

#Extract reducer function arn
rm $HOME/.marla/$CLUSTERNAME/stderr &> /dev/null
if reducerARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-reducer" | grep -o 'arn:aws:lambda:\S*'` &> $HOME/.marla/$CLUSTERNAME/stderr
then
    echo -e "\e[32mARN of reducer function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of reducer function\e[39m"
    more $HOME/.marla/$CLUSTERNAME/stderr
    exit 1
fi


echo "-------------------------"

echo "Cluster generated successfully!"
