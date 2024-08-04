import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import explode, col, to_date, date_format
import boto3
from datetime import datetime, timezone

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

bucket = 'fuel-prices-files-bucket'

# Initialise S3 client
s3_client = boto3.client('s3')
glue_client = boto3.client('glue')

def get_last_run_time(job_name, bucket_name):
    file_name = f"{job_name}_last_run_time.txt"
    
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_name)
        last_run_time_str = response['Body'].read().decode('utf-8').split(': ')[1]
        return datetime.fromisoformat(last_run_time_str)
    except s3_client.exceptions.NoSuchKey:
        print("No last run time file found. Using 1970-01-01 as the default date.")
        return datetime(1970, 1, 1).replace(tzinfo=timezone.utc)
    except Exception as e:
        print(f"Error reading last run time from S3: {str(e)}. Using 1970-01-01 as the default date.")
        return datetime(1970, 1, 1).replace(tzinfo=timezone.utc)

last_run_time = get_last_run_time(args['JOB_NAME'], bucket_name=bucket)

def get_current_run_start_time(job_name, job_run_id):
    try:
        response = glue_client.get_job_run(JobName=job_name, RunId=job_run_id)
        current_run_time = response['JobRun']['StartedOn'].replace(tzinfo=timezone.utc)
        file_content = f"Last successful job run: {current_run_time}"
        file_name = f"{job_name}_last_run_time.txt"
        s3_client.put_object(Bucket=bucket, Key=file_name, Body=file_content)
        print(f"Successfully wrote run time to s3://{bucket}/{file_name}")        
        return current_run_time
    except Exception as e:
        print(f"Error getting current run start time: {str(e)}")
        return datetime.now(timezone.utc)

current_run_start_time = get_current_run_start_time(args['JOB_NAME'], args['JOB_RUN_ID'])

# List objects in the bucket
response = s3_client.list_objects_v2(Bucket=bucket)

new_files = []

for obj in response.get('Contents', []):
    if obj['LastModified'].replace(tzinfo=timezone.utc) > last_run_time:
        print(f"New file: {obj['Key']}")
        new_files.append(f"s3://{bucket}/{obj['Key']}")
    else:
        print(f"Old file: {obj['Key']}")

# process new files
for file in new_files:
    try:
        # Read data from S3 into a Dynamic Frame
        dyf = glueContext.create_dynamic_frame.from_options(
            format_options={"multiline": True},
            connection_type="s3",
            format="json",
            connection_options={
                "paths": [file],
                "recurse": True,
                "useS3ListImplementation": True
            },
            transformation_ctx="read_json_from_s3"
        )
        df = dyf.toDF()
        # Flatten the nested 'stations' array
        df_exploded = df.withColumn("station", explode(col("stations")))
        # Select and rename columns
        df_flattened = df_exploded.select(
            col("last_updated"),
            col("station.site_id"),
            col("station.brand"),
            col("station.address"),
            col("station.postcode"),
            col("station.location.latitude").alias("latitude"),
            col("station.location.longitude").alias("longitude"),
            col("station.prices.B7").alias("price_B7"),
            col("station.prices.E10").alias("price_E10"),
            col("station.prices.E5").alias("price_E5"),
            col("station.prices.SDV").alias("price_SDV")
        ).withColumn("last_updated_date", to_date("last_updated")).withColumn("last_updated_time", date_format("last_updated", "HH:mm:ss"))

        # Convert back to Dynamic Frame
        flattened_dynamic_frame = DynamicFrame.fromDF(df_flattened, glueContext, "flattened_data")
        # Write the processed data to a new S3 location
        glueContext.write_dynamic_frame.from_options(
            frame=flattened_dynamic_frame,
            connection_type="s3",
            format="parquet",
            connection_options={
                "path": "s3://fuel-prices-processed-bucket/",
                "partitionKeys": ["last_updated_date"]
            },
            transformation_ctx="write_to_s3"
        )
        print(f"Processed file: {file}")
    except Exception as e:
        print(f"Error processing file {file}: {e}")

job.commit()