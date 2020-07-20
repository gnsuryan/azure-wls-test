#!/bin/bash

checkIfAdminServerIsRunning()
{
   echo "======= checking WLServer Availability ========"
  serverhost=`hostname -f`
  url="http://${ADMIN_SERVER_HOST}:${ADMIN_SERVER_PORT}/console"
  count=0

  while :
  do
       status=`curl -sL -w "%{http_code}\\n" "$url" -o /dev/null`
       count=$((count+1))
       echo "Weblogic Server Status : $status : iteration --> $count"

       if [ $status -eq 200 ]; then
            echo "Weblogic Admin Server is up and running. "
            return 1
       else
            sleep 10
            if [ $count -gt 10 ]; then
             echo "Failed to connect to Weblogic Admin Server even after 40 attempts: Check if the Server is running or not";
             break;
            fi
       fi
  done
  return 0

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

DOMAIN_DIR=${path.domain.config}/${domain.name}

mkdir -p ${DOMAIN_DIR}/AdminServer/security

cd ${DOMAIN_DIR}/AdminServer/security

cat <<EOF> ${DOMAIN_DIR}/AdminServer/security/boot.properties
username=${USERNAME}
password=${PASSWORD}
EOF

cd ${DOMAIN_DIR}

./startWebLogic.sh &

cd ${CURR_DIR}

retcode=$(checkIfAdminServerIsRunning)

if [ "$retcode" == "1" ]
then
   echo "Failed to start WebLogic Administration Server."
   exit 1
fi
