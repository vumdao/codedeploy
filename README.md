#Gitlab Pipeline With AWS Codedeploy
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/oc5bq3919tr4j5oj2jpc.png)

##**Flow Chart**
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/xg79z3cjvx6cth7pexjo.png)

###**1. [Create Codedeploy](https://dev.to/vumdao/create-codedeploy-4425)**
- Follow the link to create lambda function which is trigger by S3 notification event and then create code deployment.
- Gitlab pipeline job will push deploy.zip to S3 so that lambda function will create code deployment for running install script on target instance by codedeploy-agent
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/v8gvmrxqzx6muj31349c.png)

![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/2lr98c3fanha39zk1asv.png)

###**2. Gitlab pipeline jobs to build and deploy**
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/o2164onbj04mixqxgjlh.jpg)
- `image_version.txt` is packed in `deploy.zip` for codedeploy get version to deploy
- Codedeploy structure:
 - application: service_name (app, api, myweb, etc.)
 - deployment group: branch_name (feature, develop, hotfix, master, integration, etc.), each one will have same or different target instancce
- [.gitlab-ci.yml]()
```
build:
  stage: build
  script:
    - echo compile and package
    - echo tag image version
    - branch_name=$(echo $CI_COMMIT_REF_NAME | sed 's/\//-/g')
    - version="$branch_name-$CI_PIPELINE_ID"
    - echo login ECR and push image
    - eval $(aws ecr get-login --no-include-email --region ap-northeast-1)
    - docker tag app:latest myimage:${version}
    - docker push myimage:${version}
  only:
    refs:
      - feature
      - develop
      - integration
      - hotfix
      - master
    changes:
      - src/**/*
  tags:
    - build-runner

deploy:
  stage: deploy
  script:
    - echo "Deploy app"
    - branch_name=$(echo $CI_COMMIT_REF_NAME | sed 's/\//-/g')
    - version="$branch_name-$CI_PIPELINE_ID"
    - echo $version > codedeploy/image_version.txt
    - cd codedeploy
    - zip -r deploy.zip appspec.yml image_version.txt scripts
    - aws s3 cp deploy.zip s3://codedeploy/automation/${CI_COMMIT_REF_NAME}/app/deploy.zip --metadata x-amz-meta-application-name=app,x-amz-meta-deploymentgroup-name=${obj}
  only:
    refs:
      - feature
      - develop
      - integration
      - hotfix
      - master
    changes:
      - src/**/*
  tags:
    - deploy-runner
```

###**3. Install script**
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/texdrp5op28irl7g35b2.png)
- The script is run on target instance by codedeploy-agent
```
$ cat codedeploy/scripts/install.sh 
#!/bin/bash
# Script is run on instance

# Get app version
dir=$(dirname "$0")
version=$(cat ${dir}/../image_version.txt)

# Tracking version
OPS_DIR="/ect/ops"
export APP_VERSION=${version}

# Compose up
docker-compose up -d app
```

###**4. `appspec.yml`**
```
version: 0.0
os: linux
hooks:
  BeforeInstall:
    - location: scripts/install.sh
      timeout: 300
      runas: root
```
