# Create application
aws deploy create-application --application-name myapp --compute-platform Server --region ap-northeast-2

# Create group deployment
aws deploy create-deployment-group --application-name myapp --deployment-group-name mygroup --ec2-tag-filters Key=Name,Value=dev,Type=KEY_AND_VALUE --service-role-arn arn:aws:iam::111111111111:role/CodeDeployServiceRole --deployment-style deploymentType=IN_PLACE,deploymentOption=WITHOUT_TRAFFIC_CONTROL --region ap-northeast-2
