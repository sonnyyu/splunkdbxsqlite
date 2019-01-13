#!/bin/bash
# show commands being executed, per debug

set -x
exec > >(sudo tee install.log)
exec 2>&1
INSTALL_SPLUNK=1
INSTALL_JAVA=1
INSTALL_DBX=1
PLUNK_PASSWORD="password"

if [[ "$INSTALL_SPLUNK" == "1" ]]; then
wget -O splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.3&product=splunk&filename=splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb&wget=true'
dpkg -i splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb
cd /opt/splunk/bin
./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${PLUNK_PASSWORD}
./splunk enable boot-start
./splunk restart
fi

if [[ "$INSTALL_JAVA" == "1" ]]; then
sudo apt-get update -y && sudo apt-get upgrade  -y
sudo add-apt-repository ppa:webupd8team/java  -y
sudo apt-get update -y
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
sudo apt-get install oracle-java8-installer -y
#sudo update-alternatives --config java
echo 'JAVA_HOME="/usr/lib/jvm/java-8-oracle"' >>/etc/environment
source /etc/environment
export JAVA_HOME="/usr/lib/jvm/java-8-oracle"
fi

if [[ "$INSTALL_DBX" == "1" ]]; then
cd /opt/splunk/bin
wget https://www.dropbox.com/s/djjn9to4b4r3fy6/splunk-db-connect_314.tgz
./splunk install app splunk-db-connect_314.tgz  -auth admin:${PLUNK_PASSWORD}
./splunk restart

mkdir -p /opt/splunk/etc/apps/splunk_app_db_connect/local/
cd /opt/splunk/etc/apps/splunk_app_db_connect/local/
wget https://www.dropbox.com/s/5naqruqq3ineyam/Sample.db

sudo apt-get update -y
sudo apt-get install sqlite3 libsqlite3-dev -y

cd /opt/splunk/etc/apps/splunk_app_db_connect/drivers/

wget https://bitbucket.org/xerial/sqlite-jdbc/downloads/sqlite-jdbc-3.23.1.jar

#nano /opt/splunk/etc/apps/splunk_app_db_connect/local/db_connection_types.conf

cat << EOF > /opt/splunk/etc/apps/splunk_app_db_connect/local/db_connection_types.conf
[sqlite]
displayName = SQLite
serviceClass = com.splunk.dbx2.DefaultDBX2JDBC
jdbcDriverClass = org.sqlite.JDBC
jdbcUrlFormat = jdbc:sqlite:<database>
ui_default_catalog = $database$
EOF

#nano /opt/splunk/etc/apps/splunk_app_db_connect/local/db_connections.conf

cat << EOF > /opt/splunk/etc/apps/splunk_app_db_connect/local/db_connections.conf
[default]
useConnectionPool = true
maxConnLifetimeMillis = 1800000
maxWaitMillis = 30000
maxTotalConn = 8
fetch_size = 100

[SQLiteSample]
connection_type = sqlite
database = /opt/splunk/etc/apps/splunk_app_db_connect/local/Sample.db
host = localhost
identity = sonnyyu
jdbcUrlFormat = jdbc:sqlite:<database>
jdbcUseSSL = 0
EOF

curl -k -X POST -u admin:${PLUNK_PASSWORD} https://localhost:8089/servicesNS/nobody/splunk_app_db_connect/db_connect/dbxproxy/identities -d \
"{\"name\":\"sonnyyu\",\"username\":\"sonnyyu\",\"password\":null,\"disabled\":false,\"domain_name\":null,\"use_win_auth\":false}"

cd /opt/splunk/bin
./splunk restart

fi
echo "completed"
exit
