#!/bin/bash

function main {
   echo "Beginning building channel artifacts ..."
   registerIdentities
   #getCACerts
   #makeConfigTxYaml
   #generateChannelArtifacts
   echo "Finished building channel artifacts"
   touch /$SETUP_SUCCESS_FILE
}


function registerIdentities {
   echo "Registering identities ..."
   registerOrdererIdentities
   #registerPeerIdentities
}

# Register any identities associated with the orderer
function registerOrdererIdentities {
   for ORG in $ORDERER_ORGS; do
      initOrgVars $ORG
      enrollCAAdmin
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "Registering $ORDERER_NAME with $CA_NAME"
         fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
         COUNT=$((COUNT+1))
      done
      echo "Registering admin identity with $CA_NAME"
      # The admin identity has the "admin" attribute which is added to ECert by default
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
   done
}

# Enroll the CA administrator
function enrollCAAdmin {
   waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
   echo "Enrolling with $CA_NAME as bootstrap identity ..."
   export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   echo "FABRIC_CA_CLIENT_TLS_CERTFILES:${FABRIC_CA_CLIENT_TLS_CERTFILES}"
   fabric-ca-client enroll -d -u http://$CA_ADMIN_USER_PASS@$CA_HOST:7054
   echo "enroll ca admin completed..."
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main