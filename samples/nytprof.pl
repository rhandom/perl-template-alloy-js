#!/usr/bin/perl -d:NYTProf

use strict;
use warnings;

use Template::Alloy::JS;
use Getopt::Long;
use FindBin qw($Bin);

GetOptions(
    'size=i'     => \my $n,
    'template=s' => \my $tmpl,
    'help'       => \my $help,
    'max=i'      => \my $max,
);

die <<'HELP' if $help;
perl -Mblib $0 [--size N] [--template NAME]

HELP

$tmpl = 'include' if not defined $tmpl;
$n    = 100       if not defined $n;
$max  = 100       if not defined $max;

my $path = "$Bin/template";

use File::Path qw(rmtree);
END {
    rmtree(".tj");
};

my $vars = {
    data => [ ({
            title    => "<FOO>",
            author   => "BAR",
            abstract => "BAZ",
        }) x $n
   ],
};

my $tj;
my $sub = sub {
#    local $Template::Alloy::JS::js_context;
    my $body = '';
    #Template::Alloy::JS->new(
    $tj ||= Template::Alloy::JS->new(
        INCLUDE_PATH => [$path],
        COMPILE_DIR  => '.tj',
    )->process_simple("$tmpl.tt", $vars, \$body);
};
$sub->();

print "Running $tmpl.tt with n=$n for $max iterations\n";
for (1..$max) {
    $sub->();
}
