#!/bin/bash

CURR_DIR=`pwd`

source $PWD/test_config.properties


function getHostInfo()
{
    hostnamectl
}

function startTest()
{
    TEST_INFO="$1"
    echo "\n\n"
    echo " =========================================================================================="
    echo " EXECUTION START:  TEST >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
}

function endTest()
{
    TEST_INFO="$1"
    echo " EXECUTION END :    TEST >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
    echo " =========================================================================================="
    echo "\n\n"
}


function testWLSInstallPath()
{
    startTest "testWLSInstallPath"

    if [ ! -d "${WLS_HOME}" ]; then
      echo "Weblogic Server not installed as per the expected directory structure"
    else
      echo "Weblogic Server install path verified successfully"
    fi

    endTest "testWLSInstallation"

}

function testWLSVersion()
{
    startTest "testWLSInstallPath"
    
    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh

    OUTPUT="$(java weblogic.version)"
    echo "${OUTPUT}"

    echo "${OUTPUT}"|grep ${WLS_VERSION}

    if [ "$?" != "0" ];
    then
       echo "FAILURE - Weblogic Server Version could not be verified "    
    else
       echo "SUCCESS - Weblogic Server Version verified successfully"
    fi

    endTest "testWLSInstallPath"

}

function testJavaInstallation()
{
    startTest "testJavaInstallation"

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
       echo "FAILURE - Java Version could not be verified "    
    else
       echo "SUCCESS - Java Server Version verified successfully"
    fi

    endTest "testJavaInstallation"
}

function testDomainSetup()
{

    if [ ! -d "${DOMAIN_DIR}" ]; then
      echo "Weblogic Domain is not available as expected"
      exit 1
    fi
}


function testJDBCDrivers()
{

    startTest "testJavaInstallation"

    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh
  
    echo ${CLASSPATH}

    echo ${CLASSPATH} | grep "${POSTGRESQL_JAR}"

    if [ $? == 1 ];
    then
        echo "FAILURE - ${POSTGRESQL_JAR} file is not found in Weblogic Classpath as expected"
    else
        echo "SUCCESS - ${POSTGRESQL_JAR} file found in Weblogic Classpath as expected"
    fi

    echo $CLASSPATH|grep "${MSSQL_JAR}"

    if [ $? == 1 ];
    then
        echo "FAILURE - ${MSSQL_JAR} file is not found in Weblogic Classpath as expected"
    else
        echo "SUCCESS - ${MSSQL_JAR} file found in Weblogic Classpath as expected"
    fi

    endTest "testJavaInstallation"
}


function testAdminConsoleHTTP()
{
    retcode=$(curl -s -o /dev/null -w "%{http_code}" ${HTTP_ADMIN_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "Error!! Admin Conosle is not accessible. Curl returned code ${retcode}"
    fi
}

function testAdminConsoleHTTPS()
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

function testAppDeployment()
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

testWLSInstallation

testJavaInstallation

testJDBCDrivers

#testDomainSetup

#testAdminConsoleHTTP

#testAdminConsoleHTTPS

#testServerStatus

#testAppDeployment
