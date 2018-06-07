#!/bin/bash

function main {
   echo "Beginning building channel artifacts ..."
   registerIdentities
   getCACerts
   generateChannelArtifacts
   echo "Finished building channel artifacts"
   touch /$SETUP_SUCCESS_FILE
}


function registerIdentities {
   echo "Registering identities ..."
   registerOrdererIdentities
   registerPeerIdentities
}

function getCACerts {
   echo "Getting CA certificates ..."
   for ORG in $ORGS; do
      initOrgVars $ORG
      echo "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"
      fabric-ca-client getcacert -d -u http://$CA_HOST:7054 -M $ORG_MSP_DIR
      finishMSPSetup $ORG_MSP_DIR
      # If ADMINCERTS is true, we need to enroll the admin now to populate the admincerts directory
      if [ $ADMINCERTS ]; then
         switchToAdminIdentity
      fi
   done
}

function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "Generating orderer genesis block at $GENESIS_BLOCK_FILE"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  configtxgen -profile OrgsOrdererGenesis -outputBlock $GENESIS_BLOCK_FILE
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block"
    exit 1
  fi

  echo "Generating channel configuration transaction at $CHANNEL_TX_FILE"
  configtxgen -profile OrgsChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction"
    exit 1
  fi

  for ORG in $PEER_ORGS; do
     initOrgVars $ORG
     echo "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
     configtxgen -profile OrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
                 -channelID $CHANNEL_NAME -asOrg $ORG
     if [ "$?" -ne 0 ]; then
        echo "Failed to generate anchor peer update for $ORG"
        exit 1
     fi
  done
}


function setupOrder {
    initOrgVars org-order
    echo "Enroll to get orderer's TLS cert (using the tls profile)"
    ENROLLMENT_URL=http://orderer1-org-order:orderer1-org-orderpw@ca-org-order:7054
    ORDERER_HOST=orderer1-org-order
    fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST
    if [ "$?" -ne 0 ]; then
        echo "Failed to setupOrder, enroll error! ENROLLMENT_URL:$ENROLLMENT_URL"
        exit 1
    fi

    ORDERER_HOME=/data/orgs/org-order/orderers
    echo "Copy the TLS key and cert to the appropriate place"
    TLSDIR=$ORDERER_HOME/tls
    mkdir -p $TLSDIR

    cp /tmp/tls/keystore/* $TLSDIR/server.key
    cp /tmp/tls/signcerts/* $TLSDIR/server.crt
    rm -rf /tmp/tls

    echo "Enroll again to get the orderer's enrollment certificate (default profile)"
    ORDERER_GENERAL_LOCALMSPDIR=$ORDERER_HOME/msp
    fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR
    if [ "$?" -ne 0 ]; then
        echo "Failed to setupOrder, enroll error! ENROLLMENT_URL:$ENROLLMENT_URL"
        exit 1
    fi

    echo "Finish setting up the local MSP for the orderer"
    finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
    copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR

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
         fabric-ca-client register -d --id.name $ORDERER_NAME --id.affiliation org-order --id.secret $ORDERER_PASS --id.type orderer --id.attrs 'hf.Revoker=true'
         COUNT=$((COUNT+1))
      done
      echo "Registering admin identity with $CA_NAME"
      # The admin identity has the "admin" attribute which is added to ECert by default
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.affiliation $ORG --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
   done
}

# Register any identities associated with a peer
function registerPeerIdentities {
   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      enrollCAAdmin
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         echo "Registering $PEER_NAME with $CA_NAME"
         fabric-ca-client register -d --id.name $PEER_NAME --id.affiliation $ORG --id.secret $PEER_PASS --id.type peer --id.attrs 'hf.Revoker=true'
         COUNT=$((COUNT+1))
      done
      echo "Registering admin identity with $CA_NAME"
      # The admin identity has the "admin" attribute which is added to ECert by default
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.affiliation $ORG --id.secret $ADMIN_PASS --id.attrs "\"hf.Registrar.Roles=client,user,peer\",hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
      echo "Registering user identity with $CA_NAME"
      fabric-ca-client register -d --id.name $USER_NAME --id.affiliation $ORG --id.secret $USER_PASS --id.type user
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