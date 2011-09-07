#!/usr/bin/perl -w
# 
# check_ddos
# Check DDOS attack plugin for Nagios
#
# Nicolas Hennion (aka Nicolargo)
#
# History:
# - 0.4: correct sort (thx to Zorgh)
# - 0.3: add the -t option to netstat
#
#==================================================
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor Boston, MA 02110-1301,  USA
#
# http://www.gnu.org/licenses/gpl.txt
#
#==================================================
my $program_name = "check_ddos.pl";
my $program_version = "0.4";
my $program_date = "02/2011";

# Libraries
#----------

use strict;
use lib "/usr/local/nagios/libexec";
use Getopt::Std;

# Globals variables
#------------------

my $netstat = '/bin/netstat -ant';
my %ERRORS = ('UNKNOWN' , '3',
              'OK' , '0',
              'WARNING', '1',
              'CRITICAL', '2' );
my $state = "UNKNOWN";
my $answer = "";
my $warning;
my $critical;

# Programs argument management
#-----------------------------

my %opts = ();
getopts("hvw:c:", \%opts);
if ($opts{v}) {
    # Display the version
    print "$program_name $program_version ($program_date)\n";
    exit(-1);
}
if ($opts{h} || (!$opts{w} || !$opts{c})) {
    # Help
    print "$program_name $program_version\n";
    print "usage: ", $program_name," [options]\n";
    print " -h: Print the command line help\n";
    print " -v: Print the program version\n";
    print " -w <int>: Warning value (number of SYN_RECV)\n";
    print " -c <int>: Critical value (number of SYN_RECV)\n";
    exit (-1);
}

# Get the warning value
if ($opts{w}) {
    $warning = $opts{w};
}

# Get the warning value
if ($opts{c}) {
    $critical = $opts{c};
}

# Main program
#-------------

system("$netstat > /tmp/check_ddos.res") == 0
	or die "$state: $netstat failed ($?)";

my $ddos = `grep SYN_RECV /tmp/check_ddos.res | wc -l`;
chomp $ddos;
# my $output = `grep SYN_RECV /tmp/check_ddos.res | awk {'print \$5'} | cut -f 1 -d ":" | sort | uniq -c | sort -rn | head -10`;
my $output = `grep SYN_RECV /tmp/check_ddos.res | awk {'print \$5'} | cut -f 1 -d ":" | sort | uniq -c | sort -k1,1rn | head -10`;

if ($ddos >= $warning) {
	if ($ddos >= $critical) {
		$state = "CRITICAL";
	} else {
		$state = "WARNING";
	}
	print "DDOS attack.\nTop 10 SYN_RECV sources:\n$output";
} else {
	$state = "OK";
	print "No DDOS attack detected ($ddos/$warning).\n";
}

system("rm -f /tmp/check_ddos.res") == 0
	or die "$state: Can not delete /tmp/check_ddos.res ($?)";

exit $ERRORS{$state};

# The end...
