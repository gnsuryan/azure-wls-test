#!/bin/bash

checkIfAdminServerIsRunning()
{
  
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

DOMAIN_DIR=${path.domain.config}/${domain.name}

mkdir -p ${DOMAIN_DIR}/AdminServer/security

cd ${DOMAIN_DIR}/AdminServer/security

cat <<EOF> ${DOMAIN_DIR}/AdminServer/security/boot.properties
username=${domain.username}
password=${domain.password}
EOF

cd ${DOMAIN_DIR}

./startWebLogic.sh &

checkIfAdminServerIsRunning
