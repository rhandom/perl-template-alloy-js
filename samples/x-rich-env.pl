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
perl -Mblib benchmark/x-rich-env.pl [--size N] [--template NAME]

This is a general benchmark utility for rich environment,
assuming persisitent PSGI applications using XS modules.
See also benchmark/x-poor-env.pl.
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
use File::Path qw(rmtree);
END {
    rmtree(".tt");
    rmtree(".xslate_cache");
    rmtree(".tj");
    rmtree(".ta");
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
    my $tests = 4;
    plan tests => $tests;

    my $expected = '';
    $ta->process_simple("$tmpl.tt", $vars, \$expected) or die $ta->error;
    my $size = length($expected);
    my $expected2 = $expected;
    $expected2 =~ s/\n+/\n/g; # this is required because Xslate has not template control of whitespace via chomping

    my $out = $tx->render("$tmpl.tt", $vars);
    my $size2 = length($out);
    $out =~ s/\n+/\n/g;
    is $out, $expected2, 'TX: Text::Xslate'.($size != $size2 ? " - also had ".($size2-$size)." extra newlines" : '');

    $out = '';
    $tj->process_simple("$tmpl.tt", $vars, \$out) or die $tj->error;
    is $out, $expected, 'TJ: Template::Alloy::JS';

    $out = '';
    $tt->process("$tmpl.tt", $vars, \$out) or die $tt->error;
    is $out, $expected, 'TT: Template::Toolkit (no XS)';

    $out = '';
    $ttx->process("$tmpl.tt", $vars, \$out) or die $tt->error;
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
  1..4
  ok 1 - TX: Text::XSlate
  ok 2 - TJ: Template::Alloy::JS
  ok 3 - TT: Template::Toolkit (no XS)
  ok 4 - TTX: Template::Toolkit with XS
  Benchmarks with 'include' (datasize=100)
  Benchmark: running TA, TJ, TT, TTX, Xslate for at least 1 CPU seconds...
          TA:  1 wallclock secs ( 1.02 usr +  0.01 sys =  1.03 CPU) @ 107.77/s (n=111)
          TJ:  1 wallclock secs ( 1.10 usr +  0.01 sys =  1.11 CPU) @ 755.86/s (n=839)
          TT:  1 wallclock secs ( 1.10 usr +  0.02 sys =  1.12 CPU) @ 106.25/s (n=119)
         TTX:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 211.32/s (n=224)
      Xslate:  1 wallclock secs ( 1.05 usr +  0.02 sys =  1.07 CPU) @ 784.11/s (n=839)
          Rate     TT     TA    TTX     TJ Xslate
  TT     106/s     --    -1%   -50%   -86%   -86%
  TA     108/s     1%     --   -49%   -86%   -86%
  TTX    211/s    99%    96%     --   -72%   -73%
  TJ     756/s   611%   601%   258%     --    -4%
  Xslate 784/s   638%   628%   271%     4%     --

=cut
