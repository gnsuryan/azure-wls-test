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

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    echo $output

    adminServerStatus=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .state ')
    echo "Admin Server Status: $adminServerStatus"

    isServerRunning "AdminServer" "$adminServerStatus"

    endTest
}

function testAppDeployment()
{
    startTest

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    adminServerName=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .name ')

    echo "Deploying to: $adminServerName"
    echo "DEPLOY_APP_PATH: $DEPLOY_APP_PATH"

    retcode=$(curl -v -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${SHOPPING_CART_APP_NAME}',
                deploymentPath: '${SHOPPING_CART_APP_PATH}',
                targets: [ '${adminServerName}' ]
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

    endTest

    echo "Wait for 30 seconds for the deployed Apps to become available..."
    sleep 30s

}


function testDeployedAppHTTP()
{
    startTest

    retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${ADMIN_HTTP_SHOPPING_CART_APP_URL} )

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

    retcode=$(curl --insecure -L -s -o /dev/null -w "%{http_code}" ${ADMIN_HTTPS_SHOPPING_CART_APP_URL} )

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

get_param "$@"

validate_input

testWLSDomainPath

testAdminConsoleHTTP

testAdminConsoleHTTPS

testServerStatus

testAppDeployment

testDeployedAppHTTP

testDeployedAppHTTPS

verifyAdminSystemService

printTestSummary
