# Squid on Docker
### Active Directory/LDAP integration
---

### DISCLAIMER
Work in progress. This is just a kind of note to myself about what I've learned about this topic during my job activity. Everything should be considered as "raw".

### Introduction
Purpose of this article is to describe the process to build a containerized and scalable Proxy service image that can be deployed in a [Docker](https://www.docker.com/) environment.

[Squid](http://www.squid-cache.org/) proxy will authenticate users in Active Directory using Kerberos or LDAP.

The first type of authentication will be transparent for all the clients already joined to Active Directory: users won't be asked for their user/password because the browser will manage the Kerberos authentication.

The second type of authentication will be used for all the clients who have a valid Active Directory user account but can't use Kerberos for any reason.

Non authenticated users won't be allowed to use the proxy.


**In the next steps we are going to do the necessary steps on Active Directory and then create the files needed by the [Dockerfile](https://docs.docker.com/engine/reference/builder/) to build the final Docker image.**


<br>
### Environment

- Active Directory Windows 2012 r2: **my.domain.com**
- Docker v1.12.0
- Container with Squid 3.4.8 on Debian (jessie in this case)
- Container hostname: **proxy.my.domain.com**

<br>
### Requirements of the Squid container
- no AD join of the proxy server
	- no samba related library to install (smaller container image)
	- minimum [AD configuration](#ADSection)
- negotiate [kerberos/LDAP authentication](#KRBSection)
- basic [ACL](#SQUIDSection) - only authorized users
- same hostname for every running container
	- this way containers will use the same keytab file
- centralization and persistence of access log files
	- logs will be written on the docker host or to a shared location

<br>

## Configuration

### <a name="ADSection"></a> First step: Active Directory
- Create a simple domain user account, for example **"proxy.user**". This will be the account that Squid will use for both Kerberos/LDAP service authentication. 
>**Important**: Take note of the user's password

- In order to authenticate users via Kerberos, create a [keytab](https://kb.iu.edu/d/aumh#intro) file using the **ktpass** command on your Windows server. Squid will use the keytab to first authenticate itself as a service and then to check the credentials of clients requesting to use the proxy.


		ktpass -princ HTTP/proxy.my.domain.com@MY.DOMAIN.COM -mapuser DOMAIN\proxy.user -pass ******* -crypto all -out squid.keytab

	>**Important**: The `@MY.DOMAIN.COM` part of `HTTP/proxy.my.domain.com@MY.DOMAIN.COM` must be **uppercase**

<br>
### <a name="CONFSection"></a> Second step: Configuration files creation

> **Note**: You can find all the informations about how to build your own Docker image [here](https://docs.docker.com/engine/tutorials/dockerimages/)

- **<a name="NTPSection"></a>NTP Configuration file**

	Kerberos needs to have the time syncronised with Windows Domain Controllers.
	
	Create a **ntp.conf** file like the following and edit the `server` lines with your AD Domain Controller adresses. 
	
	For example:
		
		
		driftfile /var/lib/ntp/ntp.drift
		statistics loopstats peerstats clockstats
		filegen loopstats file loopstats type day enable
		filegen peerstats file peerstats type day enable
		filegen clockstats file clockstats type day enable
		
		# Your Domain Controller(s)
		server dc01.my.domain.com
		server dc02.my.domain.com
		server dc03.my.domain.com
		server dc04.my.domain.com
		
		restrict -4 default kod notrap nomodify nopeer noquery
		restrict -6 default kod notrap nomodify nopeer noquery
		restrict 127.0.0.1
		restrict ::1
	
<br>

- **<a name="KRBSection"></a>Kerberos Configuration file**
	
	Create a **krb5.conf** file like the following and edit the `default_realm` line in `[libdefaults]` section, the `[realms]` and `[domain_realm]` sections according to your Active Directory informations.
	
	For example:
	
			
		[libdefaults]
    	default_realm = MY.DOMAIN.COM
    	dns_lookup_kdc = no
    	dns_lookup_realm = no
    	ticket_lifetime = 24h
    	default_keytab_name = /etc/squid3/squid.keytab

		# For Windows 2003
		# default_tgs_enctypes = rc4-hmac des-cbc-crc des-cbc-md5
		# default_tkt_enctypes = rc4-hmac des-cbc-crc des-cbc-md5
		# permitted_enctypes = rc4-hmac des-cbc-crc des-cbc-md5

		# For Windows 2008/2012 with AES
    	default_tgs_enctypes = aes256-cts-hmac-sha1-96 rc4-hmac des-cbc-crc des-cbc-md5
    	default_tkt_enctypes = aes256-cts-hmac-sha1-96 rc4-hmac des-cbc-crc des-cbc-md5
    	permitted_enctypes = aes256-cts-hmac-sha1-96 rc4-hmac des-cbc-crc des-cbc-md5

		[realms]
    	MY.DOMAIN.COM = {
		kdc = dc01.my.domain.com
		kdc = dc02.my.domain.com
		kdc = dc03.my.domain.com
		kdc = dc04.my.domain.com 
		admin_server = dc01.my.domain.com
		default_domain = my.domain.com
    	}

		[domain_realm]
    	.my.domain.com = MY.DOMAIN.COM
    	my.domain.com = MY.DOMAIN.COM
    	
    <br>

- **<a name="SQUIDSection"></a>Squid Configuration files**


	- Create a **squid3** file containing the following text
	
			KRB5_KTNAME=/etc/squid3/squid.keytab
			export KRB5_KTNAME
	
		this file is read by Squid at startup and basically tells which keytab 		file to use for the service authentication
	
	<br>
	
	- Create a **ldappass.txt** file containing the password of the [Active Directory user previously created](#ADSection).

		>**Important**: this file contains a plaintext password. Even though is of a low privilege AD account it should be readable only by the Squid process.
	
			-rw-r----- 1 root proxy   36 Sep  6 16:54 ldappass.txt
	<br>
		
	- Create the **squid.conf** file  

	

			### Squid.conf Configuration File ####

			### cache manager
			cache_mgr your_email@my.domain.com

			### Negotiate kerberos authentication
			auth_param negotiate program /usr/lib/squid3/negotiate_kerberos_auth
			auth_param negotiate children 10
			auth_param negotiate keep_alive on

			### Provide basic authentication via ldap for clients not authenticated via kerberos
			auth_param basic program /usr/lib/squid3/basic_ldap_auth -Z -R -b "dc=my,dc=domain,dc=com" -D proxy.user@my.domain.com -W /etc/squid3/ldappass.txt -f sAMAccountName=%s -h dc01.my.domain.com
			auth_param basic children 10
			auth_param basic realm Internet Proxy
			auth_param basic credentialsttl 1 minute


			acl auth proxy_auth REQUIRED

			http_access deny !auth
			http_access allow auth
			http_access deny all

			### squid defaults
			acl SSL_ports port 443
			acl Safe_ports port 80          # http
			acl Safe_ports port 21          # ftp
			acl Safe_ports port 443         # https
			acl Safe_ports port 70          # gopher
			acl Safe_ports port 210         # wais
			acl Safe_ports port 1025-65535  # unregistered ports
			acl Safe_ports port 280         # http-mgmt
			acl Safe_ports port 488         # gss-http
			acl Safe_ports port 591         # filemaker
			acl Safe_ports port 777         # multiling http
			acl CONNECT method CONNECT
			http_access allow manager localhost
			http_access deny manager
			http_access deny !Safe_ports
			http_access deny CONNECT !SSL_ports
			http_access allow localhost


			### squid Debian defaults
			http_port 3128
			hierarchy_stoplist cgi-bin ?
			coredump_dir /var/spool/squid3
			refresh_pattern ^ftp:           1440    20%     10080
			refresh_pattern ^gopher:        1440    0%      1440
			refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
			refresh_pattern .               0       20%     4320

			### logging added dinamically on container startup by entrypoint.sh
			
					
				
		>**Important**: The **`logging`** section must be empty. It will be added dynamically on container startup to ensure file names uniqueness. Considering that we want persistence and centralization of logs, in this way we will have a unique log file per container, regardless the number of running containers.  
		
		>**Note**: This is a very simple example. Squid has many configuration directives and extensive access controls. Refer to its [documentation](http://www.squid-cache.org/Doc/) to find the configuration that meets your needs.
		 
	<br>
- **<a name="ENTRYPOINTSection"></a>Entrypoint script**

	Create a **entrypoint.sh** file. In few words this script will be executed just after the container startup.
	>**Note**: See [Entrypoint](https://docs.docker.com/engine/reference/builder/#/entrypoint) section of Docker documentation for further reading.

			
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
		
	This script does the following operations:
	- Creates a unique identifier composed by the ID of the running container plus a random string. The created string will be part of the log files name
	- Checks if the log files already exist. Useful in case you stop and restart the container otherwise you will have a duplicate `access_log` directive for every container restart
	-  Sets the correct permissions on the logs directory
	-  Starts the NTP service
	-  Starts Squid daemon

	
<br>
### <a name="DOCKERSection"></a> Third step: Dockerfile
>**Note**: All the next steps must be done on a machine with Docker installed

- Create a directory that will hold the access log files. For example **"/var/log/squid_logs"**
	
	>**Note**: If you plan to use two or more containers, for example behind a load balancer, consider a shared location (NFS or whatever meets your needs) 
- Create a directory that will hold all the files related to the Docker image we're going to build. For example **"proxy"**.
- Copy all the previously created files in this directory including the `squid.keytab`
- Into the same directory, create a **Dockerfile** like the following

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

- Use the `docker build` command to build the image. Choose your own tag `(-t reponame/imagename:version)`. For example:

		docker build -t algrega/squid-krb-ldap:v1.0 .
		
- After a successful build, we can start our new container based on the newly created image.
	>**Important**: Use your preferred options but **remember to correctly set the container hostname** with the `--hostname` option. You **must** use the same hostname chosen during the [keytab creation](#ADSection). 
	Remember also to [mount](https://docs.docker.com/engine/tutorials/dockervolumes/#/mount-a-host-directory-as-a-data-volume) the logs directory created on your Docker host.

	For example:

		docker run -d --hostname proxy.my.domain.com -v /var/log/squid_logs:/var/log/squid3 algrega/squid-krb-ldap:v1.0
		
	>**Note**: Consider [Rancher](http://rancher.com/) to deploy and manage your dockerized applications ([Rancher documentation](http://docs.rancher.com/))