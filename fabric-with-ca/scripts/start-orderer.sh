#!/bin/bash

set -e

source $(dirname "$0")/env.sh

echo "Wait for setup to complete sucessfully"
awaitSetup

echo "Enroll to get orderer's TLS cert (using the 'tls' profile)"
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST
if [ "$?" -ne 0 ]; then
    echo "Failed to start orderer, enroll for tls error! ENROLLMENT_URL:$ENROLLMENT_URL"
    exit 1
fi

echo "Copy the TLS key and cert to the appropriate place"
TLSDIR=$ORDERER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY
cp /tmp/tls/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE
rm -rf /tmp/tls

echo "Enroll again to get the orderer's enrollment certificate (default profile)"
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR
if [ "$?" -ne 0 ]; then
    echo "Failed to start order, enroll for msp error! ENROLLMENT_URL:$ENROLLMENT_URL"
    exit 1
fi

echo "Finish setting up the local MSP for the orderer"
finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR

# Start the orderer
env | grep ORDERER
orderer
