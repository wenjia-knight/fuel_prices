import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime
import boto3

# Set up S3 client
s3 = boto3.client("s3")

def get_station_data(url):
        response = requests.get(url)
        if response.status_code != 200:
            print(f"Failed to fetch the webpage for {url}. Status code: {response.status_code}")
            return None
        
        # 2. Parse the webpage using BeautifulSoup
        soup = BeautifulSoup(response.text, 'html.parser')
        # 3. Extract address and postcode
        try:
            contact_section = soup.find('div', class_='col-xs-12 col-sm-4 col-md-5 no-padding')
            address_lines = [span.text.strip() for span in contact_section.find_all('span') if not span.find('a')]
            postcode = address_lines.pop()  # Extract the last line as the postcode
            address = ", ".join(address_lines)
        except AttributeError:
            print("Failed to find contact details.")

        # 4. Extract fuel prices based on the new structure
        fuel_prices = {}
        try:
            price_boxes = soup.find_all('div', class_='col-xs-3 gas-box-padding')
            for box in price_boxes:
                fuel_type = box.find('span', class_='gas-title').text.strip()
                price = box.find('span', class_='gas-price').text.strip()
                if fuel_type == "Unleaded Petrol":
                    fuel_prices["E10"] =float(price)
                if fuel_type == "Premium Diesel":
                    fuel_prices["SDV"] =float(price)
                if fuel_type == "Premium Unleaded Petrol":
                    fuel_prices["E5"] =float(price)
                
        except AttributeError:
            print("Failed to extract fuel prices.")

        try:
            map_section = soup.find('div', class_='store-finder-map')
            latitude = float(map_section['data-latitude'])
            longitude = float(map_section['data-longitude'])
        except (AttributeError, KeyError):
            latitude = longitude = 'Coordinates not found'
            print(f"Failed to extract coordinates for URL: {url}")

        # 5. Prepare the data for a single station
        station_data = {
            "site_id": url.split('/')[-1],
            "brand": "Costco",
            "address": address,
            "postcode": postcode,
            "location": {
                "latitude": latitude,
                "longitude": longitude
            },  
            "prices": fuel_prices
        }

        return station_data

def get_data(urls: list):
    all_data = []   
    for url in urls:
        station_data = get_station_data(url)
        if station_data:
            all_data.append(station_data)
    return all_data 

def get_final_data(data: list):
    final_data = {
        "last_updated": datetime.now(),
        "stations": data
    }
    return final_data

def lambda_handler(event, context):
    urls = [
        "https://www.costco.co.uk/store-finder/Oldham",
        "https://www.costco.co.uk/store-finder/Manchester",
        "https://www.costco.co.uk/store-finder/Haydock",
        "https://www.costco.co.uk/store-finder/Leeds",
        "https://www.costco.co.uk/store-finder/Liverpool",
        "https://www.costco.co.uk/store-finder/Chester",
        "https://www.costco.co.uk/store-finder/Sheffield",
        "https://www.costco.co.uk/store-finder/Derby",
        "https://www.costco.co.uk/store-finder/Gateshead",
        "https://www.costco.co.uk/store-finder/Birmingham",
        "https://www.costco.co.uk/store-finder/Leicester",
        "https://www.costco.co.uk/store-finder/Coventry",
        "https://www.costco.co.uk/store-finder/Edinburgh",
        "https://www.costco.co.uk/store-finder/Glasgow",
        "https://www.costco.co.uk/store-finder/Bristol",
        "https://www.costco.co.uk/store-finder/Stevenage",
        "https://www.costco.co.uk/store-finder/Watford",
        "https://www.costco.co.uk/store-finder/Reading",
        "https://www.costco.co.uk/store-finder/Thurrock",
        "https://www.costco.co.uk/store-finder/Southampton"
    ]
    stations_data = get_data(urls)
    final_data = get_final_data(data=stations_data)
    # last_updated_dt = final_data["last_updated"]
    last_updated = final_data["last_updated"].strftime('%Y-%m-%d %H:%M:%S')
    formatted_last_updated = last_updated.replace(' ', 'T')

    file_key = f"costco_fuel_prices_{formatted_last_updated}.json"
    bucket_name = "fuel-prices-raw-bucket-wk"
        # Upload JSON data to S3
    final_data["last_updated"] = last_updated
    s3.put_object(Bucket=bucket_name, Key=file_key, Body=json.dumps(final_data), ContentType='application/json')
    print(f"Uploaded {file_key} to {bucket_name}")
