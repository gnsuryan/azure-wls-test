#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/test_config.properties

function startTest()
{
    TEST_INFO="$1"
    echo " =========================================================================================="
    echo " TEST EXECUTION START:   >>>>>>     ${TEST_INFO}      <<<<<<"
    echo " =========================================================================================="
}

function endTest()
{
    TEST_INFO="$1"
    echo " =========================================================================================="
    echo " TEST EXECUTION END :    >>>>>>     ${TEST_INFO}      <<<<<<"
    echo " =========================================================================================="
}

function getHostInfo()
{
    hostnamectl
}

function checkWLSInstallation()
{

    startTest "checkWLSInstallation"

    if [ ! -d "${WLS_HOME}" ]; then
      echo "Weblogic Server not installed as per the expected directory structure"
    else
      echo "Weblogic Server install path verified successfully"
    fi

    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh

    OUTPUT="$(java weblogic.version)"
    echo "${OUTPUT}"

    echo "${OUTPUT}"|grep ${WLS_VERSION}

    if [ "$?" != "0" ];
    then
       echo "Error !! Weblogic Server Version could not be verified "    
    else
       echo "Success !! Weblogic Server Version verified successfully"
    fi

    endTest "checkWLSInstallation"

}

function checkJavaInstallation()
{
    startTest "checkJavaInstallation"

     if type -p java; then
        echo found java executable in PATH
        _java=java
    elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
        echo found java executable in JAVA_HOME     
        _java="$JAVA_HOME/bin/java"
    else
        echo "no java"
    fi

    if [[ "$_java" ]]; then
        version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
        echo version "$version"
    fi

    echo "${version}"|grep ${JDK_VERSION}

    if [ "$?" != "0" ];
    then
       echo "Error !! Java Version could not be verified "    
    else
       echo "Success !! Java Server Version verified successfully"
    fi

    endTest "checkJavaInstallation"
}

function checkDomainSetup()
{

    if [ ! -d "${DOMAIN_DIR}" ]; then
      echo "Weblogic Domain is not available as expected"
      exit 1
    fi
}


function checkJDBCDrivers()
{
    echo ${CLASSPATH}

    echo ${CLASSPATH} | grep "${POSTGRESQL_JAR}"

    if [ $? == 1 ];
    then
        echo "${POSTGRESQL_JAR} file is not found in Weblogic Classpath as expected"
    fi

    echo $CLASSPATH|grep "${MSSQL_JAR}"

    if [ $? == 1 ];
    then
        echo "${MSSQL_JAR} file is not found in Weblogic Classpath as expected"
    fi


}


function checkAdminConsoleHTTP()
{
    retcode=$(curl -s -o /dev/null -w "%{http_code}" ${HTTP_ADMIN_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "Error!! Admin Conosle is not accessible. Curl returned code ${retcode}"
    fi
}

function checkAdminConsoleHTTPS()
{
    retcode=$(curl --insecure -s -o /dev/null -w "%{http_code}" ${HTTPS_ADMIN_URL})

    if [ "${retcode}" != "200" ];
    then
        echo "Error!! Admin Conosle is not accessible. Curl returned code ${retcode}"
    fi
}

function getServerStatus()
{

    curl -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET http://localhost:7001/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state

}

function checkAppDeployment()
{
    curl -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{
     name: '${DEPLOY_APP_NAME}',
     applicationPath : '/apps/oracle-weblogic/applications/mwiapp.war',
     targets: ['mwiCluster1'],
     plan: '/apps/oracle-weblogic/applications/plan.xml',
     deploymentOptions: {}
    }" \
    -X POST http://localhost:17001/management/weblogic/latest/domainRuntime/deploymentManager/deploy_
}


#main

getHostInfo

checkWLSInstallation

checkJavaInstallation

#checkJDBCDrivers

#checkDomainSetup

#checkAdminConsoleHTTP

#checkAdminConsoleHTTPS

#checkServerStatus

#checkAppDeployment
