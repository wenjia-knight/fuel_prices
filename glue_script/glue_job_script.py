import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import explode, col, to_date, date_format, lit
from pyspark.sql.types import DoubleType
import boto3
from datetime import datetime, timezone

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# S3 bucket that contains the raw data
bucket = 'fuel-prices-files-bucket'

# Initialise s3 and glue clients
s3_client = boto3.client('s3')
glue_client = boto3.client('glue')

# Function to get the last run time from text file saved in S3
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

# Function to get the current run start time from Glue job run and use it to update the last run time file in S3
def get_current_run_start_time(job_name, job_run_id):
    try:
        response = glue_client.get_job_run(JobName=job_name, RunId=job_run_id)
        current_run_start_time = response['JobRun']['StartedOn'].replace(tzinfo=timezone.utc)
        file_content = f"Last successful job run: {current_run_start_time}"
        file_name = f"{job_name}_last_run_time.txt"
        s3_client.put_object(Bucket=bucket, Key=file_name, Body=file_content)
        print(f"Successfully wrote job run start time {current_run_start_time} to s3://{bucket}/{file_name}")        
        return current_run_start_time
    except Exception as e:
        print(f"Error getting current job run start time: {str(e)}. Use current time as the start time.")
        return datetime.now(timezone.utc)

last_run_time = get_last_run_time(args['JOB_NAME'], bucket_name=bucket)
current_run_start_time = get_current_run_start_time(args['JOB_NAME'], args['JOB_RUN_ID'])

# List objects in the bucket
response = s3_client.list_objects_v2(Bucket=bucket)

new_files = []

# Filter out files that are created after the last run time
for obj in response.get('Contents', []):
    if obj['LastModified'].replace(tzinfo=timezone.utc) > last_run_time:
        print(f"New file: {obj['Key']}")
        new_files.append(f"s3://{bucket}/{obj['Key']}")
    else:
        print(f"Old file: {obj['Key']}")

# process the new files
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

        # Extract schema of the 'station' field
        station_schema = df_exploded.schema["station"].dataType

        # Initialise the columns to be selected
        selected_columns = [
            col("last_updated"),
            col("station.site_id"),
            col("station.brand"),
            col("station.address"),
            col("station.postcode"),
            col("station.location.latitude").cast(DoubleType()).alias("latitude"),
            col("station.location.longitude").cast(DoubleType()).alias("longitude")
        ]
        # Add the price columns if they exist
        price_columns = ["B7", "E10", "E5", "SDV"]
        # Fill missing price columns with nulls
        for price_col in price_columns:
            if price_col in station_schema["prices"].dataType.fieldNames():
                selected_columns.append(col(f"station.prices.{price_col}").alias(f"price_{price_col}"))
            else:
                selected_columns.append(lit(None).cast("double").alias(f"price_{price_col}"))

        df_flattened = df_exploded.select(*selected_columns).withColumn("last_updated_date", to_date("last_updated")).withColumn("last_updated_time", date_format("last_updated", "HH:mm:ss"))
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