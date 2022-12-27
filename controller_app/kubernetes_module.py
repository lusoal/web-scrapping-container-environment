import eks_token
import boto3
import tempfile
import base64
import kubernetes
import requests
import time


def _write_cafile(data: str) -> tempfile.NamedTemporaryFile:
    # protect yourself from automatic deletion
    cafile = tempfile.NamedTemporaryFile(delete=False)
    cadata_b64 = data
    cadata = base64.b64decode(cadata_b64)
    cafile.write(cadata)
    cafile.flush()
    return cafile

def k8s_api_client(endpoint: str, token: str, cafile: str) -> kubernetes.client.CoreV1Api:
    kconfig = kubernetes.config.kube_config.Configuration(
        host=endpoint,
        api_key={'authorization': 'Bearer ' + token}
    )
    kconfig.ssl_ca_cert = cafile
    kclient = kubernetes.client.ApiClient(configuration=kconfig)
    return kubernetes.client.CoreV1Api(api_client=kclient), kclient

def get_yaml_files(url):
    URL = url
    response = requests.get(URL)
    path_file = "/tmp/deployment.yaml"
    open(path_file, "wb").write(response.content)
    return path_file


def apply_manifest(cluster_name, region_name, manifest_path):
    responseData = {}
    
    cluster_name = cluster_name
    region_name = region_name
    
    try:
        my_token = eks_token.get_token(cluster_name)
        
        bclient = boto3.client('eks', region_name=region_name)
        cluster_data = bclient.describe_cluster(name=cluster_name)['cluster']
        my_cafile = _write_cafile(cluster_data['certificateAuthority']['data'])
        
        # yaml_url = "https://gist.githubusercontent.com/lusoal/cfec2144e81ed8aeb1968752b77093f2/raw/fb6743e180074d211a153743b485a2130dfd7610/deployment-file.yaml"
        
        api_client, kclient = k8s_api_client(
            endpoint=cluster_data['endpoint'],
            token=my_token['status']['token'],
            cafile=my_cafile.name
        )
        
        kubernetes.utils.create_from_yaml(kclient, manifest_path)
        
        # time.sleep(5)
        # ELB_DNS_ENDPOINT = ""
        
        # services = api_client.list_namespaced_service("default")
        # for service in services.items:
        #     if service.status.load_balancer.ingress:
        #         ELB_DNS_ENDPOINT=(service.status.load_balancer.ingress[0].hostname)
        
        # responseData['Data'] = ELB_DNS_ENDPOINT
        
        # print(ELB_DNS_ENDPOINT)
        # cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, "CustomResourcePhysicalID")
        return f"Created Resources {manifest_path}"
    except Exception as e:
        responseData['Error'] = str(e)
        # cfnresponse.send(event, context, cfnresponse.FAILED, responseData, 'CustomResourcePhysicalID')
        raise e