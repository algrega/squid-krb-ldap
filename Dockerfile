FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
ntp wget vim-tiny krb5-user squid3 ldap-utils \
libsasl2-modules-gssapi-mit libsasl2-modules \ 
&& rm -rf /var/lib/apt/lists/*

WORKDIR /root
COPY krb5.conf /etc/krb5.conf
COPY ntp.conf /etc/ntp.conf
COPY squid3 /etc/default/squid3
COPY squid.conf /etc/squid3/squid.conf
COPY ldappass.txt /etc/squid3/ldappass.txt
COPY entrypoint.sh /sbin/entrypoint.sh
COPY squid.keytab /etc/squid3/squid.keytab

RUN chmod 755 /sbin/entrypoint.sh
RUN ln -fs /usr/share/zoneinfo/Europe/Rome /etc/localtime
RUN chmod o-r /etc/squid3/ldappass.txt && chgrp proxy /etc/squid3/ldappass.txt

EXPOSE 3128/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
