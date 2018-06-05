#!/bin/bash

set -e

source $(dirname "$0")/env.sh


function main {
    done=false

    # Wait for setup to complete and then wait another 10 seconds for the orderer and peers to start
    awaitSetup
    sleep 10

    trap finish EXIT

    # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    initOrdererVars ${OORGS[0]} 1
    export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

    # Convert PEER_ORGS to an array named PORGS
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"

    # Create the channel
    createChannel
    echo "create channel completed......."
    sleep 1000

}

# Enroll as a peer admin and create the channel
function createChannel {
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."
   peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS
}

function finish {
   if [ "$done" = true ]; then
      logr "See $RUN_LOGFILE for more details"
      touch /$RUN_SUCCESS_FILE
   else
      logr "Tests did not complete successfully; see $RUN_LOGFILE for more details"
      touch /$RUN_FAIL_FILE
   fi
}

function logr {
   echo $*
   echo $* >> $RUN_SUMPATH
}

main
