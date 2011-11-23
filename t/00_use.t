# -*- Mode: Perl; -*-

=head1 NAME

00_use.t - Test the use/import/can functionality of Template::Alloy::JS

=cut

use strict;
use warnings;

use Test::More tests => 13;

###----------------------------------------------------------------###
### loading via can, use, and import

use_ok('Template::Alloy');

### autoload via can
ok(! $INC{'Template/Alloy/JS.pm'},     "Parse role isn't loaded yet");
ok(Template::Alloy->can('process_js'), "But it can load anyway");
ok($INC{'Template/Alloy/JS.pm'},       "Now it is loaded");

use_ok('Template::Alloy::JS');

for my $ta (Template::Alloy->new(COMPILE_JS => 1), Template::Alloy::JS->new) {
    print "# ".ref($ta)."\n";

    my $out  = '';
    my $in   = q{[% JS %] write("Hello from "+vars.foo) [% END %]};
    my $test = 'Hello from javascript';
    $ta->process(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{[% a = 43; JS %] write(vars.a); vars.b = 67 [% END %]~[% b %]};
    $test = '43~67';
    $ta->process(\$in, {}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{([% write("Hello from "+vars.foo) %])};
    $test = '(Hello from javascript)';
    $ta->process_js(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{ write("Hello from "+vars.foo) };
    $test = 'Hello from javascript';
    $ta->process_jsr(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

}
