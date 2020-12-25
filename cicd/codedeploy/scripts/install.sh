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
