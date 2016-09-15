#!/bin/bash

# Setting variables
export KRB5_KTNAME=/etc/squid3/squid.keytab
export CONTAINER_ID=$(cat /proc/1/cgroup | grep 'docker/' | tail -1 | sed 's/^.*\///' | cut -c 1-12)
export SQUID_CONF="/etc/squid3/squid.conf"
export RND_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
export SQUID_LOG="access_log stdio:/var/log/squid3/access_$CONTAINER_ID.$RND_ID.log squid"
export SQUID_CACHE_LOG="cache_log /var/log/squid3/cache_$CONTAINER_ID.$RND_ID.log"
export SQUID_NETDB_STATE="netdb_filename stdio:/var/log/squid3/netdb_$CONTAINER_ID.$RND_ID.state"

# Check if access_log directive already exists in squid configuration
grep access_log $SQUID_CONF > /dev/null

if [ $? -eq 0 ]
then
  echo""
  echo "access_log directive already exists. Reusing it"
  echo""
else
  echo""
  echo "access_log directive does not exists"
  echo "Setting access logfile to access_$CONTAINER_ID.$RND_ID.log"
  echo $SQUID_LOG >> $SQUID_CONF 
  echo""
fi

# Check if cache_log directive already exists in squid configuration
grep cache_log $SQUID_CONF > /dev/null

if [ $? -eq 0 ]
then
  echo""
  echo "cache_log directive already exists. Reusing it"
  echo""
else
  echo""
  echo "cache_log directive does not exists"
  echo "Setting cache logfile to cache_$CONTAINER_ID.$RND_ID.log"
  echo $SQUID_CACHE_LOG >> $SQUID_CONF
  echo""
fi

# Check if netdb_filename directive already exists in squid configuration
grep netdb_filename $SQUID_CONF > /dev/null

if [ $? -eq 0 ]
then
  echo""
  echo "netdb_filename directive already exists. Reusing it"
  echo""
else
  echo""
  echo "netdb_filename directive does not exists"
  echo "Setting netdb_filename to netdb_$CONTAINER_ID.$RND_ID.state"
  echo $SQUID_NETDB_STATE >> $SQUID_CONF
  echo""
fi

chown -R proxy:proxy /var/log/squid3
service ntp start
squid3 -NYCd 1
