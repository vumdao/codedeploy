import boto3
from chalice import Chalice
import json
import time
import re


app = Chalice(app_name='codedeploy')
app.debug = True
log_url = "https://ap-northeast-2.console.aws.amazon.com/codesuite/codedeploy/deployments"


class Deployment:
    def __init__(self):
        region = 'ap-northeast-2'
        self.client = boto3.client("codedeploy", region_name=region)
        self.instance_id = 'i-1111c11e1d6cc11ae'
        self.s3_bucket = "codedeploy"

    def get_deployment_instance(self, deployment_id):
        """ Loop all lifecycleEvents to find which one failed """
        resp = self.client.get_deployment_instance(deploymentId=deployment_id,
                                                   instanceId=self.instance_id)
        summary = resp['instanceSummary']
        for event in summary['lifecycleEvents']:
            if event['status'] == 'Failed':
                return event['diagnostics']['message']

    def create_deployment(self, app_name, s3_object, group_name):
        app.log.debug("Create deployment for: %s, group: %s", s3_object, group_name)
        res = self.client.create_deployment(applicationName=app_name,
                                            deploymentGroupName=group_name,
                                            revision={
                                                'revisionType': 'S3',
                                                's3Location': {
                                                    'bucket': self.s3_bucket,
                                                    'key': s3_object,
                                                    'bundleType': 'zip'
                                                }
                                            },
                                            deploymentConfigName='CodeDeployDefault.OneAtATime',
                                            description='Lambda invoked codedeploy deployment',
                                            fileExistsBehavior='OVERWRITE')

        """ Wait until the deployment finish """
        failed_states = ['Failed', 'Stopped']
        while True:
            respond = self.client.get_deployment(deploymentId=str(res['deploymentId']))
            deployment_status = respond['deploymentInfo']['status']
            if deployment_status == "Succeeded":
                app.log.debug("Deployment Succeeded")
                break
            elif deployment_status in failed_states:
                error_log = self.get_deployment_instance(str(res['deploymentId']))
                app.log.debug("Deployment failed\n{}".format(error_log))
                break
            else:
                time.sleep(3)
                continue


@app.on_s3_event(bucket='codedeploy',
                 suffix='.zip',
                 events=['s3:ObjectCreated:Put'])
def handle_s3_event(event):
    app.log.debug("Received event for bucket: %s, key: %s", event.bucket, event.key)
    app_name = 'myapp'
    group_name = 'mygroup'

    deploy = Deployment()
    deploy.create_deployment(app_name, event.key, group_name)
