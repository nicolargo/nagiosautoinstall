#!/bin/sh
#
# Installation automatique de Nagios sous Ubuntu/Debian
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiosautoinstall-ubuntu.sh
#
version="0.93"

nagios_core_version="3"
nagios_core_subversion="3.4.1"
nagios_plugins_version="1.4.15"
nrpe_version="2.13"

apt="apt-get -q -y --force-yes"
wget="wget --no-check-certificate"

# Fonction: installation
installation() {
  # Pre-requis
  echo "----------------------------------------------------"
  echo "Installation de pre-requis / Configuration Postfix"
  echo "----------------------------------------------------"
  $apt install apache2 wget libapache2-mod-php5 build-essential libgd2-xpm-dev libperl-dev
  $apt install bind9-host dnsutils libbind9-60 libdns66 libisc60 libisccc60 libisccfg60 liblwres60 libradius1 qstat radiusclient1 snmp snmpd
  $apt install libgd2-noxpm-dev libpng12-dev libjpeg62 libjpeg62-dev
  $apt install fping libnet-snmp-perl libldap-dev libmysqlclient-dev libgnutls-dev libradiusclient-ng-dev
  $apt install libssl-dev
  $apt install bsd-mailx mailutils postfix
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
  echo "NRPE version:          $nrpe_version"
  echo "----------------------------------------------------"
  mkdir ~/$0
  cd ~/$0
  $wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$nagios_core_subversion.tar.gz
  $wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-$nagios_plugins_version.tar.gz
  $wget http://surfnet.dl.sourceforge.net/sourceforge/nagios/nrpe-$nrpe_version.tar.gz

  # Compilation de Nagios Core
  echo "----------------------------------------------------"
  echo "Compilation de Nagios Core"
  echo "----------------------------------------------------"
  cd ~/$0
  tar zxvf nagios-$nagios_core_subversion.tar.gz
  #cd nagios-$nagios_core_subversion
  cd nagios
  ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagios --enable-event-broker --enable-nanosleep --enable-embedded-perl --with-perlcache
  make all
  # Hack pb sur install HTML
  sed -i 's/for file in includes\/rss\/\*\;/for file in includes\/rss\/\*\.\*\;/g' ./html/Makefile
  sed -i 's/for file in includes\/rss\/extlib\/\*\;/for file in includes\/rss\/extlib\/\*\.\*\;/g' ./html/Makefile
  # Fin hack
  make fullinstall
  make install-config
  ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
  echo "----------------------------------------------------"
  echo "Mot de passe pour acceder a l'interface Web"
  echo "Utilisateur: nagiosadmin"
  echo "----------------------------------------------------"
  htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
  /etc/init.d/apache2 reload

  # Compilation de Nagios plugins
  echo "----------------------------------------------------"
  echo "Compilation de Nagios plugins"
  echo "----------------------------------------------------"
  cd ~/$0
  tar zxvf nagios-plugins-$nagios_plugins_version.tar.gz
  cd nagios-plugins-$nagios_plugins_version
  ./configure --with-nagios-user=nagios --with-nagios-group=nagios
  make
  make install

  # Compilation de NRPE
  cd ~/$0
  echo "----------------------------------------------------"
  echo "Compilation du plugin NRPE"
  echo "----------------------------------------------------"
  tar zxvf nrpe-$nrpe_version.tar.gz
  cd nrpe-$nrpe_version
  ./configure
  make all
  make install-plugin

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
    $wget https://raw.github.com/nicolargo/nagiosautoinstall/master/$i
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

