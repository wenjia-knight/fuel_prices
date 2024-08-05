# Data Engineering Fuel Prices Project
## Overview
This project aims to securely manage, streamline, and perform analysis on the semi-structured daily fuel prices data.

## Project Components 
1. Data Ingestion — Ingest data daily from a list of URLs into storage.
2. ETL Pipeline — Get data in raw format, transforming this data into a format that can be used for further analysis.
3. Data lake — A centralized repo to store semi-structured date and processed data.
4. Cloud — As the data increases daily, local computer will not be able to process the data. So we will use AWS for scalability.
5. Infrastructure as Code - Terraform is an Infrastructure as Code tool to define cloud resources in a human-readable configuration files. All the resources in AWS in this project is deployed using Terraform.
6. Reporting — Build a dashboard to give business insights.

## Services used
1. Amazon S3: To store raw data obtained daily from a list of URLs, and also store the data after it's been processed.
2. AWS IAM: AWS Identity and Access Management which enables us to manage access to AWS services and resources securely.
3. AWS Lambda: Lambda is a computing service that allows programmers to run code without creating or managing servers.
4. AWS Glue: A serverless data integration service that makes it easy to discover, prepare, and combine data for analytics, machine learning, and application development.
5. AWS Athena: Athena is an interactive query service so we can query data stored in S3 directly without a database.
