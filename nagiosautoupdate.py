#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Mise à jour automatique de Nagios sous Ubuntu/Debian
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: (as root)
#	./nagiosautoupdate.py
#
# Nicolargo (aka) Nicolas Hennion
# http://www.nicolargo.com
#

"""
Update Nagios Core / Nagios Plugin / NRPE to the latest version
"""

import os, sys, platform, getopt, shutil, logging, getpass

# Global variables
#-----------------------------------------------------------------------------

_VERSION="0.96"
_DEBUG = 0
log_file = "/tmp/nagiosautoupdate.log"

nagios_core_subversion="3.4.3"
nagios_plugins_version="1.4.16"
nrpe_version="2.13"

# Classes
#-----------------------------------------------------------------------------

class colors:
	RED = '\033[91m'
	GREEN = '\033[92m'
	BLUE = '\033[94m'
	ORANGE = '\033[93m'
	NO = '\033[0m'

	def disable(self):
		self.RED = ''
		self.GREEN = ''
		self.BLUE = ''
		self.ORANGE = ''
		self.NO = ''

# Functions
#-----------------------------------------------------------------------------

def init():
	"""
	Init the script
	"""
	# Globals variables
	global _VERSION
	global _DEBUG

	# Set the log configuration
	logging.basicConfig(
		filename=log_file,
		level=logging.DEBUG,
		format='%(asctime)s %(levelname)s - %(message)s',
	 	datefmt='%d/%m/%Y %H:%M:%S',
	 )

def syntax():
  """
  Print the script syntax
  """
  print "This script should be run as root."
  print "Some options: -d to debug / -v to print the version and exit"

def version():
	"""
	Print the script version
	"""
	sys.stdout.write ("Script version %s" % _VERSION)
	sys.stdout.write (" (running on %s %s)\n" % (platform.system() , platform.machine()))

def isroot():
	"""
	Check if the user is root
	Return TRUE if user is root
	"""
	return (os.geteuid() == 0)

def showexec(description, command, exitonerror = 0):
	"""
	Exec a system command with a pretty status display (Running / Ok / Warning / Error)
	By default (exitcode=0), the function did not exit if the command failed
	"""

	if _DEBUG:
		logging.debug ("%s" % description)
		logging.debug ("%s" % command)

	# Manage very long description
	if (len(description) > 65):
		description = description[0:65] + "..."

	# Display the command
	status = "[Running]"
	statuscolor = colors.BLUE
	sys.stdout.write (colors.NO + "%s" % description + statuscolor + "%s" % status.rjust(79-len(description)) + colors.NO)
	sys.stdout.flush()

	# Run the command
	returncode = os.system ("/bin/sh -c \"%s\" >> %s 2>&1" % (command, log_file))

	# Display the result
	if returncode == 0:
		status = "[  OK   ]"
		statuscolor = colors.GREEN
	else:
		if exitonerror == 0:
			status = "[Warning]"
			statuscolor = colors.ORANGE
		else:
			status = "[ Error ]"
			statuscolor = colors.RED

	sys.stdout.write (colors.NO + "\r%s" % description + statuscolor + "%s\n" % status.rjust(79-len(description)) + colors.NO)

	if _DEBUG:
		logging.debug ("Returncode = %d" % returncode)

	# Stop the program if returncode and exitonerror != 0
	if ((returncode != 0) & (exitonerror != 0)):
		if _DEBUG:
			logging.debug ("Forced to quit")
		exit(exitonerror)

def getpassword(description = ""):
	"""
	Read password (with confirmation)
	"""

	if (description != ""):
		sys.stdout.write ("%s\n" % description)

	password1 = getpass.getpass("Password: ");
	password2 = getpass.getpass("Password (confirm): ");

	if (password1 == password2):
		return password1
	else:
		sys.stdout.write (colors.ORANGE + "[Warning] Password did not match, please try again" + colors.NO + "\n")
		return getpassword()

def	nagiosbackup():
	"""
	Backup the current Nagios configuration in the /tmp/nagios-backup.tgz file
	"""

	showexec ("Backup the current Nagios configuration",
            "tar zcvfh /tmp/nagios-backup.tgz /usr/local/nagios --exclude var/archives")

def nagiosupdate():
  """
  Update Nagios Core + plugins + NRPE
  """

  # Double check if the libperl-dev is installed
  showexec ("Install prerequisites",
            "apt-get -q -y --force-yes install libperl-dev libssl-dev", 1)

  # Download sources
  showexec ("Download Nagios Core version %s" % nagios_core_subversion,
            "wget --no-check-certificate -c -O /tmp/nagios-%s.tar.gz http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-%s.tar.gz" % (nagios_core_subversion, nagios_core_subversion), 1)
  showexec ("Download Nagios Plugins version %s" % nagios_plugins_version,
            "wget --no-check-certificate -c -O /tmp/nagios-plugins-%s.tar.gz http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-%s.tar.gz" % (nagios_plugins_version, nagios_plugins_version), 1)
  showexec ("Download NRPE version %s" % nrpe_version,
            "wget --no-check-certificate -c -O /tmp/nrpe-%s.tar.gz http://surfnet.dl.sourceforge.net/sourceforge/nagios/nrpe-%s.tar.gz" % (nrpe_version, nrpe_version), 1)

  # Update Nagios Core
  showexec ("Uncompress Nagios Core" ,
            "cd /tmp ; tar zxvf nagios-%s.tar.gz" % nagios_core_subversion, 1)
  showexec ("Configure Nagios Core" ,
            "cd /tmp/nagios ; ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagios --enable-event-broker --enable-nanosleep --enable-embedded-perl --with-perlcache", 1)
  showexec ("Make Nagios Core" ,
            "cd /tmp/nagios ; make all", 1)
  showexec ("Correct a bug in the installer (http://bit.ly/roq2ea)" ,
            "cd /tmp/nagios/html ; sed -i 's/for file in includes\/rss\/\*\;/for file in includes\/rss\/\*\.\*\;/g' ./Makefile ; sed -i 's/for file in includes\/rss\/extlib\/\*\;/for file in includes\/rss\/extlib\/\*\.\*\;/g' ./Makefile", 1)
  showexec ("Install Nagios Core" ,
            "cd /tmp/nagios ; make fullinstall", 1)

  # Update Nagios Plugins
  showexec ("Uncompress Nagios Plugins" ,
            "cd /tmp ; tar zxvf nagios-plugins-%s.tar.gz" % nagios_plugins_version, 1)
  showexec ("Configure Nagios Plugins" ,
            "cd /tmp/nagios-plugins-%s ; ./configure --with-nagios-user=nagios --with-nagios-group=nagios" % nagios_plugins_version, 1)
  showexec ("Make Nagios Plugins" ,
            "cd /tmp/nagios-plugins-%s ; make" % nagios_plugins_version, 1)
  showexec ("Install Nagios Core" ,
            "cd /tmp/nagios-plugins-%s ; make install; make install-root" % nagios_plugins_version, 1)

  # Update NRPE
  showexec ("Uncompress Nagios NRPE" ,
            "cd /tmp ; tar zxvf nrpe-%s.tar.gz" % nrpe_version, 1)
  showexec ("Configure Nagios NRPE" ,
            "cd /tmp/nrpe-%s ; ./configure" % nrpe_version, 1)
  showexec ("Make Nagios NRPE" ,
            "cd /tmp/nrpe-%s ; make all" % nrpe_version, 1)
  showexec ("Install Nagios NRPE" ,
            "cd /tmp/nrpe-%s ; make install-plugin" % nrpe_version, 1)

  # Set files rights
  showexec ("Set files rights to nagios:nagios" ,
            "chown -R nagios:nagios /usr/local/nagios", 1)

def nagioscheck():
  """
  Check the Nagios configuration after the upgrade
	"""

  showexec ("Check the current Nagios configuration" ,
            "/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg")

def nagiosrestart():
  """
  Restart Nagios and NRPE
  """

  showexec ("Restart NRPE", "/etc/init.d/nagios-nrpe-server restart")
  showexec ("Restart Nagios", "/etc/init.d/nagios restart")

def main(argv):
	"""
	Main function
	"""

	try:
		opts, args = getopt.getopt(argv, "hvd", ["help", "version", "debug"])
	except getopt.GetoptError:
		syntax()
		exit(2)

	for opt, arg in opts:
		if opt in ("-h", "--help"):
			syntax()
			exit()
		elif opt == '-v':
			version()
			exit()
		elif opt == '-d':
			global _DEBUG
			_DEBUG = 1

	#=================
	# Start the script
	#=================

	# Check if user is root
	if (not isroot()):
		print "This script should be run as root."
		exit(2)

	# Check if Nagios is already installed
	if (not os.path.isfile("/usr/local/nagios/bin/nagios")):
		print "Nagios is not installed on your system"
		print "or Nagios has been installed via a package manager"
		print "This script can not upgrade this configuration"
		exit(2)

	# Update
	nagiosbackup()
	nagiosupdate()
	nagioscheck()
	nagiosrestart()

# Main program
#-----------------------------------------------------------------------------

if __name__ == "__main__":
	init()
	main(sys.argv[1:])
	exit()
