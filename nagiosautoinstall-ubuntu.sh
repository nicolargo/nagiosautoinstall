#!/bin/sh
#
# Installation automatique de Nagios sous Ubuntu 9.10
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiosautoinstall-ubuntu.sh
#
version="0.71"

nagios_core_version="3"
nagios_core_subversion="3.2.3"
nagios_plugins_version="1.4.15"

# Fonction: installation
installation() {
  # Pre-requis
  echo "----------------------------------------------------"
  echo "Installation de pre-requis / Configuration Postfix"
  echo "----------------------------------------------------"
  aptitude install apache2 wget libapache2-mod-php5 build-essential libgd2-xpm-dev 
  aptitude install bind9-host dnsutils libbind9-60 libdns66 libisc60 libisccc60 libisccfg60 liblwres60 libradius1 qstat radiusclient1 snmp snmpd
  aptitude install libgd2-noxpm-dev libpng12-dev libjpeg62 libjpeg62-dev
  aptitude install fping libnet-snmp-perl libldap-dev libmysqlclient-dev libgnutls-dev libradiusclient-ng-dev
  aptitude install mailx postfix
  ln -s /usr/bin/mail /bin/mail

  # Creation de l'utilisateur nagios et du groupe nagios
  echo "----------------------------------------------------"
  echo "Creation utilisateur nagios et groupe nagios"
  echo "----------------------------------------------------"
  useradd -M -s /bin/noshellneeded nagios
  echo "Fixer un mot de passe pour l'utilisateur nagios"
  passwd nagios
  groupadd nagios
  usermod -G nagios nagios
  usermod -G nagios www-data 

  # Recuperation des sources
  echo "----------------------------------------------------"
  echo "Telechargement des sources"
  echo "Nagios Core version:   $nagios_core_subversion"
  echo "Nagios Plugin version: $nagios_plugins_version"
  echo "----------------------------------------------------"
  mkdir ~/$0
  cd ~/$0
  wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$nagios_core_subversion.tar.gz
  wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-$nagios_plugins_version.tar.gz

  # Compilation de Nagios Core
  echo "----------------------------------------------------"
  echo "Compilation de Nagios Core"
  echo "----------------------------------------------------"
  tar zxvf nagios-$nagios_core_subversion.tar.gz
  cd nagios-$nagios_core_subversion
  ./configure --with-command-group=nagios
  make all
  make install
  make install-config
  make install-commandmode
  make install-init
  ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
  make install-webconf
  echo "----------------------------------------------------"
  echo "Mot de passe pour acceder a l'interface Web"
  echo "Utilisateur: nagiosadmin"
  echo "----------------------------------------------------"
  htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
  /etc/init.d/apache2 reload
  cd ..

  # Compilation de Nagios plugins
  echo "----------------------------------------------------"
  echo "Compilation de Nagios plugins"
  echo "----------------------------------------------------"
  tar zxvf nagios-plugins-$nagios_plugins_version.tar.gz
  cd nagios-plugins-$nagios_plugins_version
  ./configure --with-nagios-user=nagios --with-nagios-group=nagios
  make
  make install
  cd ..

  # Installation des plugins additionnels
  plugins_list="check_ddos.pl check_memory check_url.pl"
  echo "----------------------------------------------------"
  echo "Telechargement des plugins additionnels"
  echo $plugins_list
  echo "----------------------------------------------------"
  cd /usr/local/nagios/libexec
  for i in `echo $plugins_list`
  do
    rm -f $i > /dev/null
    wget http://svn.nicolargo.com/nagiosautoinstall/trunk/$i
    chmod a+rx $i
    chown nagios:nagios $i
    # Conf file
    grep $i /usr/local/nagios/etc/objects/commands.cfg > /dev/null
    if [ $? -ne 0 ]
    then
	case $i in
      	"check_ddos.pl")
	  cat >> /usr/local/nagios/etc/objects/commands.cfg << EOF

# check_ddos
define command{
    command_name check_ddos
    command_line \$USER1\$/check_ddos.pl -w \$ARG1\$ -c \$ARG2\$
}
EOF
	;;
      	"check_memory")
	cat >> /usr/local/nagios/etc/objects/commands.cfg << EOF

# CheckMemory
define command{
        command_name    check_memory
        command_line    \$USER1\$/check_memory -w \$ARG1\$ -c \$ARG2\$
        }
EOF
	;;
       "check_url.pl")
	cat >> /usr/local/nagios/etc/objects/commands.cfg << EOF

# CheckURL
# \$ARG1\$: URL a tester (exemple: http://blog.nicolargo.com/sitemap.xml)
define command{
    command_name check_url
    command_line \$USER1\$/check_url.pl \$ARG1\$
}
EOF
	;;      
    	esac
    fi
  done
  cd -

  # On supprime les fichiers temporaires  
  cd ~
  rm -rf ~/$0 
}

# Fonction: Verifie si Nagios les fichiers de conf sont OK
check() {
  echo "----------------------------------------------------"
  echo "Verification des fichiers de configuration de Nagios"
  echo "----------------------------------------------------"
  /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
}   

# Fonction: Lancement de Nagios
start() {
  echo "----------------------------------------------------"
  echo "Lancement de Nagios"
  echo "----------------------------------------------------"
  /etc/init.d/nagios start
  echo "Interface d'administration par cet URL: http://localhost/nagios/"
  echo "Utilisateur: nagiosadmin"
}

# Programme principal
if [ "$(id -u)" != "0" ]; then
	echo "Il faut les droits d'administration pour lancer ce script."
	echo "Syntaxe: sudo $0"
	exit 1
fi
installation
check
start

