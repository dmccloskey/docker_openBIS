# Dockerfile for openBIS installation and configuration

# # access to psql and pg_dump are required in /bin
# FROM debian:latest
FROM postgres:latest

LABEL maintainer "dmccloskey87@gmail.com"
LABEL version="1.0"
LABEL description="dockerized version of openBIS"
LABEL build_example="docker build --build-arg OPENBIS_USERNAME=username \
    --build-arg OPENBIS_PASSWORD=password -t dmccloskey/docker-openbis:latest ."
LABEL run_example="docker run --rm --name=openbis dmccloskey/docker-openbis"
LABEL exec_example="docker exec -it --user=user openbis /bin/bash"

# username and password for openBIS
ARG OPENBIS_USERNAME
ARG OPENBIS_PASSWORD

# create an openbis user
ENV HOME /home/openbis
RUN useradd --create-home --home-dir $HOME openbis \
   && chmod -R u+rwx $HOME \
   && chown -R openbis:openbis $HOME

USER root

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		curl \
		unzip \
		# wget \
		# default-jre \
        openjdk-7-jre \
	&& rm -rf /var/lib/apt/lists/*

# openBIS version
ENV OPENBIS_VERSION 16.05.3-r37798

# download and extract openBIS
#RUN mkdir -p /home/openbis \
RUN cd /home/openbis \
    && curl -u ${OPENBIS_USERNAME}:${OPENBIS_PASSWORD} -O https://wiki-bsse.ethz.ch/download/attachments/96536755/openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && tar -xzvf openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && rm openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && cd openBIS-installation-standard-technologies-${OPENBIS_VERSION}

## # wget retrieves an .html document and not a .tar.gz file
## wget --user={OPENBIS_USERNAME} --password='${OPENBIS_PASSWORD}' --content-disposition -O openBIS.tar.gz https://wiki-bsse.ethz.ch/download/attachments/96536755/openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz

# switch back to user for installation
WORKDIR $HOME
USER openbis

# non-GUI installation of openBIS
COPY ./settings/console.properties /home/openbis/openBIS-installation-standard-technologies-${OPENBIS_VERSION}/
# RUN /home/openBIS-installation-standard-technologies-${OPENBIS_VERSION}/run-console.sh

# # customize service.properties of openBIS
# COPY ./settings/service.properties /home/openbis/servers/openBIS-server/jetty/etc/

# # Cleanup
# RUN apt-get clean

# # start the server
# ENTRYPOINT ["/home/openbis/bin/bisup.sh"]

# # stop the server
# ENTRYPOINT ["/home/openbis/bin/bisdown.sh"]