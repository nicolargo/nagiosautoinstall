#!/bin/sh
#
# Mise à jour automatique de Nagios sous Ubuntu/Debian
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiosautoupdate-ubuntu.sh
#
version="0.94"

nagios_core_version="3"
nagios_core_subversion="3.4.1"
nagios_plugins_version="1.4.16"
nrpe_version="2.13"

apt="apt-get -q -y --force-yes"
wget="wget --no-check-certificate"

# Fonction: installation
update() {

  # Backup
  echo "----------------------------------------------------"
  echo "Archivage de la configuration existante"
  echo "Si les choses se passe mal, on restore avec:"
  echo "# cd /"
  echo "# sudo tar zxvf ./nagios-backup.tgz"
  echo "----------------------------------------------------"
  cd /tmp
  tar zcvfh ./nagios-backup.tgz /usr/local/nagios --exclude var/archives

  # Pre-requis
  echo "----------------------------------------------------"
  echo "Installation de pre-requis / Configuration Postfix"
  echo "----------------------------------------------------"
  $apt install libperl-dev
  $apt install libssl-dev

  # Recuperation des sources
  cd /tmp
  mkdir src
  cd src
  echo "----------------------------------------------------"
  echo "Telechargement des sources"
  echo "Nagios Core version:   $nagios_core_subversion"
  echo "Nagios Plugin version: $nagios_plugins_version"
  echo "NRPE version:          $nrpe_version"
  echo "----------------------------------------------------"
  $wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$nagios_core_subversion.tar.gz
  $wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-$nagios_plugins_version.tar.gz
  $wget http://surfnet.dl.sourceforge.net/sourceforge/nagios/nrpe-$nrpe_version.tar.gz

  # Compilation de Nagios Core
  echo "----------------------------------------------------"
  echo "Compilation de Nagios Core"
  echo "----------------------------------------------------"
  cd /tmp/src
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

  # Compilation de Nagios plugins
  echo "----------------------------------------------------"
  echo "Compilation de Nagios plugins"
  echo "----------------------------------------------------"
  cd /tmp/src
  tar zxvf nagios-plugins-$nagios_plugins_version.tar.gz
  cd nagios-plugins-$nagios_plugins_version
  ./configure --with-nagios-user=nagios --with-nagios-group=nagios
  make
  make install
  make install-root

  # Compilation de NRPE
  echo "----------------------------------------------------"
  echo "Compilation du plugin NRPE"
  echo "----------------------------------------------------"
  cd /tmp/src
  tar zxvf nrpe-$nrpe_version.tar.gz
  cd nrpe-$nrpe_version
  ./configure
  make all
  make install-plugin

  # On fixe les droits
  chown -R nagios:nagios /usr/local/nagios

  # On supprime les fichiers temporaires
  cd /tmp
  rm -rf ./src
}

# Fonction: Verifie si Nagios les fichiers de conf sont OK
check() {
  echo "----------------------------------------------------"
  echo "Verification des fichiers de configuration de Nagios"
  echo "----------------------------------------------------"
  /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
}

# Fonction: Lancement de Nagios
restart() {
  echo "----------------------------------------------------"
  echo "Redemarrage de Nagios / NRPE"
  echo "----------------------------------------------------"
  /etc/init.d/nagios-nrpe-server restart
  /etc/init.d/nagios restart
}

# Programme principal
if [ "$(id -u)" != "0" ]; then
	echo "Il faut les droits d'administration pour lancer ce script."
	echo "Syntaxe: sudo $0"
	exit 1
fi
if [ ! -x /usr/local/nagios/bin/nagios ]; then
	echo "Nagios n'est pas installé sur votre système."
	echo "Pour installer Nagios, utilisez le script nagiosautoinstall-ubuntu.sh"
	exit 1
fi
update
check
restart

