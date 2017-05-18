# marla
MApReduce on AWS Lambda

Marla (MApReduce on AWS Lambda) is a tool to create and configure a serverless map-reduce processor on AWS using Lambda functions. Once created, will process the files entered in a S3 speceficic folder automatically. For that purpose, use user predefined mapper and reduce function.

# Installation

The program requires an account on AWS, AWS cli, which is used to lunch and configure Lambda functions and S3 buckets, and a "role" on AWS with permisions to create, delete and list keys on the used S3 buckets and permissions to invoke Lambda functions.

Although the code of Lambda functions and user mapper and reduce functions is written in python, marla doesn't need python to run. This is because the entire code will run on AWS.

`marla` can be download from `this <https://github.com/grycap/marla>`_ git repository::

  `git clone https://github.com/grycap/marla`
  

# How to use

First you need to create your own mapper and reduce functions in the same file. In the "example" folder you can see an example. This functions must meet few design constraints. We explain them below.

## Mapper

The mapper function must respect the below signature:

  `def mapper(chunk, Names, Values):`
  
where "chunck" is the raw text from the input file to be mapped and "Names" and "Values" are a initially empty lists. At the end of mapper function, "Names" and "Values" must store the pairs name-value respectively. That is, the first name stored in "Names[0]" is assosiated with the first value stored in "Values[0]" and so on. Obviously the user can modify the name of the variables, but not the name of the function.

## Reducer

The reducer function must respect the below signature:
  
  `def reducer(Pairs, Results):`
  
 where "Pairs" is a list of 2D tuples with the pairs name-value (Pairs[i][0] correspond to names, Pairs[i][1] correspond to values) extracted in the mapper function. "Pairs" is sorted alphabetically by names. "Results" is an initially empty 2D list. At the finish of reduce function, "Results" must store a list of name-value pairs (Results[i][0] store names, Results[i][1] store values). 
 
 This functions will be writed in the same file and stored in a directory with all this dependences, excluding installed dependences in AWS environment.
 
## Configuration
 
 In addition to the previous functions, the user must especify some parameters in a configuration file. This configuration file must use the structure of the example "config.in". The order of keys is not important. The keys to introduce are the following:
 
  * ClusterName: A ID for this "Lambda cluster".
  
  * FunctionsDir: The directory where the mapper and reduce functions file is.
  
  * FunctionsFile: The name of the file with the user mapper and reduce functions.
  
  * Region: The region to use in aws.
  
  * BucketIn: The bucket for input files. Must exist
  
  * BucketOut: The bucket for output files. We strongly recommend to use diferents buckets for input and output. Must exist.
  
  * RoleARN: The ARN of the role used to create lambda functions.
  
  * MapperNodes: The desired concurrent mapper functions.
  
  * MinBlockSize: The minimum size, in KB, of text that will process every mapper.
   
  * KMSKeyARN: The ARN of KMS key used to encript environment variables.
  
  * Memory: The memory of the lambda functions. The maximum text size to proces in every mapper will be restricted by this memory.
  
  * TimeOut: The maximum time a single lambda function runs.
 
 
## Create and Process data
 
 When the previous steps was done, use
 
 `$ bash marla_create.sh config.in`
 
 where "config.int" must be the path to the configuration file. The script will create and configure lambda functions and add permissions to the S3 buckets. If the script finish succesfully, you can see a folder with the cluster name in the bucket specified in configuration file like this
 
 `BucketIn/ClusterName`
 
Every file you introduce in this folder will be processed. The output of the map reduce will be stored in the "BucketOut" S3 bucket in the following path

`BucketOut/ClusterName/NameFile/results`

where "NameFile" is the name of the uploaded input file without the extension (for example .txt) and "results" is the file with re map-reduce results.  

## Removing

To remove a "Lambda cluster", use script "marla_remove.sh" with the name of "cluster"

`$ bash marla_remove.sh ClusterName`

This will remove lambda functions from aws, but not the files in S3.
