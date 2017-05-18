 
CLUSTERNAME=$1

rm stderr &> /dev/null
if aws lambda delete-function --function-name HC-$CLUSTERNAME-lambda-mapper
then
    echo "Mapper function removed from cluster '$CLUSTERNAME'"
else
    echo "Error removing mapper function from cluster '$CLUSTERNAME'"
    more stderr
    exit 1
fi

rm stderr &> /dev/null
if aws lambda delete-function --function-name HC-$CLUSTERNAME-lambda-reducer
then
    echo "Reducer function removed from cluster '$CLUSTERNAME'"
else
    echo "Error removing reducer function from cluster '$CLUSTERNAME'"
    more stderr
    exit 1
fi


rm stderr &> /dev/null
if aws lambda delete-function --function-name HC-$CLUSTERNAME-lambda-coordinator
then
    echo "Coordinator function removed from cluster '$CLUSTERNAME'"
else
    echo "Error removing coordinator function from cluster '$CLUSTERNAME'"
    more stderr
    exit 1
fi
