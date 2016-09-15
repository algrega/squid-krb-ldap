#Squid on Docker
###Active Directory/LDAP integration
---
#Quick start guide 
(More info [here](https://github.com/algrega/squid-krb-ldap/blob/master/squid-krb-ldap.md))

### DISCLAIMER
Work in progress. This is just a kind of note to myself about what I've learned about this topic during my job activity. Everything should be considered as "raw".

---

- Clone [**algrega/squid-krb-ldap**](https://github.com/algrega/squid-krb-ldap) repository

		git clone https://github.com/algrega/squid-krb-ldap.git
		
	This will create a `squid-krb-ldap` directory
	
- Create a simple domain user account your Active Directory, for example **"proxy.user"**. This will be the account that Squid will use for both Kerberos/LDAP service authentication. 

	>**Important**: Take note of the user's password
- Choose the hostname to assign to your container(s). In this guide will be: "**proxy.my.domain.com**"
- Create your keytab file using the **ktpass** command on your Windows server.

	Squid will use the keytab to first authenticate itself as a service and then to check the credentials of clients requesting to use the proxy.


		ktpass -princ HTTP/proxy.my.domain.com@MY.DOMAIN.COM -mapuser DOMAIN\proxy.user -pass ******* -crypto all -out squid.keytab

	>**Important**: The `@MY.DOMAIN.COM` part of `HTTP/proxy.my.domain.com@MY.DOMAIN.COM` must be **uppercase**

- Copy `squid.keytab` in `squid-krb-ldap` directory 
- Edit configuration files: `ntp.conf` `krb5.conf` `squid.conf` `ldappass.txt`
([more info](https://github.com/algrega/squid-krb-ldap/blob/master/squid-krb-ldap.md#-second-step-configuration-files-creation))
- Create a directory that will hold the access log files. For example **"/var/log/squid_logs"**
	
	>**Note**: If you plan to use two or more containers, for example behind a load balancer, consider a shared location (NFS or whatever meets your needs)
- Use the `docker build` command to build the image. Choose your own tag `(-t reponame/imagename:version)`. For example:

		docker build -t algrega/squid-krb-ldap:v1.0 .
		
- After a successful build, start a new container based on the newly created image.
	>**Important**: Use your preferred options but **remember to correctly set the container hostname** with the `--hostname` option. You **must** use the same hostname chosen during the [keytab creation](#ADSection). 
	Remember also to [mount](https://docs.docker.com/engine/tutorials/dockervolumes/#/mount-a-host-directory-as-a-data-volume) the logs directory created on your Docker host.

	For example:

		docker run -d --hostname proxy.my.domain.com -v /var/log/squid_logs:/var/log/squid3 algrega/squid-krb-ldap:v1.0

	>**Note**: Consider [Rancher](http://rancher.com/) to deploy and manage your dockerized applications ([Rancher documentation](http://docs.rancher.com/))