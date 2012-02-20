#!/usr/bin/perl

=head1 NAME

x-rich-env.pl - copy but with modifications from the Text::Xslate distribution testing only TT languages

=head1 NOTE

For rich environment, e.g. Persistent PSGI applications with XS

This module has modifications which test Template::Alloy::JS, Template::Alloy,
Template with XS stash, and Template without XS stash.

For parity the include.tt template includes calls to vmethods as well
as other operations that would more typically be in a template.

=cut

use strict;
use warnings;

use Template;
use Template::Stash;
use Template::Alloy;
use Template::Alloy::JS;
use Text::Xslate;
use Text::Xslate::Bridge::TT2;

use Getopt::Long;

use Test::More;
use Benchmark qw(cmpthese timethese);
use FindBin qw($Bin);
use Storable ();
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

GetOptions(
    'size=i'     => \my $n,
    'template=s' => \my $tmpl,
    'help'       => \my $help,
);

die <<'HELP' if $help;
perl -Mblib x-rich-env.pl [--size N] [--template NAME]

This is a general benchmark utility for rich environment,
assuming persisitent PSGI applications using XS modules.
See also x-poor-env.pl.
HELP

$tmpl = 'include' if not defined $tmpl;
$n    = 100       if not defined $n;

foreach my $mod(qw(
    Text::Xslate
    Template
    Template::Alloy
    Template::Alloy::JS
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $path = "$Bin/template";

my $tt = Template->new(
    STASH => do { require Template::Stash; Template::Stash->new },
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.outa',
    COMPILE_DIR  => '.tt',
);
my $ttx = Template->new(
    STASH => do { require Template::Stash::XS; Template::Stash::XS->new },
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.outa',
    COMPILE_DIR  => '.tt',
);
my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  '.xslate_cache',
    type       => 'text',
    syntax     => 'TTerse',
    module     => [qw(Text::Xslate::Bridge::TT2)],
);
my $tj = Template::Alloy->new(
    COMPILE_JS   => 1,
    INCLUDE_PATH => [$path],
    COMPILE_DIR  => '.tj',
    COMPILE_EXT  => '.outj',
);
my $ta = Template::Alloy->new(
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.outa',
    COMPILE_DIR  => '.ta',
);
my $tp = Template::Alloy->new(
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.outp',
    COMPILE_DIR  => '.tp',
    COMPILE_PERL => 2,
);
use File::Path qw(rmtree);
END {
    rmtree(".tt");
    rmtree(".xslate_cache");
    rmtree(".tj");
    rmtree(".ta");
    rmtree(".tp");
};

my $vars = {
    data => [ ({
            title    => "<FOO>",
            author   => "BAR",
            abstract => "BAZ",
        }) x $n
   ],
};

{
    my $tests = 5;
    plan tests => $tests;

    my $expected = '';
    $ta->process_simple("$tmpl.tt", $vars, \$expected) or die $ta->error;
    my $size = length($expected);
    my $expected2 = $expected;
    $expected2 =~ s/\n+/\n/g; # this is required because Xslate may not control of whitespace via chomping (i think it was added in more recent versions)

    my $out = $tx->render("$tmpl.tt", $vars);
    my $size2 = length($out);
    $out =~ s/\n+/\n/g;
    is $out, $expected2, 'TX: Text::Xslate'.($size != $size2 ? " - also had ".($size2-$size)." extra newlines" : '');

    $out = '';
    $tj->process_simple("$tmpl.tt", $vars, \$out) or die $tj->error;
    is $out, $expected, 'TJ: Template::Alloy::JS';

    $out = '';
    $tp->process_simple("$tmpl.tt", $vars, \$out) or die $tp->error;
    is $out, $expected, 'TP: Template::Alloy (compile to perl)';

    $out = '';
    $tt->process("$tmpl.tt", $vars, \$out) or die $tt->error;
    is $out, $expected, 'TT: Template::Toolkit (no XS)';

    $out = '';
    $ttx->process("$tmpl.tt", $vars, \$out) or die $ttx->error;
    is $out, $expected, 'TTX: Template::Toolkit with XS';
}

print "Benchmarks with '$tmpl' (datasize=$n)\n";
cmpthese timethese -1 => {
    Xslate => sub {
        my $body = $tx->render("$tmpl.tt", {%$vars}) or die;;
        return;
    },
    TJ => sub {
        my $body = '';
        $tj->process_simple("$tmpl.tt", {%$vars}, \$body) or die $tj->error;
        return;
    },
    TP => sub {
        my $body = '';
        $tp->process_simple("$tmpl.tt", {%$vars}, \$body) or die $tp->error;
        return;
    },
    TA => sub {
        my $body;
        $ta->process_simple("$tmpl.tt", {%$vars}, \$body) or die $ta->error;
        return;
    },
    TT => sub {
        my $body;
        $tt->process("$tmpl.tt", $vars, \$body) or die $tt->error;
        return;
    },
    TTX => sub {
        my $body;
        $ttx->process("$tmpl.tt", $vars, \$body) or die $ttx->error;
        return;
    },
};

=head1 OUTPUT (2012/02/10)

  paul@paul-laptop:~/dev/Template-Alloy-JS$ perl -Ilib -Iblib/lib ./samples/x-rich-env.pl
  Perl/5.12.4 i686-linux-gnu-thread-multi-64int
  Text::Xslate/1.5007
  Template/2.24
  Template::Alloy/1.016
  Template::Alloy::JS/1.000
  1..5
  ok 1 - TX: Text::Xslate
  ok 2 - TJ: Template::Alloy::JS
  ok 3 - TP: Template::Alloy (compile to perl)
  ok 4 - TT: Template::Toolkit (no XS)
  ok 5 - TTX: Template::Toolkit with XS
  Benchmarks with 'include' (datasize=100)
  Benchmark: running TA, TJ, TP, TT, TTX, Xslate for at least 1 CPU seconds...
          TA:  1 wallclock secs ( 1.03 usr +  0.00 sys =  1.03 CPU) @ 107.77/s (n=111)
          TJ:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 813.64/s (n=895)
          TP:  2 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 108.18/s (n=119)
          TT:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 106.73/s (n=111)
         TTX:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 215.38/s (n=224)
      Xslate:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 791.51/s (n=839)
          Rate     TT     TA     TP    TTX Xslate     TJ
  TT     107/s     --    -1%    -1%   -50%   -87%   -87%
  TA     108/s     1%     --    -0%   -50%   -86%   -87%
  TP     108/s     1%     0%     --   -50%   -86%   -87%
  TTX    215/s   102%   100%    99%     --   -73%   -74%
  Xslate 792/s   642%   634%   632%   267%     --    -3%
  TJ     814/s   662%   655%   652%   278%     3%     --

=cut
