#!/bin/sh
#
# Mise à jour automatique de Nagios sous Ubuntu 9.10
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiosautoupdate-ubuntu.sh
#
version="0.7"

nagios_core_version="3"
nagios_core_subversion="3.2.3"
nagios_plugins_version="1.4.15"

# Fonction: installation
update() {
  # Pre-requis
  # echo "----------------------------------------------------"
  # echo "Mise à jour du système"
  # echo "----------------------------------------------------"
  # aptitude -y update
  # aptitude -y upgrade

  # Backup
  echo "----------------------------------------------------"
  echo "Archivage de la configuration existante"
  echo "Si les choses se passe mal, on restore avec:"
  echo "# cd /"
  echo "# sudo tar zxvf ./nagios-backup.tgz"
  echo "----------------------------------------------------"
  cd /tmp
  tar zcvfh ./nagios-backup.tgz /usr/local/nagios --exclude var/archives
  cp /usr/local/nagios/share/side.php side.php.MODIF


  # Recuperation des sources
  cd /tmp
  mkdir src
  cd src
  echo "----------------------------------------------------"
  echo "Telechargement des sources"
  echo "Nagios Core version:   $nagios_core_subversion"
  echo "Nagios Plugin version: $nagios_plugins_version"
  echo "----------------------------------------------------"
  wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$nagios_core_subversion.tar.gz
  wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-$nagios_plugins_version.tar.gz

  # Compilation de Nagios Core
  echo "----------------------------------------------------"
  echo "Compilation de Nagios Core"
  echo "----------------------------------------------------"
  cd /tmp/src
  tar zxvf nagios-$nagios_core_subversion.tar.gz
  cd nagios-$nagios_core_subversion
  ./configure --with-command-group=nagios
  make all
  make install
  cp /usr/local/nagios/share/side.php /tmp/side.php.DEFAULT
  cp /tmp/side.php.MODIF /usr/local/nagios/share/side.php

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
  echo "Redemarrage de Nagios"
  echo "----------------------------------------------------"
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

