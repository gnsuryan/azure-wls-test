# Set environment.
export MW_HOME=/u01/app/wls/install/oracle/middleware
export WLS_HOME=/u01/app/wls/install/oracle/middleware/oracle_home/wlserver
export WL_HOME=$WLS_HOME
export PATH=$JAVA_HOME/bin:$PATH
export CONFIG_JVM_ARGS=-Djava.security.egd=file:/dev/./urandom

. $WLS_HOME/server/bin/setWLSEnv.sh

echo $CLASSPATH
echo $JAVA_HOME

java -version
java weblogic.version

# Create the domain.
java weblogic.WLST create_domain.py -p domain.properties
