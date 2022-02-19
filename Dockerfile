FROM python:2.7.18-slim-buster

ARG BUILD_DATE
ARG BUILD_VERSION

LABEL org.opencontainers.image.authors="Johann Häger <johann.haeger@posteo.de>"
LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.description="Calendar and Contacts Server"
LABEL org.opencontainers.image.documentation="https://github.com/darkv/ccs-calendarserver/blob/main/README.md"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/darkv/ccs-calendarserver"
LABEL org.opencontainers.image.title="Calendar and Contacts Server"
LABEL org.opencontainers.image.url="https://github.com/darkv/ccs-calendarserver"
LABEL org.opencontainers.image.vendor="Johann Häger <johann.haeger@posteo.de>"
LABEL org.opencontainers.image.version=$BUILD_VERSION

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  gettext-base \
  git \
  libffi-dev \
  libkrb5-dev \
  libldap2-dev \
  libreadline6-dev \
  libsasl2-dev \
  libssl-dev \
  zlib1g-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/man/*

# All of the source code is in here
ADD . /home/ccs

WORKDIR /home/ccs
RUN pip install -r requirements-default.txt --no-cache-dir

# Create cache file for twisted
WORKDIR $(python -c "import site; print site.getsitepackages()[0]")/twisted/plugins
RUN python -c "from twisted.plugin import IPlugin, getPlugins; list(getPlugins(IPlugin))"

# Create all runtime directories and ensure right permissions for OC
RUN mkdir -p        /var/db/caldavd     \
                    /var/log/caldavd    \
                    /var/run/caldavd    \
                    /etc/caldavd &&     \
    chmod -R g+rwX  /home/ccs           \
                    /var/db/caldavd     \
                    /var/log/caldavd    \
                    /var/run/caldavd    \
                    /etc/caldavd &&     \
    chmod g=u       /etc/passwd

# TODO Check if everything is in this dir
VOLUME [ "/var/db/caldavd" ]

# For user defined complex configuration (e.g. accounts.xml, resources.xml)
# A configuration file can be placed at /etc/caldavd/caldavd.ext.plist
VOLUME [ "/etc/caldavd" ]

# This can be edited in docker/caldavd.plist.template > HTTPPort
EXPOSE 8080

# Some sensible defaults for config
ENV POSTGRES_HOST     tcp:postgres:5432
ENV POSTGRES_DB       postgres
ENV POSTGRES_USER     postgres
ENV POSTGRES_PASSWORD password
ENV MEMCACHED_HOST    memcached
ENV MEMCACHED_PORT    11211

# To avoid errors with OpenShift, could be any
USER 1000

# This entry point simply creates /tmp/caldavd.plist,
# using the given ENV as placeholders
ENTRYPOINT [ "/home/ccs/contrib/docker/docker_entrypoint.sh" ]
CMD [ "caldavd", "-X", "-L", "-f", "/tmp/caldavd.plist" ]
