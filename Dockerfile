# Dockerfile for openBIS installation and configuration

FROM debian:latest

LABEL maintainer "dmccloskey87@gmail.com"
LABEL version="1.0"
LABEL description="dockerized version of openBIS"
LABEL build_example="docker build --build-arg OPENBIS_USERNAME=username \
    OPENBIS_PASSWORD=password -t dmccloskey/docker_openbis:latest ."
LABEL run_example="docker run --rm --name=openbis dmccloskey/docker_openbis"
LABEL exec_example="docker exec -it --user=user openbis /bin/bash"

# username and password for openBIS
ARG OPENBIS_USERNAME
ARG OPENBIS_PASSWORD

USER root

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		curl \
		# wget \
		default-jre \
	&& rm -rf /var/lib/apt/lists/*

# openBIS version
ENV OPENBIS_VERSION 16.05.3-r37798

# download and extract openBIS
RUN mkdir -p /home/user \
    && cd /home/user \
    && curl -u ${OPENBIS_USERNAME}:${OPENBIS_PASSWORD} -O https://wiki-bsse.ethz.ch/download/attachments/96536755/openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && tar -xzvf openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && rm openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz \
    && cd openBIS-installation-standard-technologies-${OPENBIS_VERSION}

##wget retrieves an .html document and not a .tar.gz file
#wget --user={OPENBIS_USERNAME} --password='${OPENBIS_PASSWORD}' --content-disposition -O openBIS.tar.gz https://wiki-bsse.ethz.ch/download/attachments/96536755/openBIS-installation-standard-technologies-${OPENBIS_VERSION}.tar.gz

# non-GUI installation of openBIS
COPY ./settings/console.properties /home/user/openBIS-installation-standard-technologies-${OPENBIS_VERSION}/
RUN /home/user/openBIS-installation-standard-technologies-${OPENBIS_VERSION}/run-console.sh

# customize service.properties of openBIS

# Cleanup
RUN apt-get clean

create a python user
ENV HOME /home/user
RUN useradd --create-home --home-dir $HOME user \
   && chmod -R u+rwx $HOME \
   && chown -R user:user $HOME

# switch back to user
WORKDIR $HOME
USER user

# set the command
#CMD ["python3"]