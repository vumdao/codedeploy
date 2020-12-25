## Create CodeDeploy
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/wy2s887614g22graauax.jpg)

- AWS CodeDeploy is a fully managed deployment service that automates software deployments to a variety of compute services such as Amazon EC2, AWS Fargate, AWS Lambda, and your on-premises servers.

- AWS CodeDeploy makes it easier for you to rapidly release new features, helps you avoid downtime during application deployment, and handles the complexity of updating your applications.

- You can use AWS CodeDeploy to automate software deployments, eliminating the need for error-prone manual operations. The service scales to match your deployment needs.

![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/qtztr5t4rxtaaw4g3kur.png)

###**1. Install codedeploy-agent on EC2 target machine**
- Enter the instance and follow steps from [Install the CodeDeploy agent for Amazon Linux](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-linux.html)

- Notes: Need to add S3 GetObject policy to the instance in order to download codedeploy agent package from S3. [Resource kit bucket names by Region](https://docs.aws.amazon.com/codedeploy/latest/userguide/resource-kit.html#resource-kit-bucket-names)
```
aws s3 ls --recursive s3://aws-codedeploy-ap-northeast-1 --region ap-northeast-1
aws s3 cp s3://aws-codedeploy-ap-northeast-1/latest/install .

sudo yum update
sudo yum install ruby
cd /home/ec2-user
aws s3 cp s3://aws-codedeploy-ap-northeast-1/latest/install .
chmod +x ./install
sudo ./install auto

systemctl status codedeploy-agent.service
● codedeploy-agent.service - AWS CodeDeploy Host Agent
   Loaded: loaded (/usr/lib/systemd/system/codedeploy-agent.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2020-10-30 02:27:22 UTC; 1 months 25 days ago
 Main PID: 4788 (ruby)
    Tasks: 6
   Memory: 92.6M
   CGroup: /system.slice/codedeploy-agent.service
           ├─4788 codedeploy-agent: master 4788
           └─4794 codedeploy-agent: InstanceAgent::Plugins::CodeDeployPlugin::CommandPoller of master 4788
```

###**2. Create S3 bucket to store application package (.zip) which contains deployment scripts and `appspec.yml` for codedeploy service consumes**
- [appspec.yml](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file.html) example
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/mhxjxu7vi2zszw6tcusa.png)

```
version: 0.0
os: linux
files:
  - source: /
    destination: /var/www/html/WordPress
hooks:
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root
  AfterInstall:
    - location: scripts/change_permissions.sh
      timeout: 300
      runas: root
  ApplicationStart:
    - location: scripts/start_server.sh
    - location: scripts/create_test_db.sh
      timeout: 300
      runas: root
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
      runas: root
```

###**3. Create Lambda function which listen to S3 event of the above bucket and then create deployment**
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/sy0gy1af6pt7itxy6lgl.png)

- LambdaCodeDeployServiceRole
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetDeploymentConfig",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:deploymentconfig:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:RegisterApplicationRevision",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:application:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetApplicationRevision",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:application:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:CreateDeployment",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:deploymentgroup:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetDeployment",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:deploymentgroup:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:GetDeploymentInstance",
            "Resource": [
                "arn:aws:codedeploy:ap-northeast-2:111111111111:deploymentgroup:*"
            ]
        }
    ]
}
```

###**4. Create codedeployment application and Deployment groups to consume app package**
```
# Create application
aws deploy create-application --application-name myapp --compute-platform Server --region ap-northeast-2

# Create group deployment
aws deploy create-deployment-group --application-name myapp --deployment-group-name mygroup --ec2-tag-filters Key=Name,Value=dev,Type=KEY_AND_VALUE --service-role-arn arn:aws:iam::111111111111:role/CodeDeployServiceRole --deployment-style deploymentType=IN_PLACE,deploymentOption=WITHOUT_TRAFFIC_CONTROL --region ap-northeast-2
```

###**5. Push package to S3 bucket in order to trigger deploy**
- Note: Custom object metadata should be prefixed with x-amz-meta-. For example, x-amz-meta-application-name or x-amz-meta-deploymentgroup-name. Amazon S3 uses this prefix to distinguish the user metadata from other headers.

```
zip -r demo.zip appspec.yml scripts/
aws s3 cp demo.zip s3://codedeploy/demo.zip --metadata x-amz-meta-application-name=myapp,
x-amz-meta-deploymentgroup-name=mygroup
```

- Result
```
root@dev:/opt/codedeploy-agent/deployment-root/159045b5-e08b-4594-80af-e34ff25ba82f# cat d-PGZ2ZUOX1/logs/scripts.log 
2020-02-27 07:55:47 LifecycleEvent - ApplicationStop
2020-02-27 07:55:47 Script - scripts/stop_server.sh
2020-02-27 07:55:47 [stdout]Thu Feb 27 07:55:47 UTC 2020: stop server
2020-02-27 07:55:49 LifecycleEvent - BeforeInstall
2020-02-27 07:55:49 Script - scripts/install_dependencies.sh
2020-02-27 07:55:49 [stdout]Thu Feb 27 07:55:49 UTC 2020: install dependency
2020-02-27 07:55:51 LifecycleEvent - AfterInstall
2020-02-27 07:55:51 Script - scripts/change_permissions.sh
2020-02-27 07:55:51 [stdout]Thu Feb 27 07:55:51 UTC 2020: change_permissions
2020-02-27 07:55:52 LifecycleEvent - ApplicationStart
2020-02-27 07:55:52 Script - scripts/start_server.sh
2020-02-27 07:55:52 [stdout]Thu Feb 27 07:55:52 UTC 2020: start server
2020-02-27 07:55:52 Script - scripts/create_test_db.sh
2020-02-27 07:55:52 [stdout]Thu Feb 27 07:55:52 UTC 2020: create test db
