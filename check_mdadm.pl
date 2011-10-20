#!/usr/bin/perl
# DMA - Dedibox Monitoring Agent
# Script de verification de l'etat du raid soft
# abermingham@corp.free.fr - 07/12/2007
# Code original de Steve Milton

open (MDSTAT, "</proc/mdstat") or die "Failed to open /proc/mdstat";
my $found = 0;
my $status = "";
my $recovery = "";
my $finish = "";
my $active = "";

while(<MDSTAT>) {
    if ($found) {
        if (/(\[[_U]+\])/) {
            $status = $1;
            last;
	} elsif (/recovery = (.*?)\s/) {
            $recovery = $1;
            ($finish) = /finish=(.*?min)/;
	    last;
        }
    } else {
        if (/^$ARGV[0]\s*:/) {
            $found = 1;
            if (/active/) {
                $active = 1;
            }
        }
    }
}

my $msg = "FAILURE";
my $code = "UNKNOWN";
if ($status =~ /_/) {
    if ($recovery) {
        $msg = sprintf "%s status=%s, recovery=%s, finish=%s\n",
        $ARGV[0], $status, $recovery, $finish;
        $code = "WARNING";
    } else {
        $msg = sprintf "%s status=%s\n", $ARGV[0], $status;
        $code = "WARNING";
    }
} elsif ($status =~ /U+/) {
    $msg = sprintf "%s status=%s\n", $ARGV[0], $status;
    $code = "OK";
} else {
    if ($active) {
        $msg = sprintf "%s active with no status information.\n",
        $ARGV[0];
        $code = "OK";
    } else {
        $msg = sprintf "%s does not exist.\n", $ARGV[0];
        $code = "WARNING";
    }
}

print $code."\n".$msg;
exit ($ERRORS{$code});
