# MARLA - MApReduce on AWS Lambda

MARLA is a tool to create and configure a serverless MapReduce processor on AWS by means of a set of Lambda functions created on AWS Lambda. Files are uploaded to Amazon S3 and this triggers the execution of the functions using the user-supplied Mapper and Reduce functions.

# Installation

MARLA requires:

* An AWS account
* AWS CLI (version 1.11.76+), used to create the Lambda functions and S3 buckets
* An IAM Role on AWS with permissions to create, delete and list keys on the used S3 buckets and permissions to invoke Lambda functions. See an example of such an IAM role in the [examples/iam-role.json](examples/iam-role.json) file.

The code of the Lambda functions and user-defined Mapper and Reduce functions is written in Python. 

MARLA can be retrieved by issuing this command:

  `git clone https://github.com/grycap/marla`

# Usage

First you need to create your own Mapper and Reduce functions in the same file (as shown in the  [example/example_functions.py](example/example_functions.py) file). 

This functions must satisfy some constraints, explained below.

## Mapper Function

The mapper function must adhere to the following signature:

  `def mapper(chunk, Pairs):`
  
where `chunk` is the raw text from the input file to be mapped and `Pairs` is initially an empty list.

 After executing the mapper function, `Pairs` must store the name-value pairs respectively. That is, a list of 2D tuples with the pairs name-value (`Pair[i][0]` correspond to names, `Pairs[i][1]` correspond to values) extracted in the mapper function.
 
 
## Reducer Function

The reducer function must adhere to the following signature:
  
  `def reducer(Pairs, Results):`
  
 where `Pairs` is a list of 2D tuples with the pairs name-value (in the same format of the mapper function) extracted in the mapper function. `Pairs` is sorted alphabetically by names. `Result` is an initially empty 2D list. 
 
 After executing the reduce function, `Result` must store a list of name-value pairs (`Results[i][0]` store names, `Results[i][1]` store values).
 
 
## Configuration
 
 In addition to the aforementioned functions, the user must specify some parameters in a configuration file. This configuration file must follow the structure of the provided example [examples/config.in](examples/config.in). The order of the keys is not important and its meaning is explained here: 
 
  * ClusterName: An identified for this "Lambda cluster".
  
  * FunctionsDir: The directory containing the file that defines the Mapper and Reduce functions.
  
  * FunctionsFile: The name of the file with the Mapper and Reduce functions.
  
  * Region: The AWS region where the AWS Lambda functions will be created.
  
  * BucketIn: The bucket for input files. It must exist.
  
  * BucketOut: The bucket for output files. We strongly recommend using diferent buckets for input and output to avoid unwanted recursions.
  
  * RoleARN: The ARN of the role under which the Lambda functions will be executed.
  
  * MapperNodes: The desired number of concurrent mapper functions.
  
  * MinBlockSize: The minimum size, in KB, of text that  every mapper will process.
   
  * KMSKeyARN: The ARN of KMS key used to encript environment variables.
  
  * Memory: The memory of the Lambda functions. The maximum text size to process by every Mapper will be restricted by this amount of memory.
  
  * TimeOut: The elapsed time for a Lambda function to run before terminating it.
 
 
## Creating and Processing the Data
 
 Once fulfilled the previous steps, assumming that you modified the `config.in` file in the `example` directory, issue:

 `$ sh marla_create.sh example/config.in`
 
 where `config.in` is the path to the configuration file. 
 
 The script will create and configure the Lambda functions and add permissions to the S3 buckets. If the script finishes succesfully, you will find a folder with the cluster name in the bucket specified in configuration file, such as this one: `BucketIn/ClusterName`
 
Every file you upload in this folder will be processed via MapReduce. The output of the MapReduce process will be stored in the `BucketOut` S3 bucket in the following path: `BucketOut/ClusterName/NameFile/results`

where `NameFile` is the name of the uploaded input file without the extension (for example .txt) and "results" is the file with the MapReduce results.

## Deleting

To remove a "Lambda cluster", use the script "marla_remove.sh" with the name of "cluster"

`$ sh marla_remove.sh ClusterName`

This will remove all the created Lambda functions, but not the files in S3.
