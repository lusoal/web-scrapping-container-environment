import boto3
from flask import Flask, render_template, request
import os

app = Flask(__name__)

DYNAMO_DB_TABLE=os.getenv("DYNAMO_DB_TABLE")

def scan_dynamo_table(table_name):
    client = boto3.client('dynamodb')
    
    response = client.scan(TableName=table_name)
    ip_list = []
    url_list = []
    
    for item in response.get("Items"):
        ip = (item.get("IP").get("S"))
        url = item.get("SCRAPE").get("S")
        
        ip_list.append(ip)
        url_list.append(url)
    
    unique_urls = list(set(url_list))
    dict_unique_urls = {}
    # ip_list_final = list(set(ip_list))
    
    for u in unique_urls:
        dict_unique_urls[u] = url_list.count(u)
        
    

    return dict_unique_urls, ip_list
    

@app.route('/', methods=['GET', 'POST'])
def index():
    dict_unique_urls, ip_list = scan_dynamo_table(DYNAMO_DB_TABLE)
    
    unique_ips_number = len(set(ip_list))
    
    ip_duplicate=[]
    ip_duplicate_2=[]
    
    for i in ip_list:
        if i not in ip_duplicate:
            ip_duplicate.append(i)
        else:
            ip_duplicate_2.append(i)
    
    
    
    if request.method == "GET":
        return render_template('index.html', ip_list = ip_list, dict_unique_urls = dict_unique_urls, 
                               unique_ips_number = unique_ips_number, duplicate_ips = len(ip_duplicate_2))
        

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)