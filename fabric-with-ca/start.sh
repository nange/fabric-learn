#!/bin/bash

set -e

SDIR=$(dirname "0")
echo "SIR:${SDIR}"

cd ${SDIR}

# delete docker containers of fabric
dockerContainers=$(docker ps -a | awk '$2~/hyperledger/ {print $1}')
if [ "$dockerContainers" != "" ]; then
   echo "Deleting existing docker containers ..."
   docker rm -f $dockerContainers > /dev/null
fi

# Remove chaincode docker images
chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
if [ "$chaincodeImages" != "" ]; then
   echo "Removing chaincode docker images ..."
   docker rmi -f $chaincodeImages > /dev/null
fi

# Start with a clean data directory
DDIR=${SDIR}/data
if [ -d ${DDIR} ]; then
   echo "Cleaning up the data directory from previous run at $DDIR"
   rm -rf ${SDIR}/data
fi
mkdir -p ${DDIR}/logs

# Create the docker containers
echo "Creating docker containers ..."
docker-compose -f ./docker-compose-ca.yaml up

