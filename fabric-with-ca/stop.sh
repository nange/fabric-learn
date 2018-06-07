#!/bin/bash

set -e
SDIR=$(dirname "$0")

echo "Stopping docker containers ..."
docker-compose -f ./docker-compose-ca.yaml down

# Stop chaincode containers and images as well
docker rm -f $(docker ps -aq --filter name=dev-peer)
docker rmi $(docker images | awk '$1 ~ /dev-peer/ { print $3 }')
echo "Docker containers have been stopped"
