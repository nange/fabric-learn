#!/bin/bash

# Set to true to enable use of intermediate CAs
USE_INTERMEDIATE_CA=true

# Number of orderer nodes
NUM_ORDERERS=1

# The volume mount to share data between containers
DATA=data

# Log directory
LOGDIR=$DATA/logs
LOGPATH=/$LOGDIR

# Name of a the file to create when setup is successful
SETUP_SUCCESS_FILE=${LOGDIR}/setup.successful

# Names of the orderer organizations
ORDERER_ORGS="org-order"

# initOrgVars <ORG>
function initOrgVars {
    ORG=$1

    ROOT_CA_HOST=rca
    ROOT_CA_NAME=rca
    ROOT_CA_LOGFILE=$LOGDIR/${ROOT_CA_NAME}.log

    INT_CA_HOST=ica-${ORG}
    INT_CA_NAME=ica-${ORG}
    INT_CA_LOGFILE=${LOGDIR}/${INT_CA_NAME}.log

    ROOT_CA_CERTFILE=/${DATA}/${ORG}-ca-cert.pem
    INT_CA_CHAINFILE=/${DATA}/${ORG}-ca-chain.pem

    # Admin identity for the org
    ADMIN_NAME=admin-${ORG}
    ADMIN_PASS=${ADMIN_NAME}pw

    if test "$ORG" = "org-order"; then
        INT_CA_ADMIN_USER_PASS="order-admin:order-adminpw"
    elif test "$ORG" = "org-rockontrol"; then
        INT_CA_ADMIN_USER_PASS="rockontrol-admin:rockontrol-adminpw"
    elif test "$ORG" = "org-weihai"; then
        INT_CA_ADMIN_USER_PASS="weihai-admin:weihai-adminpw"
    fi

    if test "$USE_INTERMEDIATE_CA" = "true"; then
        CA_NAME=$INT_CA_NAME
        CA_HOST=$INT_CA_HOST
        CA_CHAINFILE=$INT_CA_CHAINFILE
        CA_LOGFILE=$INT_CA_LOGFILE
        CA_ADMIN_USER_PASS=$INT_CA_ADMIN_USER_PASS
    else
        echo "should set USE_INTERMEDIATE_CA to true"
        exit 1
    fi

}

# initOrdererVars <NUM>
function initOrdererVars {
    if [ $# -ne 2 ]; then
        echo "Usage: initOrdererVars <ORG> <NUM>"
        exit 1
    fi

    initOrgVars $1
    NUM=$2

    ORDERER_NAME=orderer${NUM}-${ORG}
    ORDERER_PASS=${ORDERER_NAME}pw

    MYHOME=/etc/hyperledger/orderer
}


# Wait for a process to begin to listen on a particular host and port
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
function waitPort {
   set +e
   local what=$1
   local secs=$2
   local logFile=$3
   local host=$4
   local port=$5
   nc -z $host $port > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo -n "Waiting for $what ..."
      local starttime=$(date +%s)
      while true; do
         sleep 1
         nc -z $host $port > /dev/null 2>&1
         echo "exec nc cmd..."
         if [ $? -eq 0 ]; then
            break
         fi
         if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
            echo "Failed waiting for $what; see $logFile"
            exit 1
         fi
         echo -n "."
      done
      echo ""
   fi
   set -e
}
