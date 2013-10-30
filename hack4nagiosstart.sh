#!/bin/sh
#
# Hack for Nagios 4.0 and 4.0.1
#
# Solve following issue on daemon script:
# /etc/init.d/nagios start
# /etc/init.d/nagios: 20: .: Can't open /etc/rc.d/init.d/functions
# 
# Nicolargo - 2013 - GPL

sudo apt-get install daemon
if [ ! -e /etc/rc.d/init.d/functions ]; 
    then 
        sudo sed -i 's/^\.\ \/etc\/rc.d\/init.d\/functions$/\.\ \/lib\/lsb\/init-functions/g' /etc/init.d/nagios
        sudo sed -i 's/status\ /status_of_proc\ /g' /etc/init.d/nagios
        sudo sed -i 's/daemon\ --user=\$user\ \$exec\ -ud\ \$config/daemon\ --user=\$user\ --\ \$exec\ -d\ \$config/g' /etc/init.d/nagios
        sudo sed -i 's/\/var\/lock\/subsys\/\$prog/\/var\/lock\/\$prog/g' /etc/init.d/nagios
    fi
sudo service nagios start