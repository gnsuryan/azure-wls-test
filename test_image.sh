#!/bin/bash

function run_as_oracle_user()
{
    command="$1"
    runuser -l oracle -c "$command"
}

function print_heading()
{
  text="$1"
  echo -e "\n################ $text #############\n"
  echo -e "-----------------------------------------------------\n"
}


print_heading "OS information"
hostnamectl

print_heading "JDK Details"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && java -version && print_heading JAVA_HOME=\$JAVA_HOME"


print_heading "WLS Details"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && java weblogic.version && print_heading WL_HOME=\$WL_HOME"

print_heading "OPatch version"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && \$WL_HOME/../OPatch/opatch version"

print_heading "OPatch details"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && \$WL_HOME/../OPatch/opatch lsinventory"


print_heading "JDBC Driver Details"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && print_heading \$WEBLOGIC_CLASSPATH"

print_heading "MSSQL Driver"
run_as_oracle_user " [ -f /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/mssql-jdbc-7.4.1.jre8.jar ] && print_heading 'MSSQL Driver found'"

print_heading "PostgreSQL Driver"
run_as_oracle_user " [ -f /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/postgresql-42.2.8.jar ] && print_heading 'PostgreSQL Driver found'"

print_heading "rngd service"
systemctl status rngd

print_heading "create cluster domain and verify"

print_heading "installing git..."
yum install -y git 

print_heading "download domain creation scripts..."
run_as_oracle_user "mkdir -p /u01/app/scripts && rm -rf /u01/app/scripts/* && cd /u01/app/scripts && git clone https://github.com/gnsuryan/weblogic-cluster-domain-init"

print_heading "kill any existing weblogic processes"
pkill -9 -f weblogic.NodeManager
pkill -9 -f weblogic.Server

sleep 10s

print_heading "cleanup domain directory..."
run_as_oracle_user "rm -rf /u01/domains/*"

print_heading "replace actual hostname in domain.properties"
run_as_oracle_user "sed -i \"s/adminVM/$HOSTNAME/g\" /u01/app/scripts/weblogic-cluster-domain-init/domain.properties"

print_heading "execute domain creation script"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST createDomain.py"

print_heading "execute app deployment script"
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST deployApps.py"

print_heading "open ports for testing..."
sudo firewall-cmd --zone=public --add-port=7001/tcp
sudo firewall-cmd --zone=public --add-port=7002/tcp
sudo firewall-cmd --zone=public --add-port=7003/tcp
sudo firewall-cmd --zone=public --add-port=7004/tcp
sudo firewall-cmd --runtime-to-permanent
sudo systemctl restart firewalld

print_heading "Test Admin console and Test app deployed on the cluster"
run_as_oracle_user "cd /u01/app/scripts/weblogic-cluster-domain-init && chmod +x testApp.sh && sh testApp.sh"

username=$(run_as_oracle_user "cat /u01/app/scripts/weblogic-cluster-domain-init/domain.properties | grep 'domain_username')
password=$(run_as_oracle_user "cat /u01/app/scripts/weblogic-cluster-domain-init/domain.properties | grep 'domain_password')

print_heading "Testing Server Restart..."
run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST testServerRestart.py $username $password t3://$HOSTNAME:7001"
