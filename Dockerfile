# vim:set ft=dockerfile:
## postgres < 9.6 breaks the build process
# FROM postgres:9.5
FROM postgres:9.6

ENV OPENBIS_REPO https://wiki-bsse.ethz.ch/download/attachments/11109400/
ENV OPENBIS_DISTRIBUTABLE openBIS-installation-standard-technologies-16.05.2-r37126
ENV ADMIN_PASSWORD changeit
ENV ETLSERVER_PASSWORD changeit

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

## User creation
RUN groupadd -r openbis --gid=1000 && useradd -r -g openbis --uid=1000 openbis && \
	mkdir -p /home/openbis && chown -R openbis /home/openbis 
	# \
	# # add permissions to postgres
	# && chown -R postgres /home/openbis

## Java Installation
# auto validate license
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
	# update repos
	echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee /etc/apt/sources.list.d/webupd8team-java.list && \
	echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list && \
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 && \
	apt-get update && \
	# install java
	apt-get install oracle-java8-installer -y && \
	apt-get clean && \
	## openBIS Installation
	apt-get install -y curl && \
	# openBIS tarball
	curl -o /home/openbis/"$OPENBIS_DISTRIBUTABLE".tar.gz "$OPENBIS_REPO""$OPENBIS_DISTRIBUTABLE".tar.gz && \
	# UNZIP used by openbis Installer
	apt-get install -y unzip && \
	# LESS used by openbis scripts
	apt-get install -y less && \
	# openbis and store directory
	mkdir -p /home/openbis/openbis && chown -R openbis /home/openbis/openbis && \
	mkdir -p /home/openbis/store && chown -R openbis /home/openbis/store && \
	# Unzip tarball
	tar -xvzf /home/openbis/"$OPENBIS_DISTRIBUTABLE".tar.gz -C /home/openbis/ && \
	# Delete tarball
	rm -rf /home/openbis/"$OPENBIS_DISTRIBUTABLE".tar.gz && \
	# Updating the installer console.properties to install with sensible defaults
	sed -i "s/^INSTALL_PATH.*/INSTALL_PATH= \/home\/openbis\/openbis\//g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	sed -i "s/^DSS_ROOT_DIR.*/DSS_ROOT_DIR= \/home\/openbis\/store\//g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	sed -i "s/^INSTALLATION_TYPE.*/INSTALLATION_TYPE=server/g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	sed -i "s/^#ELN-LIMS.*/ELN-LIMS = true/g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	sed -i "s/^#ELN-LIMS-MASTER-DATA.*/ELN-LIMS-MASTER-DATA = false/g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	sed -i "s/^#PATHINFO_DB_ENABLED.*/PATHINFO_DB_ENABLED = true/g" /home/openbis/"$OPENBIS_DISTRIBUTABLE"/console.properties && \
	# running installation
	su openbis -c /home/openbis/"$OPENBIS_DISTRIBUTABLE"/run-console.sh && \
	# Path DSS service.properties since contains an unknown host for localhost
	sed -i "s/^host-address.*/host-address = http:\/\/localhost/g" /home/openbis/openbis/servers/datastore_server/etc/service.properties && \
	# Delete unziped installer
	rm -rf /home/openbis/"$OPENBIS_DISTRIBUTABLE" && \
	# Delete blast
	rm -rf /home/openbis/openbis/servers/core-plugins/eln-lims/bin/blast && \
	# Session workspace created manualy to link the directory outside of the container
	mkdir -p /home/openbis/openbis/servers/datastore_server/data/sessionWorkspace && chown -R openbis /home/openbis/openbis/servers/datastore_server/data/sessionWorkspace && \
	## openBIS/DSS configuration for jetty/apache
	mv /home/openbis/openbis/servers/openBIS-server/jetty/start.d/https.ini /home/openbis/openbis/servers/openBIS-server/jetty/start.d/https.ini.backup && \
	mv /home/openbis/openbis/servers/openBIS-server/jetty/start.d/ssl.ini /home/openbis/openbis/servers/openBIS-server/jetty/start.d/ssl.ini.backup && \
	# Path DSS service.properties to run under http
	sed -i 's/8444/8081/g' /home/openbis/openbis/servers/datastore_server/etc/service.properties && \
	sed -i 's/8443/8080/g' /home/openbis/openbis/servers/datastore_server/etc/service.properties && \
	sed -i 's/^use-ssl.*/use-ssl = false/g' /home/openbis/openbis/servers/datastore_server/etc/service.properties && \
	sed -i "s/^download-url.*/download-url = /g" /home/openbis/openbis/servers/datastore_server/etc/service.properties && \
	## Apache installation used by openbis
	apt-get install -y apache2 && \
	a2enmod ssl; a2enmod proxy; a2enmod rewrite; a2enmod proxy_http && \
	mkdir /etc/pki/ && \
	mkdir /etc/pki/tls/ && \
	openssl req -new -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=SW/ST=Basel-City/L=Basel/O=SSDM/CN=SIS" -keyout /etc/pki/tls/apache.key -out /etc/pki/tls/apache.crt && \
	ln -s /etc/apache2/conf-available/openbis.conf   /etc/apache2/conf-enabled/openbis.conf && \
	sed -i '1 i\ServerName localhost' /etc/apache2/apache2.conf


## Template for openBIS state on the same directory (used by the startup script)
COPY openbis_state_template.zip /home/openbis/

## Entrypoint - Just a patched version of the postgres image entry point adding the openBIS startup
# COPY docker-entrypoint.sh /

## Testing permission fix for Win10
RUN rm /docker-entrypoint.sh && rm /usr/local/bin/docker-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh / && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 443

# openBIS Jetty patch for apache
COPY http.ini /home/openbis/openbis/servers/openBIS-server/jetty/start.d/
# openBIS config for apache
COPY openbis.conf /etc/apache2/conf-available/openbis.conf

# QBIC custom installation
RUN mkdir -p /home/openbis/openbis/servers/core-plugins/QBIC/1/as
COPY master-data.py /home/openbis/openbis/servers/core-plugins/QBIC/1/as/initialize-master-data.py
RUN mkdir -p /home/openbis/openbis/servers/core-plugins/QBIC/1/dss \
	&& apt-get install -y --no-install-recommends git \
	&& git clone https://github.com/qbicsoftware/etl-scripts.git /home/openbis/openbis/servers/core-plugins/QBIC/1/dss \
	&& echo 'enabled-modules = dropbox-monitor, dataset-uploader, dataset-file-search, eln-lims, QBIC' > /home/openbis/openbis/servers/core-plugins/core-plugins.properties
# 	#curl -o /home/openbis/openbis/servers/core-plugins/QBIC/1/dss/etl-scripts.zip https://github.com/qbicsoftware/etl-scripts/archive/master.zip && \
# 	#apt-get install unzip && \
# 	#unzip /home/openbis/openbis/servers/core-plugins/QBIC/1/dss/etl-scripts.zip -d /home/openbis/openbis/servers/core-plugins/QBIC/1/dss/ && \
# 	#rm /home/openbis/openbis/servers/core-plugins/QBIC/1/dss/etl-scripts.zip
