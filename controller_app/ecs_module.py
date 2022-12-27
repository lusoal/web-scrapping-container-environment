import boto3

def connect_to_ecs():
    
    client = boto3.client('ecs')
    
    return client

def run_ecs_task_fargate(cluster_name, public_subnets, security_groups, 
                         public_ip="ENABLED", bucket_name="", url="", table_name="", task_definition=""):
    
    try:
        client = connect_to_ecs()
        print(f"Running {url} task on ECS + Fargate")
        response = client.run_task(
        cluster=cluster_name,
        count=1,
        enableECSManagedTags=True,
        # enableExecuteCommand=True,
        launchType='FARGATE',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': public_subnets,
                'securityGroups': security_groups,
                'assignPublicIp': public_ip
            }
        },
            overrides={
                'containerOverrides': [
                    {
                        'name' : "web-scrapping",
                        'environment': [
                            {
                                'name': 'BUCKET_NAME',
                                'value': bucket_name
                            },
                            {
                                'name': 'URL',
                                'value': url
                            },
                            {
                                'name': 'TABLE_NAME',
                                'value': table_name
                            }
                        ]
                    }
                ]
            },
            startedBy='web-scrapper-controller',
            tags=[
                {
                    'key': 'URL',
                    'value': url
                },
            ],
            taskDefinition=task_definition
        )
    except Exception as e:
        print(e)
        pass
        



# bucket_name = "webscrapping-test-demonstration"
# table_name = "web-scrapping-final"
# url = "https://amazon.com"
# cluster_name = "ecs-cluster-webscrapping"
# public_subnets = ["subnet-0c591e87ef00d9e51", "subnet-05bb81b89858da204", "subnet-07dff4412222c5fd9"]
# security_groups = ["sg-06333c7149c88fe3b"]
# task_definition = "web-scrapping-app:1"

# run_ecs_task_fargate(cluster_name, public_subnets, security_groups,
#                      bucket_name=bucket_name, url=url, table_name=table_name, task_definition=task_definition)