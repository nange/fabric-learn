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


    echo "All peers join the channel"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         joinChannel
         COUNT=$((COUNT+1))
      done
    done
    echo "peers join channel completed......."

    echo "Update the anchor peers"
    for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1
      switchToAdminIdentity
      logr "Updating anchor peers for $PEER_HOST ..."
      peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
      if [ $? -ne 0 ]; then
        fatalr "Update the anchor peers failed! ORG:$ORG"
      fi
    done
    echo "Update the anchor peers completed......."
    sleep 5


    echo "Install chaincode on the 1st peer in each org"
    for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1
      installChaincode
    done
    echo "Install chaincode on the 1st peers completed......."
    sleep 5

    echo "Instantiate chaincode on the 1st peer of the 2nd org"
    makePolicy
    initPeerVars ${PORGS[1]} 1
    switchToAdminIdentity
    logr "Instantiating chaincode on $PEER_HOST ..."
    peer chaincode instantiate -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "$POLICY" $ORDERER_CONN_ARGS
    if [ $? -ne 0 ]; then
        fatalr "peer chaincode instantiate failed! ORG:${PORGS[1]}"
    fi
    echo "Instantiate chaincode on the 1st peer of the 2nd org completed......."
    sleep 5

    # TODO: here
    echo "Query chaincode from the 1st peer of the 1st org"
    initPeerVars ${PORGS[0]} 1
    switchToUserIdentity
    chaincodeQuery 100


}

# Enroll as a peer admin and create the channel
function createChannel {
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."
   peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS
}


# Enroll as a fabric admin and join the channel
function joinChannel {
   switchToAdminIdentity
   set +e
   local COUNT=1
   MAX_RETRY=10
   while true; do
      logr "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
      peer channel join -b $CHANNEL_NAME.block
      if [ $? -eq 0 ]; then
         set -e
         logr "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
         return
      fi
      if [ $COUNT -gt $MAX_RETRY ]; then
         fatalr "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
      fi
      COUNT=$((COUNT+1))
      sleep 1
   done
}


function installChaincode {
   switchToAdminIdentity
   logr "Installing chaincode on $PEER_HOST ..."
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go
   if [ $? -ne 0 ]; then
      fatalr "peer chaincode install failed! PEER_HOST:$PEER_HOST"
   fi
}


function makePolicy  {
   POLICY="OR("
   local COUNT=0
   for ORG in $PEER_ORGS; do
      if [ $COUNT -ne 0 ]; then
         POLICY="${POLICY},"
      fi
      initOrgVars $ORG
      POLICY="${POLICY}'${ORG_MSP_ID}.member'"
      COUNT=$((COUNT+1))
   done
   POLICY="${POLICY})"
   echo "policy: $POLICY"
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

function fatalr {
   logr "FATAL: $*"
   exit 1
}

main
