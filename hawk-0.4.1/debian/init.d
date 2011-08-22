#!/bin/sh
#
#     RedHat system startup script for hawk
#
#     Copyright (C) 2010  Tim Serong, SUSE / Novell Inc.
#          
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published by
#     the Free Software Foundation; either version 2.1 of the License, or (at
#     your option) any later version.
#			      
#     This library is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#     Lesser General Public License for more details.
#      
#     You should have received a copy of the GNU Lesser General Public
#     License along with this library; if not, write to the Free Software
#     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,
#     USA.
#
### BEGIN INIT INFO
# Provides:          hawk
# Required-Start:    $syslog $remote_fs
# Should-Start:      $time
# Required-Stop:     $syslog $remote_fs
# Should-Stop:       $time
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: hawk daemon providing web GUI for Pacemaker HA clusters
# Description:       Start hawk to provide a web GUI for the Pacemaker
#	High-Availability cluster resource manager.
### END INIT INFO

# Author: unknown <hawk-package@dizopsin.net> (Debian adaptation)

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="HA Web Konsole"
NAME=hawk
DAEMON=/usr/sbin/lighttpd
PROCNAME=lighttpd
LIGHTTPD_CONFIG=/etc/hawk.conf
DAEMON_ARGS="-f $LIGHTTPD_CONFIG"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x $DAEMON ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

# Check for existence of needed config file and read it
test -r $LIGHTTPD_CONFIG || { echo "$LIGHTTPD_CONFIG does not exist";
	if [ "$1" = "stop" ]; then exit 0;
	else exit 6; fi; }

# Generate a self-signed SSL certificate if necessary.  Will not
# generate certificate if one already exists, so administrator can
# install a "real" certificate by simply replacing the generated
# (combined) one at /etc/lighttpd/certs/hawk-combined.pem
# NOTE: This is essentially a heavily stripped-back shell version
# of the more generic check-create-certificate.pl script from WebYaST.
# If this latter script becomes generally available, we should prefer
# using it over this little function here.
generate_ssl_cert() {
	openssl_bin=/usr/bin/openssl
	c_rehash_bin=/usr/bin/c_rehash
	cert_file=/etc/lighttpd/certs/hawk.pem
	cert_key_file=/etc/lighttpd/certs/hawk.key
	combined_cert_file=/etc/lighttpd/certs/hawk-combined.pem
	log_file=/usr/share/hawk/log/certificate.log
	[ -e "$combined_cert_file" ] && return 0
       
	echo "No certificate found. Creating one now."
	mkdir -p $(dirname $combined_cert_file)

	old_mask=$(umask)
	umask 177
	CN=$(hostname -f)
	[ -z "$CN" ] && CN=$(hostname)
	[ -z "$CN" ] && CN=localhost
	$openssl_bin req -newkey rsa:2048 -x509 -nodes -days 1095 -batch -config /dev/fd/0 -out $cert_file -keyout $cert_key_file >$log_file 2>&1 <<CONF
[req]
distinguished_name = user_dn
prompt = no
[user_dn]
commonName=$CN
emailAddress=root@$CN
organizationName=HA Web Konsole
organizationalUnitName=Automatically Generated Certificate
CONF
	rc=$?
	if [ $rc -eq 0 ]; then
		cat $cert_key_file $cert_file > $combined_cert_file
		[ -x "$c_rehash_bin" ] && $c_rehash_bin $(dirname $combined_cert_file) >/dev/null 2>&1
	else
		echo "Could not generate certificate.  Please see $log_file for details"
	fi
	umask $old_mask
	return $rc
}

#
# Function that starts the daemon/service
#
do_start()
{
        generate_ssl_cert || {
                return 2
        }

        # Return
        #   0 if daemon has been started
        #   1 if daemon was already running
        #   2 if daemon could not be started
        start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
                || return 1
        start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- \
                $DAEMON_ARGS \
                || return 2
        # Add code here, if necessary, that waits for the process to be ready
        # to handle requests from services started subsequently which depend
        # on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
        # Return
        #   0 if daemon has been stopped
        #   1 if daemon was already stopped
        #   2 if daemon could not be stopped
        #   other if a failure occurred
        start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $PROCNAME
        RETVAL="$?"
        [ "$RETVAL" = 2 ] && return 2
        # Wait for children to finish too if this is a daemon that forks
        # and if the daemon is only ever run from this initscript.
        # If the above conditions are not satisfied then add some other code
        # that waits for the process to drop all resources that could be
        # needed by services started subsequently.  A last resort is to
        # sleep for some time.
        start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
        [ "$?" = 2 ] && return 2
        # Many daemons don't delete their pidfiles when they exit.
        rm -f $PIDFILE
        return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
        #
        # If the daemon can reload its configuration without
        # restarting (for example, when it is sent a SIGHUP),
        # then implement that here.
        #
        start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE --name $NAME
        return 0
}

case "$1" in
  start)
    log_daemon_msg "Starting $DESC " "$NAME"
    do_start
    case "$?" in
                0|1) log_end_msg 0 ;;
                2) log_end_msg 1 ;;
        esac
  ;;
  stop)
        log_daemon_msg "Stopping $DESC" "$NAME"
        do_stop
        case "$?" in
                0|1) log_end_msg 0 ;;
                2) log_end_msg 1 ;;
        esac
        ;;
  status)
       status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
       ;;
  #reload|force-reload)
        #
        # If do_reload() is not implemented then leave this commented out
        # and leave 'force-reload' as an alias for 'restart'.
        #
        #log_daemon_msg "Reloading $DESC" "$NAME"
        #do_reload
        #log_end_msg $?
        #;;
  restart|force-reload)
        #
        # If the "reload" option is implemented then remove the
        # 'force-reload' alias
        #
        log_daemon_msg "Restarting $DESC" "$NAME"
        do_stop
        case "$?" in
          0|1)
                do_start
                case "$?" in
                        0) log_end_msg 0 ;;
                        1) log_end_msg 1 ;; # Old process is still running
                        *) log_end_msg 1 ;; # Failed to start
                esac
                ;;
          *)
                # Failed to stop
                log_end_msg 1
                ;;
        esac
        ;;
  *)
        #echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
        echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
        exit 3
	;;
esac

:
