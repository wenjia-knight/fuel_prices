import requests
import boto3
import json
from datetime import datetime

# Set up S3 client
s3 = boto3.client("s3")

# check if file already exists in S3 bucket
def is_file_exists(bucket_name, key):
    try:
        s3.head_object(Bucket=bucket_name, Key=key)
        return True
    except s3.exceptions.ClientError:
        return False
    
# extract retailer name from URL    
def extract_retailer(url):
    domain_parts = url.split('//')[1].split('/')[0].split('.')
    for i, part in enumerate(domain_parts):
        if part in ('com', 'co', 'uk'):
            return domain_parts[i - 1]
    return "unknown_retailer"

# Convert dd/mm/yyyy hh:mm:ss to yyyy-mm-dd hh:mm:ss format
def parse_date(date_string):
    dt = datetime.strptime(date_string, '%d/%m/%Y %H:%M:%S')
    return dt.strftime('%Y-%m-%d %H:%M:%S')

def download(url):
    try:
        response = requests.get(url,timeout=2)
        response.raise_for_status()

        data = response.json()

        data["last_updated"] = parse_date(data["last_updated"])

        last_updated = data["last_updated"].replace(" ", "T")

        retailer = extract_retailer(url)
        file_name = f"{retailer}_fuel_prices_{last_updated}.json"
        bucket_name = "fuel-prices-files-bucket"

        if is_file_exists(bucket_name, file_name):
            print(f"File {file_name} already exists in {bucket_name}. Skipping upload.")
        else:
            s3.put_object(Bucket=bucket_name, Key=file_name, Body=response.content, ContentType='application/json')
            print(f"Uploaded {file_name} to {bucket_name}")

    except requests.exceptions.Timeout:
        print(f"Request timed out error for {url}")
    except requests.exceptions.RequestException as e:
        print(f"Request failed for {url}: {e}")
    except Exception as e:
        print(f"An error occurred while downloading {url}: {e}")

def download_all(urls):
    for url in urls:
        download(url)

def lambda_handler(event, context):
    urls = [
        "https://applegreenstores.com/fuel-prices/data.json",
        "https://fuelprices.asconagroup.co.uk/newfuel.json",
        "https://storelocator.asda.com/fuel_prices_data.json",
        "https://www.bp.com/en_gb/united-kingdom/home/fuelprices/fuel_prices_data.json",
        "https://fuelprices.esso.co.uk/latestdata.json",
        "https://jetlocal.co.uk/fuel_prices_data.json",
        "https://www.morrisons.com/fuel-prices/fuel.json",
        "https://moto-way.com/fuel-price/fuel_prices.json",
        "https://fuel.motorfuelgroup.com/fuel_prices_data.json",
        "https://www.rontec-servicestations.co.uk/fuel-prices/data/fuel_prices_data.json",
        "https://api.sainsburys.co.uk/v1/exports/latest/fuel_prices_data.json",
        "https://www.sgnretail.uk/files/data/SGN_daily_fuel_prices.json",
        "https://www.shell.co.uk/fuel-prices-data.html",
        "https://www.tesco.com/fuel_prices/fuel_prices_data.json"
    ]
    download_all(urls=urls)
