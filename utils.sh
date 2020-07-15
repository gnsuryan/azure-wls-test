#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/test_config.properties

export passcount=0
export failcount=0

function notifyPass()
{
    passcount=$((passcount+1))
}

function notifyFail()
{
    failcount=$((failcount+1))
}

function printTestSummary()
{
    printf "\n++++++++++++++++++++++++++++++++++++++++++\n"
    printf "\n     TEST EXECUTION SUMMARY"
    printf "\n     ++++++++++++++++++++++   \n"
    printf "       NO OF TEST PASSED:  ${passcount} \n"
    printf "       NO OF TEST FAILED:  ${failcount} \n"
    printf "\n++++++++++++++++++++++++++++++++++++++++++\n"
}

function startTest()
{
    TEST_INFO="${FUNCNAME[1]}"
    printf "\n\n"
    echo " -----------------------------------------------------------------------------------------"
    echo " TEST EXECUTION START:  >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
}

function endTest()
{
    TEST_INFO="${FUNCNAME[1]}"
    echo " TEST EXECUTION  END :   >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
    echo " -----------------------------------------------------------------------------------------"
    printf "\n\n"
}

function isUtilityInstalled()
{
    startTest

    utilityName="$1"    
    
    yum list installed | grep "$utilityName"

    if [ "$?" != "0" ];
    then
       echo "FAILURE - Utility $utilityName not found. "
       notifyFail
    else
       echo "SUCCESS - Utility $utilityName found."
       notifyPass
    fi

    endTest
}
