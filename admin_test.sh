#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/utils.sh

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

function testWLSDomainPath()
{
    startTest

    echo "DOMAIN_DIR: ${ADMIN_DOMAIN_DIR}"

    if [ ! -d "${ADMIN_DOMAIN_DIR}" ]; then
      echo "Weblogic Server Domain directory not setup as per the expected directory structure: ${ADMIN_DOMAIN_DIR} "
      notifyFail
    else
      echo "Weblogic Server Domain path verified successfully"
      notifyPass
    fi

    endTest
}


function testAdminConsoleHTTP()
{
    startTest

    retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${HTTP_CONSOLE_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Admin Console is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Admin Console is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function testAdminConsoleHTTPS()
{
    startTest

    retcode=$(curl --no-keepalive --insecure -L -s -o /dev/null -w "%{http_code}" ${HTTPS_CONSOLE_URL})

    if [ "${retcode}" != "200" ];
    then
        echo "Error!! Admin Console is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Admin Console is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function testServerStatus()
{
    startTest

    output=$(curl -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    echo $output

    adminServerStatus=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name == $ADMIN_NAME) | .state ')
    echo "Admin Server Status: $adminServerStatus"

    isServerRunning "AdminServer" "$adminServerStatus"

    echo "MANAGED_SERVER_PREFIX: $MANAGED_SERVER_PREFIX"

    managedServer="$(echo $output | jq -r --arg MS_PREFIX "$MANAGED_SERVER_PREFIX" '.items[]|select(.name| startswith($MS_PREFIX))|.name')"
    managedServerStatus="$(echo $output | jq -r --arg MS_PREFIX "$MANAGED_SERVER_PREFIX" '.items[]|select(.name| startswith($MS_PREFIX))|.state')"

    managedServer=$(echo $managedServer)
    managedServerStatus=$(echo $managedServerStatus)

    IFS=' '
    read -a managedServerArray <<< "$managedServer"
    read -a managedServerStatusArray <<< "$managedServerStatus"

    for i in "${!managedServerArray[@]}"; 
    do
        serverName="${managedServerArray[$i]}"
        serverStatus="${managedServerStatusArray[$i]}"
        isServerRunning "$serverName" "$serverStatus"
    done

    endTest
}

function testAppDeployment()
{
    startTest

    echo "DEPLOY_APP_PATH: $DEPLOY_APP_PATH"

    retcode=$(curl -v -s -o /dev/null -w "%{http_code}" \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${SHOPPING_APP_NAME}',
                deploymentPath: '${SHOPPING_APP_PATH}',
                targets: [ '${ADMIN_SERVER_NAME}' ]
            }" \
            -X POST ${HTTP_ADMIN_URL}/management/wls/latest/deployments/application)

    if [ "${retcode}" != "201" -o "${retcode}" != "202" ];
    then
        echo "Error!! App Deployment Failed. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: App Deployed Successfully. Curl returned code ${retcode}"
        notifyPass

        if [ "${retcode}" != "202" ];
        then
            echo "Deployment in progress. Wait for 1 minute for deployment to complete."
            sleep 60s
        fi
    fi

    endTest
}


function testDeployedAppHTTP()
{
    startTest

    retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${HTTP_SHOPPING_APP_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Deployed App is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Deployed App is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}


function testDeployedAppHTTPS()
{
    startTest

    retcode=$(curl --insecure -L -s -o /dev/null -w "%{http_code}" ${HTTPS_SHOPPING_APP_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Deployed App is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Deployed App is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function verifyAdminSystemService()
{

    startTest

    systemctl | grep "$WLS_ADMIN_SERVICE"

    if [ $? == 1 ];
    then
        echo "FAILURE - Service $WLS_ADMIN_SERVICE not found"
        notifyFail
    else
        echo "SUCCESS - Service $WLS_ADMIN_SERVICE found"
        notifyPass
    fi

    endTest
}


#main

testWLSDomainPath

testAdminConsoleHTTP

testAdminConsoleHTTPS

testServerStatus

testAppDeployment

testDeployedAppHTTP

testDeployedAppHTTPS

verifyAdminSystemService

printTestSummary



