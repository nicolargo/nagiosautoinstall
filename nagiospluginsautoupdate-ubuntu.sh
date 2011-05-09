#!/bin/sh
#
# Mise à jour automatique des Plugins Nagios sous Ubuntu
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: # sudo ./nagiospluginsautoupdate-ubuntu.sh
#
version="0.6"

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
  tar zcvfh ./nagiosplugins-backup.tgz /usr/local/nagios/libexec

  # Recuperation des sources
  cd /tmp
  mkdir src
  cd src
  echo "----------------------------------------------------"
  echo "Telechargement des sources"
  echo "Nagios Plugin version: $nagios_plugins_version"
  echo "----------------------------------------------------"
  wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-$nagios_plugins_version.tar.gz

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
if [ ! -x /usr/local/nagios/libexec/check_tcp ]; then
	echo "Les plugins Nagios ne sont pas installés sur votre système."
	exit 1
fi
update
if [ -x /usr/local/nagios/bin/nagios ]; then
	check
	restart
fi

