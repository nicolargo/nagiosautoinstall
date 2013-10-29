#!/bin/sh
#
# Installation automatique de Nagios sous Ubuntu/Debian
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiosautoinstall-ubuntu.sh
#
version="4.0.1_02"

nagios_core_version="4"
nagios_core_subversion="4.0.1"
nagios_plugins_version="1.5"
nrpe_version="2.15"

nagios_user="nagios"
nagios_group="nagios"

nagiosweb_user="nagiosadmin"

###################################
# Do not touch code under this line

apt="apt-get -q -y --force-yes"
wget="wget --no-check-certificate -c"
check_x64=`uname -a | grep -e "_64"`

# Fonction: installation
installation() {
  # Pre-requis
  echo "----------------------------------------------------"
  echo "Install common libs and configuration Postfix"
  echo "----------------------------------------------------"
  $apt install apache2 wget libapache2-mod-php5 build-essential libgd2-xpm-dev libperl-dev rrdtool librrds-perl
  $apt install bind9-host dnsutils bind9utils libradius1 qstat radiusclient1 snmp snmpd
  $apt install libpng12-dev libjpeg62 libjpeg62-dev
  $apt install fping libnet-snmp-perl libldap-dev libmysqlclient-dev libgnutls-dev libradiusclient-ng-dev
  $apt install libssl-dev openssl-blacklist openssl-blacklist-extra
  $apt install bsd-mailx mailutils postfix
  ln -s /usr/bin/mail /bin/mail

  # Creation de l'utilisateur nagios et du groupe nagios
  echo "----------------------------------------------------"
  echo "Create the Nagios user and group"
  echo "Nagios user:  ${nagios_user}"
  echo "Nagios group: ${nagios_group}"  
  echo "----------------------------------------------------"
  echo "Add the Nagios user account (${nagios_user}) in the www-data group"
  useradd -m -G www-data -s /bin/bash ${nagios_user}
  echo "Set a password for the Nagios user account (${nagios_user})"
  passwd ${nagios_user}

  # Recuperation des sources
  echo "----------------------------------------------------"
  echo "Download sources"
  echo "Nagios Core version:   ${nagios_core_subversion}"
  echo "Nagios Plugin version: ${nagios_plugins_version}"
  echo "NRPE version:          ${nrpe_version}"
  echo "----------------------------------------------------"
  mkdir ~/nagiosinstall
  cd ~/nagiosinstall
  $wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-${nagios_core_subversion}.tar.gz
  $wget https://www.nagios-plugins.org/download/nagios-plugins-${nagios_plugins_version}.tar.gz
  $wget http://surfnet.dl.sourceforge.net/sourceforge/nagios/nrpe-${nrpe_version}.tar.gz

  # Compilation de Nagios Core
  echo "----------------------------------------------------"
  echo "Nagios Core compilation"
  echo "----------------------------------------------------"
  cd ~/nagiosinstall
  tar zxvf nagios-${nagios_core_subversion}.tar.gz
  cd nagios-${nagios_core_subversion}
  ./configure --with-nagios-user=${nagios_user} --with-nagios-group=${nagios_group} --with-command-user=${nagios_user} --with-command-group=$nagios_group --enable-event-broker --enable-nanosleep --enable-embedded-perl --with-perlcache
  make all
  make fullinstall
  make install-config
  ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
  
  echo "----------------------------------------------------"
  echo "Hack for Nagios 4.0 and 4.0.1"
  echo "Solve following issue on daemon script"
  echo "----------------------------------------------------"
  apt-get install daemon
  if [ !  -e /etc/rc.d/init.d/functions ]; 
    then 
        sudo sed -i 's/^\.\ \/etc\/rc.d\/init.d\/functions$/\.\ \/lib\/lsb\/init-functions/g' /etc/init.d/nagios
        sudo sed -i 's/status\ /status_of_proc\ /g' /etc/init.d/nagios
    fi

  echo "----------------------------------------------------"
  echo "Set the password for the Nagios Web interface account"
  echo "Nagios web interface account: $nagiosweb_user"
  echo "----------------------------------------------------"
  htpasswd -c /usr/local/nagios/etc/htpasswd.users ${nagiosweb_user}
  /etc/init.d/apache2 reload

  # Compilation de Nagios plugins
  echo "----------------------------------------------------"
  echo "Nagios plugins compilation"
  echo "----------------------------------------------------"
  cd ~/nagiosinstall
  tar zxvf nagios-plugins-${nagios_plugins_version}.tar.gz
  cd nagios-plugins-${nagios_plugins_version}
  ./configure --with-nagios-user=${nagios_user} --with-nagios-group=${nagios_group} --enable-extra-opts
  make
  make install

  # Compilation de NRPE
  cd ~/nagiosinstall
  echo "----------------------------------------------------"
  echo "NRPED compilation"
  echo "----------------------------------------------------"
  tar zxvf nrpe-${nrpe_version}.tar.gz
  cd nrpe-${nrpe_version}
	if [[ ${check_x64} -ne 0 ]]; then
		./configure --with-nagios-user=${nagios_user} --with-nagios-group=${nagios_group} --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu --enable-command-args --enable-ssl
	else
		./configure --with-nagios-user=${nagios_user} --with-nagios-group=${nagios_group} --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib --enable-command-args --enable-ssl
	fi
  make all
  make install-plugin && make install-daemon && make install-daemon-config && make install-xinetd

  # Installation des plugins additionnels
  plugins_list="check_ddos.pl check_memory check_url.pl"
  echo "----------------------------------------------------"
  echo "Install additionals plugins for Nagios"
  echo ${plugins_list}
  echo "----------------------------------------------------"
  cd /usr/local/nagios/libexec
  for i in `echo ${plugins_list}`
  do
    rm -f $i > /dev/null
    $wget https://raw.github.com/nicolargo/nagiosautoinstall/master/$i
    chmod a+rx $i
    chown ${nagios_user}:${nagios_group} $i
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
  rm -rf ~/nagiosinstall
}

# Fonction: Verifie si Nagios les fichiers de conf sont OK
check() {
  echo "----------------------------------------------------"
  echo "Check the Nagios configuration"
  echo "----------------------------------------------------"
  /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
}

# Fonction: Lancement de Nagios
start() {
  echo "----------------------------------------------------"
  echo "Run Nagios"
  echo "----------------------------------------------------"
  /etc/init.d/nagios start
  echo "Nagios Web interface URL:     http://localhost/nagios/"
  echo "Nagios Web interface account: ${nagiosweb_user}"
}

# Programme principal
if [ "$(id -u)" != "0" ]; then
	echo "You need admin (root) right to run the script."
	echo "Syntax: sudo $0"
	exit 1
fi
installation
check
start

