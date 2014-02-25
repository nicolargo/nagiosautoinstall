#!/bin/sh
#
# Hack for Nagios 4.x
#
# Solve following issue on daemon script:
# /etc/init.d/nagios start
# /etc/init.d/nagios: 20: .: Can't open /etc/rc.d/init.d/functions
# 
# Nicolargo - 2014 - GPL

# Si on lance en tant que root sans installer sudo
if (dpkg-query -l "sudo" >/dev/null 2>&1);
    then
        sudo="sudo "
    else
        sudo=""
fi

${sudo}apt-get install daemon
if [ ! -e /etc/rc.d/init.d/functions ]; 
    then 
        ${sudo}sed -i 's/^\.\ \/etc\/rc.d\/init.d\/functions$/\.\ \/lib\/lsb\/init-functions/g' /etc/init.d/nagios
        ${sudo}sed -i 's/status\ /status_of_proc\ /g' /etc/init.d/nagios
        ${sudo}sed -i 's/daemon\ --user=\$user\ \$exec\ -ud\ \$config/daemon\ --user=\$user\ --\ \$exec\ -d\ \$config/g' /etc/init.d/nagios
        ${sudo}sed -i 's/\/var\/lock\/subsys\/\$prog/\/var\/lock\/\$prog/g' /etc/init.d/nagios
        ${sudo}sed -i 's/\/sbin\/service\ nagios\ configtest/\/usr\/sbin\/service\ nagios\ configtest/g' /etc/init.d/nagios
        ${sudo}sed -i 's/\"\ \=\=\ \"/\"\ \=\ \"/g' /etc/init.d/nagios
        ${sudo}sed -i "s/\#\#killproc\ \-p\ \${pidfile\}\ \-d\ 10/killproc\ \-p \${pidfile\}/g" /etc/init.d/nagios
        ${sudo}sed -i "s/runuser/su/g" /etc/init.d/nagios
        ${sudo}sed -i "s/use_precached_objects=\"false\"/&\ndaemonpid=\$(pidof daemon)/" /etc/init.d/nagios
        ${sudo}sed -i "s/killproc\ -p\ \${pidfile}\ -d\ 10\ \$exec/\/sbin\/start-stop-daemon\ --user=\$user\ \$exec\ --stop/g" /etc/init.d/nagios
        ${sudo}sed -i "s/\/sbin\/start-stop-daemon\ --user=\$user\ \$exec\ --stop/&\n\tkill -9 \$daemonpid/" /etc/init.d/nagios
        # options : remplacer options ligne 78 options="-d" par options="-- -d" pour éviter que le -u de la config precached
        # ne soit interprété comme un --user par la commande daemon...
        ${sudo}sed -i "s/\(options=\)\"-d\"/\1\"-- -d\"/" /etc/init.d/nagios
        # kill -9 $daemonpid : la commande daemon précedent suffit il n'y a pas d'intérêt a utiliser kill -9 sauf si 
        # $daemonpid existe encore
        ${sudo}sed -i "s/\(kill -9 $daemonpid\)/if [ $daemonpid ] ; then \1 ; fi/" /etc/init.d/nagios
    fi
${sudo}service nagios start
