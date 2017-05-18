 
#!/bin/bash

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
KMSKEYARN=`sed -n 's/^KMSKeyARN:[[:space:]]*//p' $CONFIGFILE`
MEMORY=`sed -n 's/^Memory:[[:space:]]*//p' $CONFIGFILE`
TIMEOUT=`sed -n 's/^TimeOut:[[:space:]]*//p' $CONFIGFILE`

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

if [[ $KMSKEYARN = *[!\ ]* ]]
then
    echo "KMSKeyARN: $KMSKEYARN "
else
    echo -e "\e[31mMissing 'KMSKeyARN:' in configuration file \e[39m"
    missingParameter="true"
fi

if [[ $MEMORY = *[!\ ]* ]]
then
    echo "Memory: $MEMORY "
else
    echo -e "\e[31mMissing 'Memory:' in configuration file \e[39m"
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
fileCount=$(find $FUNCTIONSDIR -name -mapper---CH.py | wc -l)

if [[ $file_count -gt 0 ]]
then
    echo -e "\e[31mError: you are using reserved name '-mapper---CH.py' in some of files in $FUNCTIONSDIR."
    echo -e "Please, change this filename\e[39m"
fi

fileCount=$(find $FUNCTIONSDIR -name -reducer---CH.py | wc -l)

if [[ $file_count -gt 0 ]]
then
    echo -e "\e[31mError: you are using reserved name '-reducer---CH.py' in some of files in $FUNCTIONSDIR."
    echo -e "Please, change this filename\e[39m"
fi

#rm content of reducer and mapper folders
rm -r functions/mapper/ &> /dev/null
rm -r functions/reducer/ &> /dev/null

mkdir functions/mapper &> /dev/null
mkdir functions/reducer &> /dev/null

##Mapper##

#copy user functions to mapper directory
if cp $FUNCTIONSDIR/* functions/mapper/
then
    echo -e "\e[32mUser functions copied to mapper package\e[39m"
else
    echo -e "\e[31mError coping user functions\e[39m"
    exit 1
fi

#change user functions filename
if mv functions/mapper/$FUNCTIONSFILE functions/mapper/user_functions.py
then
    echo -e "\e[32mUser functions filename changed\e[39m"
else
    echo -e "\e[31mError changing filename of user functions\e[39m"
    exit 1
fi

#copy mapper cluster function to mapper directory
if cp functions/-mapper---CH.py functions/mapper/-mapper---CH.py
then
    echo -e "\e[32mCluster mapper function copied to mapper package\e[39m"
else
    echo -e "\e[31mError coping cluster mapper function\e[39m"
    exit 1
fi

##Reducer##

#copy user functions to reducer directory
if cp $FUNCTIONSDIR/* functions/reducer/
then
    echo -e "\e[32mUser functions copied to reducer package\e[39m"
else
    echo -e "\e[31mError coping user functions\e[39m"
    exit 1
fi

#change user functions filename
if mv functions/reducer/$FUNCTIONSFILE functions/reducer/user_functions.py
then
    echo -e "\e[32mUser functions filename changed\e[39m"
else
    echo -e "\e[31mError changing filename of user functions\e[39m"
    exit 1
fi

#copy reducer cluster function to reducer directory
if cp functions/-reducer---CH.py functions/reducer/-reducer---CH.py
then
    echo -e "\e[32mCluster reducer function copied to reducer package\e[39m"
else
    echo -e "\e[31mError coping cluster reducer function\e[39m"
    exit 1
fi

#####Create packages#####

#zip the coordinator code
if zip -j9 coordinator.zip functions/coordinator.py &> /dev/null
then
    echo -e "\e[32mCoordinator package created\e[39m"
else
    echo -e "\e[31mError creating coordinator package\e[39m"
    exit 1
fi

#zip the mapper code
if zip -j9 mapper.zip functions/mapper/* &> /dev/null
then
    echo -e "\e[32mMapper package created\e[39m"
else
    echo -e "\e[31mError creating mapper package\e[39m"
    exit 1
fi

#zip the reducer code
if zip -j9 reducer.zip functions/reducer/* &> /dev/null
then
    echo -e "\e[32mReducer package created\e[39m"
else
    echo -e "\e[31mError creating reducer package\e[39m"
    exit 1
fi


echo "-------------------------"

echo "----Uploading packages...----"

#Upload code for cluster functions to the cluster bucket
rm stderr &> /dev/null
if aws s3 cp mapper.zip s3://$BUCKETIN/$CLUSTERNAME/mapper.zip &> stderr
then
    echo -e "\e[32mMapper code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading mapper code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more stderr    
    exit 1
fi

rm stderr &> /dev/null
if aws s3 cp reducer.zip s3://$BUCKETIN/$CLUSTERNAME/reducer.zip &> stderr
then
    echo -e "\e[32mReducer code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading reducer code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more stderr    
    exit 1
fi

rm stderr &> /dev/null
if aws s3 cp coordinator.zip s3://$BUCKETIN/$CLUSTERNAME/coordinator.zip &> stderr
then
    echo -e "\e[32mCoordinator code upload to $BUCKETIN/$CLUSTERNAME\e[39m"
else
    echo -e "\e[31mError uploading coordinator code to $BUCKETIN/$CLUSTERNAME\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"

echo "###############################"
echo "##COORDINATOR FUNCTION SECTION#"
echo "###############################"

echo "----Creating coordinator function...----"

#Generate cli json for coordinator function
rm coordinator.json &> /dev/null
echo '{' >> coordinator.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-coordinator",' >> coordinator.json
echo '   "Runtime": "python3.6",' >> coordinator.json
echo '   "Role": "'$ROLE'",' >> coordinator.json
echo '   "Handler": "coordinator.handler",' >> coordinator.json
echo '   "Code": {' >> coordinator.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> coordinator.json
echo '      "S3Key": "'$CLUSTERNAME'/coordinator.zip"' >> coordinator.json
#echo '      "S3ObjectVersion": "0.1"' >> coordinator.json
echo '   },' >> coordinator.json
echo '   "Timeout": '$TIMEOUT',' >> coordinator.json
echo '   "MemorySize": '$MEMORY',' >> coordinator.json
#echo '   "Publish": true,' >> coordinator.json
echo '   "Environment": {' >> coordinator.json
echo '       "Variables": {' >> coordinator.json
echo '           "BUCKET": "'$BUCKETIN'",' >> coordinator.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> coordinator.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> coordinator.json
echo '           "MAPPERNUMBER": "'$MAXMAPPERNODES'",' >> coordinator.json
echo '           "MINBLOCKSIZE": "'$MINBLOCKSIZE'",' >> coordinator.json
echo '           "MEMORY": "'$MEMORY'"' >> coordinator.json
echo '       }' >> coordinator.json
echo '   },' >> coordinator.json
echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> coordinator.json
echo '}' >> coordinator.json


#Create lambda coordinator function
rm stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://coordinator.json &> stderr
then
    echo -e "\e[32mLambda coordinator function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda coordinator function.\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for coordinator function...----"


#Add permission to lambda coordinator function
rm stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-coordinator" --statement-id "HC-"$CLUSTERNAME"-coordinator-stateID" --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn "arn:aws:s3:::"$BUCKETIN &> stderr
then
    echo -e "\e[32mPermission to S3 added for coordinator function\e[39m"
else
    echo -e "\e[31mError adding permission to S3 for coordinator function\e[39m"
    more stderr
    exit 1
fi

#Extract coordinator function arn
rm stderr &> /dev/null
if coordinatorARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-coordinator" | grep -o 'arn:aws:lambda:\S*'` &> stderr
then
    echo -e "\e[32mARN of coordinator function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of coordinator function\e[39m"
    more stderr
    exit 1
fi

#Add a bucket notification configuration to "BUCKETIN"

rm coordinator_notification.json &> /dev/null
echo '{' >> coordinator_notification.json
echo '	"LambdaFunctionConfigurations": [' >> coordinator_notification.json
echo '  {' >> coordinator_notification.json
echo '      "Id": "'$BUCKETIN'-'$CLUSTERNAME'-TRIGGERID",' >> coordinator_notification.json
echo '      "LambdaFunctionArn": "'$coordinatorARN'",' >> coordinator_notification.json
echo '      "Events": [' >> coordinator_notification.json
echo '         "s3:ObjectCreated:*"' >> coordinator_notification.json
echo '      ],' >> coordinator_notification.json
echo '      "Filter": {' >> coordinator_notification.json
echo '         "Key": {' >> coordinator_notification.json
echo '             "FilterRules": [' >> coordinator_notification.json
echo '                 {' >> coordinator_notification.json
echo '                    "Name": "prefix",' >> coordinator_notification.json
echo '                    "Value": "'$CLUSTERNAME'/"' >> coordinator_notification.json
echo '                 }' >> coordinator_notification.json
echo '             ]' >> coordinator_notification.json
echo '         }' >> coordinator_notification.json
echo '      }' >> coordinator_notification.json
echo '  }' >> coordinator_notification.json
echo ' ]' >> coordinator_notification.json
echo '}' >> coordinator_notification.json

rm stderr &> /dev/null
if aws s3api put-bucket-notification-configuration --bucket $BUCKETIN --notification-configuration file://coordinator_notification.json &> stderr
then
    echo -e "\e[32mBucket notification configuration added\e[39m"
else
    echo -e "\e[31mError adding bucket notification configuration\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"

echo "###############################"
echo "##  MAPPER FUNCTION SECTION   #"
echo "###############################"

echo "----Creating mapper function...----"

#Generate cli json for mapper function
rm mapper.json &> /dev/null
echo '{' >> mapper.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-mapper",' >> mapper.json
echo '   "Runtime": "python3.6",' >> mapper.json
echo '   "Role": "'$ROLE'",' >> mapper.json
echo '   "Handler": "-mapper---CH.handler",' >> mapper.json
echo '   "Code": {' >> mapper.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> mapper.json
echo '      "S3Key": "'$CLUSTERNAME'/mapper.zip"' >> mapper.json
#echo '      "S3ObjectVersion": "0.1"' >> mapper.json
echo '   },' >> mapper.json
echo '   "Timeout": '$TIMEOUT',' >> mapper.json
echo '   "MemorySize": '$MEMORY',' >> mapper.json
#echo '   "Publish": true,' >> mapper.json
echo '   "Environment": {' >> mapper.json
echo '       "Variables": {' >> mapper.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> mapper.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> mapper.json
echo '           "MEMORY": "'$MEMORY'"' >> mapper.json
echo '       }' >> mapper.json
echo '   },' >> mapper.json
echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> mapper.json
echo '}' >> mapper.json

#Create lambda mapper function
rm stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://mapper.json &> stderr
then
    echo -e "\e[32mLambda mapper function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda mapper function.\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for mapper function...----"

#Add permission to lambda mapper function
rm stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-mapper" --statement-id "HC-"$CLUSTERNAME"-mapper-stateID" --action "lambda:InvokeFunction" --principal lambda.amazonaws.com --source-arn $coordinatorARN &> stderr
then
    echo -e "\e[32mPermission to coordination function added for mapper function\e[39m"
else
    echo -e "\e[31mError adding permission to coordinator function for mapper function\e[39m"
    more stderr
    exit 1
fi

#Extract mapper function arn
rm stderr &> /dev/null
if mapperARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-mapper" | grep -o 'arn:aws:lambda:\S*'` &> stderr
then
    echo -e "\e[32mARN of mapper function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of mapper function\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"


echo "################################"
echo "##  REDUCER FUNCTION SECTION   #"
echo "################################"

echo "----Creating reducer function...----"

#Generate cli json for reducer function
rm reducer.json &> /dev/null
echo '{' >> reducer.json
echo '   "FunctionName": "HC-'$CLUSTERNAME'-lambda-reducer",' >> reducer.json
echo '   "Runtime": "python3.6",' >> reducer.json
echo '   "Role": "'$ROLE'",' >> reducer.json
echo '   "Handler": "-reducer---CH.handler",' >> reducer.json
echo '   "Code": {' >> reducer.json
echo '      "S3Bucket": "'$BUCKETIN'",' >> reducer.json
echo '      "S3Key": "'$CLUSTERNAME'/reducer.zip"' >> reducer.json
#echo '      "S3ObjectVersion": "0.1"' >> reducer.json
echo '   },' >> reducer.json
echo '   "Timeout": '$TIMEOUT',' >> reducer.json
echo '   "MemorySize": '$MEMORY',' >> reducer.json
#echo '   "Publish": true,' >> reducer.json
echo '   "Environment": {' >> reducer.json
echo '       "Variables": {' >> reducer.json
echo '           "BUCKETOUT": "'$BUCKETOUT'",' >> reducer.json
echo '           "PREFIX": "'$CLUSTERNAME'",' >> reducer.json
echo '           "MEMORY": "'$MEMORY'"' >> reducer.json
echo '       }' >> reducer.json
echo '   },' >> reducer.json
echo '   "KMSKeyArn": "'$KMSKEYARN'"' >> reducer.json
echo '}' >> reducer.json

#Create lambda reducer function
rm stderr &> /dev/null
if aws lambda create-function --region $REGION --cli-input-json file://reducer.json &> stderr
then
    echo -e "\e[32mLambda reducer function created on AWS.\e[39m"
else
    echo -e "\e[31mError creating lambda reducer function.\e[39m"
    more stderr
    exit 1
fi

echo "-------------------------"

echo "----Adding permissions for reducer function...----"

#Add permission to lambda mapper function to invoke reducer function
rm stderr &> /dev/null
if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-reducer" --statement-id "HC-"$CLUSTERNAME"-reducer-stateID" --action "lambda:InvokeFunction" --principal lambda.amazonaws.com --source-arn $mapperARN &> stderr
then
    echo -e "\e[32mPermission to mapper function added for reducer function\e[39m"
else
    echo -e "\e[31mError adding permission to mapper function for reducer function\e[39m"
    more stderr
    exit 1
fi

#Extract reducer function arn
rm stderr &> /dev/null
if reducerARN=`aws lambda get-function --function-name "HC-"$CLUSTERNAME"-lambda-reducer" | grep -o 'arn:aws:lambda:\S*'` &> stderr
then
    echo -e "\e[32mARN of reducer function obtained\e[39m"
else
    echo -e "\e[31mError obtaining ARN of reducer function\e[39m"
    more stderr
    exit 1
fi

#Add permission to lambda reducer function to invoke reducer function
#rm stderr &> /dev/null
#if aws lambda add-permission --function-name "HC-"$CLUSTERNAME"-lambda-reducer" --statement-id "HC-"$CLUSTERNAME"-reducer-stateID" --action "lambda:InvokeFunction" --principal lambda.amazonaws.com --source-arn $reducerARN &> stderr
#then
#    echo -e "\e[32mPermission to reducer function added for reducer function\e[39m"
#else
#    echo -e "\e[31mError adding permission to reducer function for reducer function\e[39m"
#    more stderr
#    exit 1
#fi

echo "-------------------------"

echo "Cluster generated succesfully!"
