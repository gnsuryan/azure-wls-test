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


# Set environment.
source $PWD/domain.properties

. $WLS_HOME/server/bin/setWLSEnv.sh

echo $CLASSPATH
echo $JAVA_HOME

java -version
java weblogic.version

# Create the domain.
java weblogic.WLST create_domain.py -p domain.properties

mkdir -p ${DOMAIN_DIR}/AdminServer/security

cd ${DOMAIN_DIR}/AdminServer/security

cat <<EOF> ${DOMAIN_DIR}/AdminServer/security/boot.properties
username=${domain.username}
password=${domain.password}
EOF

cd ${DOMAIN_DIR}

./startWebLogic.sh &

checkIfAdminServerIsRunning
