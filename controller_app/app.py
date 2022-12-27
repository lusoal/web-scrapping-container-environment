from flask import Flask, render_template, request
from kubernetes_module import *
import os
from ecs_module import *

app = Flask(__name__)

EKS_CLUSTER_NAME=os.getenv("EKS_CLUSTER_NAME")
ECS_CLUSTER_NAME=os.getenv("ECS_CLUSTER_NAME")
SCRAPE_IMAGE_URI=os.getenv("SCRAPE_IMAGE_URI")
BUCKET_NAME=os.getenv("BUCKET_NAME")
DYNAMO_DB_TABLE_NAME=os.getenv("DYNAMO_DB_TABLE_NAME")
AWS_REGION=os.getenv("AWS_DEFAULT_REGION")

PUBLIC_SUBNETS=os.getenv("PUBLIC_SUBNETS").split(",")
SECURITY_GROUPS=os.getenv("SECURITY_GROUPS")
TASK_DEFINITION=os.getenv("TASK_DEFINITION")

# Replace vars in Pod Template
def replace_in_file(file_name, pod_name, image_uri, bucket_name, url, table_name):
    file_path = "./manifests/00-pod.yaml"
    with open(file_path, 'r') as file :
        filedata = file.read()
        
    filedata = filedata.replace('__POD_NAME__', pod_name)
    filedata = filedata.replace('__IMAGE_URI__', image_uri)
    filedata = filedata.replace('__BUCKET_NAME__', bucket_name)
    filedata = filedata.replace('__REPLACE_URL__', url)
    filedata = filedata.replace('__TABLE_NAME__', table_name)
    
    # Write the file out again
    with open(f"/tmp/{file_name}", 'w') as file:
        file.write(filedata)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == "GET":
        return render_template('index.html')


@app.route('/launch_scrape', methods=['POST'])
def launch_scrape():
    urls = request.form.get('url')
    runtime = request.form.get('runtime')
    
    url_list = (urls).splitlines()
    
    for url in url_list:
        # TBD: Reply and apply Kubernetes manifests
        file_name = str((str(url).split("://")[1]).replace("/", "-"))
        pod_name = file_name.replace(".", "-")
        file_name = file_name.replace(".", "-") + ".yaml"
        
        image_uri = SCRAPE_IMAGE_URI
        bucket_name = BUCKET_NAME
        table_name = DYNAMO_DB_TABLE_NAME
        
        if runtime == "EKS":
            # Replace file to apply in k8s
            replace_in_file(file_name, pod_name, image_uri, 
                            bucket_name, url, table_name)
            
            # TBD Get those vars from env
            apply_manifest(EKS_CLUSTER_NAME, AWS_REGION, f"/tmp/{file_name}")
            os.remove(f"/tmp/{file_name}")

        elif runtime == "ECS":
            cluster_name = ECS_CLUSTER_NAME
            public_subnets = PUBLIC_SUBNETS
            security_groups = [SECURITY_GROUPS]
            task_definition = TASK_DEFINITION

            run_ecs_task_fargate(cluster_name, public_subnets, security_groups,
                                bucket_name=bucket_name, url=url, table_name=table_name, task_definition=task_definition)
    
    return render_template('index.html', value="Request Sent")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)