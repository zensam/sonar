FROM openjdk:8
MAINTAINER Sergii Marynenko <marynenko@gmail.com>
# LABEL version="5.6.6"
LABEL version="6.7.1"

ENV TERM=xterm \
    SONARQUBE_USER=sonarqube \
    SONARQUBE_VERSION=6.7.1 \
    # Postgresql version
    PG_VERSION=9.6 \
    # Do not use SONARQUBE_HOME until it is created with
    # "&& mv sonarqube-$SONARQUBE_VERSION sonarqube \" line in RUN instruction
    SONARQUBE_HOME=/opt/sonarqube \
    # Database configuration for Postgresql
    SQ_USER=sonar \
    # SONARQUBE_JDBC_USERNAME=sonar \
    SQ_PW=sonar \
    # SONARQUBE_JDBC_PASSWORD=sonar \
    SQ_DB=sonar \
    SQ_URL=https://sonarsource.bintray.com/Distribution/sonarqube \
    SONARQUBE_JDBC_URL=jdbc:postgresql://localhost/sonar

RUN apt-get -q -y update \
    && apt-get -q -y upgrade \
    && apt-get -q -y install apt-utils dnsutils gnupg sudo wget curl unzip vim postgresql \
    # && echo "$SQ_USER ALL=NOPASSWD: ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# Postgresql database and SonarQube http ports
EXPOSE 5432 9000

# Add sonarqube system user, es doesn't start from root
RUN groupadd -r $SONARQUBE_USER && useradd -r -g $SONARQUBE_USER $SONARQUBE_USER

# COPY sonar /etc/init.d/
# COPY sonar.ldap /tmp/
COPY sonar* /tmp/

RUN set -x \
    && echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf \
    && echo "listen_addresses='*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf \
    && /etc/init.d/postgresql restart \
    # Sleep a little while postgresql is fully restarted
    && sleep 20 \
    # Create a PostgreSQL role named ''sonar'' with ''sonar'' as the password and
    # then create a database `sonar` owned by the ''sonar'' role.
    && sudo -u postgres psql -c "CREATE USER $SQ_USER WITH REPLICATION PASSWORD '$SQ_PW';" \
    && sudo -u postgres createdb -O $SQ_USER -E UTF8 -T template0 $SQ_DB \
    # see https://bugs.debian.org/812708
    # and https://github.com/SonarSource/docker-sonarqube/pull/18#issuecomment-194045499
    && cd /tmp \
    && curl -fSL -O "https://archive.raspbian.org/raspbian/pool/main/c/ca-certificates/ca-certificates_20130119+deb7u2_all.deb" \
    && echo "03521f6c1ade5682c65c5502c126c686eeea918aaaacdf487a09960b827cbf23  ca-certificates_20130119+deb7u2_all.deb" | sha256sum -c - \
    && dpkg -P --force-all ca-certificates \
    && dpkg -i ca-certificates_20130119+deb7u2_all.deb \
    && rm ca-certificates_20130119+deb7u2_all.deb \
    # pub   2048R/D26468DE 2015-05-25
    #       Key fingerprint = F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
    # uid                  sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
    # sub   2048R/06855C1D 2015-05-25
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \
    && cd /opt \
    && curl -k -o sonarqube.zip -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip \
    && curl -k -o sonarqube.zip.asc -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip.asc \
    && gpg --batch --verify sonarqube.zip.asc sonarqube.zip \
    # Run unzip quietly to avoid log flooding
    && unzip -q sonarqube.zip \
    && mv sonarqube-$SONARQUBE_VERSION sonarqube \
    && rm sonarqube.zip* \
    # Database settings
    && sed -i '/sonar.jdbc.username=/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.username=/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i 's/sonar.jdbc.username=.*/sonar.jdbc.username='$SQ_USER'/g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/sonar.jdbc.password=/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.password=/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i 's/sonar.jdbc.password=.*/sonar.jdbc.password='$SQ_PW'/g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/jdbc:postgresql/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/jdbc:postgresql/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    # LDAP settings should be applied after ldap plugin installation
    # && wget --tries=2 -q -c -P $SONARQUBE_HOME/extensions/plugins/ \
    # http://sonarsource.bintray.com/Distribution/sonar-ldap-plugin/sonar-ldap-plugin-2.0.jar \
    # && cat /tmp/sonar.ldap >> $SONARQUBE_HOME/conf/sonar.properties \
    && ln -s $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh /usr/bin/sonar \
    && sed -i '/RUN_AS_USER=/s/^#//' /usr/bin/sonar \
    && sed -i 's/^RUN_AS_USER=/RUN_AS_USER='$SONARQUBE_USER'/g' /usr/bin/sonar \
    && mv /tmp/sonar /etc/init.d/sonar \
    && chmod 755 /etc/init.d/sonar \
    && update-rc.d sonar defaults \
    # Stop Postgresql to awoid unexpected exit
    # && /etc/init.d/postgresql stop
    && service postgresql stop

VOLUME ["$SONARQUBE_HOME/data", "$SONARQUBE_HOME/extensions"]

# WORKDIR $SONARQUBE_HOME
# COPY run.sh $SONARQUBE_HOME/bin/

# ENTRYPOINT ["/bin/bash"]
CMD service postgresql start && sleep 10 && service sonar start \
    && tail -F $SONARQUBE_HOME/logs/sonar.log
    # && tail -F /var/log/postgresql/postgresql-$PG_VERSION-main.log $SONARQUBE_HOME/logs/sonar.log
# CMD service postgresql start && tail -F /var/log/postgresql/postgresql-$PG_VERSION-main.log
