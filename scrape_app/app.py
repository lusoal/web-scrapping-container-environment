import requests
# from flask import Flask, jsonify, request
import boto3
import os

# app = Flask(__name__)
BUCKET_NAME = os.getenv("BUCKET_NAME") # TBD: Change to env var
URL = os.getenv("URL")
TABLE_NAME = os.getenv("TABLE_NAME")


def add_item_dynamo_db(table_name, item):
    client = boto3.client('dynamodb')
    ip = item.get("IP")
    object = item.get('Object')
    try:
        response = client.put_item(
            TableName=table_name,
            Item={'IP' : {'S' : ip}, 'SCRAPE' : {'S' : object}},
            ConditionExpression="attribute_not_exists(IP) AND attribute_not_exists(SCRAPE)")
        print(response)
    
    except Exception as e:
        print(e)
        response = client.get_item(
            TableName=table_name,
            Key={'IP' : {'S' : ip}, 'SCRAPE' : {'S' : object}})
        
        count_ip = dict(response).get("Item").get("COUNT")
        
        if count_ip:
            count_ip = int(count_ip.get('N')) + 1
        else:
            count_ip = 1
        
        response = client.put_item(
            TableName=table_name,
            Item={'IP' : {'S' : ip}, 'SCRAPE' : {'S' : object}, 'COUNT' : {'N' : str(count_ip)}})
        

def upload_to_s3(file_path, bucket_name, file_name, ip):
    try:
        metadata = {
            "Content-Type": "text/html",
            "IP" : ip
        }
        client = boto3.client("s3")
        
        upload_response = client.upload_file(file_path, bucket_name, file_name,
                        ExtraArgs={'Metadata': {'REQUEST_IP': ip}})
        return f"Upload file {file_name} succeded"
    except Exception as e:
        raise e
    
    

# @app.route('/scrape', methods=['POST'])
def web_scrapping_url():
    try:
        # content = request.get_json()
        # url = content.get("url")

        page = requests.get(URL)
        print("Request Succeded")
        ip = requests.get('https://api.ipify.org').text
        html_content = page.text
        
        file_name = str((str(URL).split("://")[1]).replace("/", "-")) + "content.html"
        file_path = str(f"/tmp/{file_name}")
        
        f = open(file_path, "w")
        f.write(html_content)
        f.close()
        
        upload_to_s3(file_path, BUCKET_NAME, file_name, ip)
        
        # return jsonify({"IP" : ip})
        response = {"IP" : ip, "Object" : URL}
        print(response)
        return response
    except Exception as e:
        # return jsonify({"Error" : str(e)}), 502
        print({"Error" : str(e)})
        raise e
        
def main():
    response = web_scrapping_url()
    # TABLE_NAME = "web-scrapping-final"
    # response = {"IP":"35.174.115.84", "Object" : "https://www.google.com"}
    add_item_dynamo_db(TABLE_NAME, response)

if __name__ == '__main__':
    #Host resposavel para servir o trafego alem do localhost
    # app.run(debug=True, host='0.0.0.0')
    main()
