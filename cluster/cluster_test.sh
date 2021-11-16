#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/../utils/utils.sh

function isServerRunning()
{
    serverName="$1"
    serverStatus="$2"

    echo "serverName: $serverName"
    echo "serverStatus: $serverStatus"

    if [ -z "$serverStatus" ];
    then
        echo "FAILURE: Invalid Server Status for Server $serverName"
        notifyFail
    fi

    if [ "$serverStatus" != "RUNNING" ];
    then
        echo "FAILURE: Server $serverName not running as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName running as expected."
        notifyPass
    fi
}

function isServerShutdown()
{
    serverName="$1"
    serverStatus="$2"

    echo "serverName: $serverName"
    echo "serverStatus: $serverStatus"

    if [ -z "$serverStatus" ];
    then
        echo "FAILURE: Invalid Server Status for Server $serverName"
        notifyFail
    fi

    if [ "$serverStatus" != "SHUTDOWN" ];
    then
        echo "FAILURE: Server $serverName not shutdown as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName shutdown as expected."
        notifyPass
    fi
}


function shutdownServer()
{
    serverName="$1"

    echo "Shutting down Server : $serverName"

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X POST ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${serverName}/forceShutdown)

    echo $output

    shutdownStatus="$(echo $output | jq -r '.progress')"

    if [ "$shutdownStatus" != "success" ];
    then
        echo "FAILURE: Server $serverName not shutdown as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName shutdown as expected."
        notifyPass
    fi
}

function startServer()
{
    serverName="$1"

    echo "Start Server : $serverName"

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X POST ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${serverName}/start)

    echo $output

    serverStartStatus="$(echo $output | jq -r '.progress')"

    if [ "$serverStartStatus" != "success" ];
    then
        echo "FAILURE: Server $serverName not started as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName started as expected."
        notifyPass
    fi

    echo "Shut down Server : $serverName Successful"
}

function shutdownAllServers()
{

    echo "ShutdownAllServers...."
    
     output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    #echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"        
        shutdownServer $serverName
        sleep 5s
    done

}


function startAllServers()
{

    echo "StartAllServers...."
    
     output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    #echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"
        startServer $serverName
        sleep 5s
    done
}

function getClusterName()
{

    startTest

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"
        
        output=$(curl -s -v \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${serverName})

        CLUSTER_NAME="$(echo $output | jq -r '.cluster[1]')"

        echo "ClusterName: $CLUSTER_NAME"

        break

    done

    endTest
}

function testManagedServerStatus()
{

    expectedStatus="$1"

    startTest

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    echo $output

    managedServer="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServerStatus="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .state')"

    managedServer=$(echo $managedServer)
    managedServerStatus=$(echo $managedServerStatus)

    IFS=' '
    read -a managedServerArray <<< "$managedServer"
    read -a managedServerStatusArray <<< "$managedServerStatus"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"
        serverStatus="${managedServerStatusArray[$i]}"
        
        
        if [ "$expectedStatus" == "RUNNING" ];
        then
          isServerRunning "$serverName" "$serverStatus"
        else
          if [ "$expectedStatus" == "SHUTDOWN" ];
          then
              isServerShutdown "$serverName" "$serverStatus"
          fi
        fi
    done

    endTest
}

function testAppDeployment()
{
    startTest

    echo "DEPLOY_APP_PATH: $DEPLOY_APP_PATH"

    retcode=$(curl -v -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${SHOPPING_CART_APP_NAME}',
                deploymentPath: '${SHOPPING_CART_APP_PATH}',
                targets: [ '${CLUSTER_NAME}' ]
            }" \
            -X POST ${HTTP_ADMIN_URL}/management/wls/latest/deployments/application)

    echo "$retcode"

    deploymentStatus="$(echo $retcode | jq -r '.messages[]|.severity')"
    
    if [ "${deploymentStatus}" != "SUCCESS" ];
    then
        echo "Error!! App Deployment Failed. Deployment Status: ${deploymentStatus}"
        notifyFail
    else
        echo "SUCCESS: App Deployed Successfully. Deployment Status: ${deploymentStatus}"
        notifyPass
    fi

    echo "Wait for 15 seconds for the deployed Apps to become available..."
    sleep 15s

    endTest
}


function testDeployedAppHTTP()
{
    startTest

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"
        
        output=$(curl -s -v \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${serverName})

        serverListenPort="$(echo $output | jq -r '.listenPort')"
        serverListenAddress="$(echo $output | jq -r '.listenAddress')"

        echo $output

        echo "\n\n\********************************************\n\n"

        echo "ServerListenAddress: $serverListenAddress"
        echo "ServerListenPort: $serverListenPort"

        HTTP_SHOPPING_CART_APP_URL="http://${serverListenAddress}:$serverListenPort/shoppingcart"

        echo "checking Shopping Cart URL: $HTTP_SHOPPING_CART_APP_URL"

        retcode=$(curl -L -s -v -o /dev/null -w "%{http_code}" ${HTTP_SHOPPING_CART_APP_URL} )

        if [ "${retcode}" != "200" ];
        then
            echo "FAILURE: Deployed App is not accessible. Curl returned code ${retcode}"
            notifyFail
        else
            echo "SUCCESS: Deployed App is accessible. Curl returned code ${retcode}"
            notifyPass
        fi

        echo -e "\n\n********************************************\n\n\n"
        sleep 2s

    done

    endTest
}


#main

get_param "$@"

validate_input

testManagedServerStatus "RUNNING"

getClusterName

testAppDeployment

testDeployedAppHTTP

shutdownAllServers

testManagedServerStatus "SHUTDOWN"

startAllServers

testManagedServerStatus "RUNNING"

printTestSummary
