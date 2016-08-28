### SonarQube install at CentOS 6

##### Install JDK
```bash
sudo yum install -y java-1.8.0-openjdk
```

##### Install Postgresql
```bash
yum install -y postgresql-server
echo "host all  all    0.0.0.0/0  md5" >> /var/lib/pgsql/data/pg_hba.conf
echo "listen_addresses='*'" >> /var/lib/pgsql/data/postgresql.conf
service postgresql restart
chkconfig postgresql on
sudo -u postgres psql -c "CREATE USER sonar WITH PASSWORD 'sonar';"
sudo -u postgres createdb -O sonar -E UTF8 -T template0 sonar
```

##### Install SonarQube
```bash
cd /opt
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE
curl -k -o sonarqube.zip -fSL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-5.6.zip
curl -k -o sonarqube.zip.asc -fSL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-5.6.zip.asc
gpg --batch --verify sonarqube.zip.asc sonarqube.zip
mv sonarqube-5.6 sonarqube
rm sonarqube.zip
```

##### Database settings
```bash
sed -i '/sonar.jdbc.username=/s/^#//' /opt/sonarqube/conf/sonar.properties
sed -i 's/sonar.jdbc.username=.*/sonar.jdbc.username='sonar'/g' /opt/sonarqube/conf/sonar.properties
sed -i '/sonar.jdbc.password=/s/^#//' /opt/sonarqube/conf/sonar.properties
sed -i 's/sonar.jdbc.password=.*/sonar.jdbc.password='sonar'/g' /opt/sonarqube/conf/sonar.properties
```

##### Running SonarQube as a Service on Linux
using [../sonar] file as /etc/init.d/sonar

```bash
export SONAR_HOME=/opt/sonarqube
ln -s $SONAR_HOME/bin/linux-x86-64/sonar.sh /usr/bin/sonar
cp /path/to/sonar /etc/init.d/sonar
chkconfig --add sonar
```
