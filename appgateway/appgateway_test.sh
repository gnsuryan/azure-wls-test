#!/bin/bash

APPGW_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${APPGW_DIR}/../utils/utils.sh
source ${APPGW_DIR}/../utils/test_config.properties

function getAppGWPublicIP()
{
  APPGW_IP_ADDR=$(az network public-ip show \
  --resource-group $RG_NAME \
  --name gwip \
  --query ipAddress \
  --output tsv)

  print "App Gateway IP Address: $APPGW_IP_ADDR"
}

function getAppGWPublicFQDN()
{
  APPGW_FQDN=$(az network public-ip show \
  --resource-group $RG_NAME \
  --name gwip \
  --query dnsSettings.fqdn \
  --output tsv)

  print "App Gateway Public FQDN: $APPGW_FQDN"
}

function getAdminVMIP()
{
  ADMIN_VM_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RG_NAME \
  --name adminVM_PublicIP \
  --query dnsSettings.fqdn \
  --output tsv)

  ADMIN_URL="http://${ADMIN_VM_PUBLIC_IP}:7001"

  print "Admin VM Public IP: $ADMIN_VM_PUBLIC_IP"
}


function verifyAppGatewayHTTPS()
{

    APPGW_HOST="$1"

    URL="http://${APPGW_HOST}/replicationwebapp/FirstServlet"
    print "verifying App Gateway HTTP URL... $URL"

    for i in {1..6}
    do
        response="$(curl -Ls --insecure --write-out '%{http_code}' $URL)"
        print "Response: $response"

        if [[ "$response" =~ .*"success".* ]];
        then
           print "recevied success response."
        else
           print "Received Failure response"
           break
        fi

        primaryServer="$(echo $response | grep primary | sed 's/^.*<primary>//g' | sed 's/<\/primary>.*$//g')"
        serverList+=($primaryServer)
    done

    uniqueList=$(echo "${serverList[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    print "uniqueList: $uniqueList"

    IFS=' ' read -r -a array <<< "$uniqueList"
    print "length: ${#array[@]}"

    if [[ "${#array[@]}" == 3 ]];
    then
       echo "SUCCESS: AppGateway verification is successful."
       notifyPass
    else
       echo "FAIL: AppGateway verification failed."
       notifyFail
    fi
}

function verifyAppGatewayHTTP()
{
    APPGW_HOST="$1"

    serverList=()

    URL="https://${APPGW_HOST}/replicationwebapp/FirstServlet"
    print "verifying App Gateway HTTP URL... $URL"

    for i in {1..6}
    do
        response="$(curl -Ls --insecure --write-out '%{http_code}' $URL)"
        print "Response: $response"

        if [[ "$response" =~ .*"success".* ]];
        then
           print "Received success response"
        else
           print "Received Failure response"
           break
        fi

        primaryServer="$(echo $response | grep primary | sed 's/^.*<primary>//g' | sed 's/<\/primary>.*$//g')"
        serverList+=($primaryServer)
        sleep 1s
    done

    uniqueList=$(echo "${serverList[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    print "uniqueList: $uniqueList"
    IFS=' ' read -r -a array <<< "$uniqueList"
    print "length: ${#array[@]}"

    if [[ "${#array[@]}" == 3 ]];
    then
       echo "SUCCESS: AppGateway verification is successful."
       notifyPass
    else
       echo "FAIL: AppGateway verification failed."
       notifyFail
    fi
}

function getClusterName()
{

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    print $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"

        if [[ $serverName == *"Storage"* ]];
        then
          continue
        fi

        output=$(curl -s \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${serverName})

        CLUSTER_NAME="$(echo $output | jq -r '.cluster[1]')"

        print "ClusterName: $CLUSTER_NAME"

        break

    done

    endTest
}

function deployReplicationWebApp()
{
    mkdir -p /tmp/deploy
    cp ${REPLICATION_APP_PATH} /tmp/deploy/

    startTest

    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:multipart/form-data \
            -F "model={
                name: '${REPLICATION_APP_NAME}',
                targets:    [ '${CLUSTER_NAME}' ]
            }" \
            -F "deployment=@/tmp/deploy/${REPLICATION_DEPLOY_APP}" \
            -X POST ${ADMIN_URL}/management/wls/latest/deployments/application)

    print "$retcode"

    deploymentStatus="$(echo $retcode | jq -r '.messages[]|.severity')"

    if [ "${deploymentStatus}" != "SUCCESS" ];
    then
        echo "FAILURE - Replication WebApp Deployment Failed. Deployment Status: ${deploymentStatus}"
        notifyFail
    else
        echo "SUCCESS - Replication WebApp Deployed Successfully. Deployment Status: ${deploymentStatus}"
        notifyPass
        print "Wait for 15 seconds for the deployed Apps to become available..."
        sleep 15s
    fi

    #rm -rf /tmp/deploy

    endTest
}

#main

get_param "$@"

getAppGWPublicIP

getAdminVMIP

getClusterName

deployReplicationWebApp

verifyAppGatewayHTTPS "$APPGW_IP_ADDR"

verifyAppGatewayHTTP "$APPGW_IP_ADDR"

getAppGWPublicFQDN

verifyAppGatewayHTTPS "$APPGW_FQDN"

verifyAppGatewayHTTP "$APPGW_FQDN"

printTestSummary

