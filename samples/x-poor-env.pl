#!/usr/bin/perl

=head1 NAME

x-poor-env.pl - copy but with modifications from the Text::Xslate distribution testing only TT languages

=head1 NOTE

For poor environment, e.g. no persistents between requests

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
use Benchmark qw(:all);
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
$n    = 50        if not defined $n;

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
    COMPILE_DIR  => '.tt',
);
my $ttx = Template->new(
    STASH => do { require Template::Stash::XS; Template::Stash::XS->new },
    INCLUDE_PATH => [$path],
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
);
my $ta = Template::Alloy->new(
    INCLUDE_PATH => [$path],
    COMPILE_DIR  => '.ta',
);
my $tp = Template::Alloy->new(
    INCLUDE_PATH => [$path],
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

print "Benchmarks with '$tmpl' (datasize=$n with no pre-compile)\n";
cmpthese timethese -1 => {
    Xslate => sub {
        my $body = Text::Xslate->new(type=>'text',syntax=>'TTerse',module=>[qw(Text::Xslate::Bridge::TT2)],path=>[$path],cache=>0)->render("$tmpl.tt", $vars);
        return;
    },
    TJ => sub {
        local $Template::Alloy::JS::js_context;
        my $body = '';
        Template::Alloy->new(COMPILE_JS=>1,INCLUDE_PATH=>[$path])->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TJS => sub {
        local $Template::Alloy::JS::js_context;
        my $body = '';
        Template::Alloy->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tj')->process_js("$tmpl.jst", $vars, \$body);
        return;
    },
    TP => sub {
        my $body;
        Template::Alloy->new(COMPILE_PERL=>1,INCLUDE_PATH=>[$path])->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TA => sub {
        my $body;
        Template::Alloy->new(INCLUDE_PATH=>[$path])->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TT => sub {
        my $body;
        Template->new(INCLUDE_PATH=>[$path],STASH=>Template::Stash->new)->process("$tmpl.tt", $vars, \$body);
        return;
    },
    TTX => sub {
        my $body;
        Template->new(INCLUDE_PATH=>[$path],STASH=>Template::Stash::XS->new)->process("$tmpl.tt", $vars, \$body);
        return;
    },
};
print "\n";
print "Benchmarks with '$tmpl' (datasize=$n with pre-compile)\n";
cmpthese timethese -1 => {
    Xslate => sub {
        my $body = Text::Xslate->new(type=>'text',syntax=>'TTerse',module=>[qw(Text::Xslate::Bridge::TT2)],path=>[$path],cache=>1,cache_dir=>'.xslate_cache')->render("$tmpl.tt", $vars);
        return;
    },
    TJ => sub {
        local $Template::Alloy::JS::js_context;
        my $body = '';
        Template::Alloy->new(COMPILE_JS=>1,INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tj')->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TJS => sub {
        local $Template::Alloy::JS::js_context;
        my $body = '';
        Template::Alloy->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tj')->process_js("$tmpl.jst", $vars, \$body);
        return;
    },
    TA => sub {
        my $body;
        Template::Alloy->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.ta')->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TP => sub {
        my $body;
        Template::Alloy->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tp',COMPILE_PERL=>2)->process_simple("$tmpl.tt", $vars, \$body);
        return;
    },
    TT => sub {
        my $body;
        Template->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tt',STASH=>Template::Stash->new)->process("$tmpl.tt", $vars, \$body);
        return;
    },
    TTX => sub {
        my $body;
        Template->new(INCLUDE_PATH=>[$path],COMPILE_DIR=>'.tt',STASH=>Template::Stash::XS->new)->process("$tmpl.tt", $vars, \$body);
        return;
    },
};

=head1 OUTPUT

  paul@paul-laptop:~/dev/Template-Alloy-JS$ perl -Ilib -Iblib/lib ./samples/x-poor-env.pl
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
  Benchmarks with 'include' (datasize=50 with no pre-compile)
  Benchmark: running TA, TJ, TP, TT, TTX, Xslate for at least 1 CPU seconds...
          TA:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 189.42/s (n=197)
          TJ:  1 wallclock secs ( 1.02 usr +  0.02 sys =  1.04 CPU) @ 36.54/s (n=38)
          TP:  1 wallclock secs ( 1.05 usr +  0.01 sys =  1.06 CPU) @ 166.04/s (n=176)
          TT:  2 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 139.45/s (n=152)
         TTX:  1 wallclock secs ( 1.06 usr +  0.01 sys =  1.07 CPU) @ 208.41/s (n=223)
      Xslate:  2 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 101.83/s (n=111)
           Rate     TJ Xslate     TT     TP     TA    TTX
  TJ     36.5/s     --   -64%   -74%   -78%   -81%   -82%
  Xslate  102/s   179%     --   -27%   -39%   -46%   -51%
  TT      139/s   282%    37%     --   -16%   -26%   -33%
  TP      166/s   354%    63%    19%     --   -12%   -20%
  TA      189/s   418%    86%    36%    14%     --    -9%
  TTX     208/s   470%   105%    49%    26%    10%     --
  
  Benchmarks with 'include' (datasize=50 with pre-compile)
  Benchmark: running TA, TJ, TP, TT, TTX, Xslate for at least 1 CPU seconds...
          TA:  1 wallclock secs ( 1.08 usr +  0.01 sys =  1.09 CPU) @ 204.59/s (n=223)
          TJ:  1 wallclock secs ( 0.99 usr +  0.03 sys =  1.02 CPU) @ 37.25/s (n=38)
          TP:  1 wallclock secs ( 1.11 usr +  0.00 sys =  1.11 CPU) @ 200.90/s (n=223)
          TT:  2 wallclock secs ( 1.06 usr +  0.02 sys =  1.08 CPU) @ 172.22/s (n=186)
         TTX:  1 wallclock secs ( 1.10 usr +  0.01 sys =  1.11 CPU) @ 301.80/s (n=335)
      Xslate:  1 wallclock secs ( 1.00 usr +  0.02 sys =  1.02 CPU) @ 693.14/s (n=707)
           Rate     TJ     TT     TP     TA    TTX Xslate
  TJ     37.3/s     --   -78%   -81%   -82%   -88%   -95%
  TT      172/s   362%     --   -14%   -16%   -43%   -75%
  TP      201/s   439%    17%     --    -2%   -33%   -71%
  TA      205/s   449%    19%     2%     --   -32%   -70%
  TTX     302/s   710%    75%    50%    48%     --   -56%
  Xslate  693/s  1761%   302%   245%   239%   130%     --

=cut
