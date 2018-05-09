#!/bin/bash +x

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="mychannel"}
echo $CHANNEL_NAME

## Generates Org certs using cryptogen tool
function generateCerts() {
	CRYPTOGEN=./bin/cryptogen

	if [ -f "$CRYPTOGEN" ]; then
            echo "Using cryptogen -> $CRYPTOGEN"
	else
	    echo "err: can't find cryptogen"
	    exit 1
	fi

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"
	$CRYPTOGEN generate --config=./crypto-config.yaml --output ./crypto-config
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {
    mkdir -p ./channel-artifacts

	CONFIGTXGEN=./bin/configtxgen
	if [ -f "$CONFIGTXGEN" ]; then
            echo "Using configtxgen -> $CONFIGTXGEN"
	else
	    echo "err: can't find configtxgen"
	    exit 1
	fi

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org1MSP   ##########"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org2MSP   ##########"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
	echo
}


generateCerts

generateChannelArtifacts
