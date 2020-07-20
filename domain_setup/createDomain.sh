#!/bin/bash

checkIfAdminServerIsRunning()
{
  echo "======= checking WLServer Availability ========"
  url="http://${ADMIN_SERVER_HOST}:${ADMIN_PORT}/console"
  count=0

  while :
  do
       status=`curl -sL -w "%{http_code}\\n" "$url" -o /dev/null`
       count=$((count+1))
       echo "Weblogic Server Status : $status : iteration --> $count"

       if [ $status -eq 200 ]; then
            echo "Weblogic Admin Server is up and running. "
            exit 0
       else
            sleep 10
            if [ $count -gt 10 ]; then
             echo "Failed to connect to Weblogic Admin Server even after 10 attempts: Check if the Server is running or not";
             break;
            fi
       fi
  done
  exit 1

}

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $CURR_DIR/domain.properties

. $WLS_HOME/server/bin/setWLSEnv.sh

echo $CLASSPATH
echo $JAVA_HOME

java -version
java weblogic.version

# Create the domain.
java weblogic.WLST create_domain.py -p $CURR_DIR/domain.properties

mkdir -p ${DOMAIN_DIR}/servers/AdminServer/security

cat <<EOF> ${DOMAIN_DIR}/servers/AdminServer/security/boot.properties
username=${USERNAME}
password=${PASSWORD}
EOF

cd ${DOMAIN_DIR}
./startWebLogic.sh &

cd ${CURR_DIR}
checkIfAdminServerIsRunning

if [ "$retcode" == "1" ]
then
   echo "Failed to start WebLogic Administration Server."
   exit 1
fi
