# -*- Mode: Perl; -*-

=head1 NAME

00_use.t - Test the use/import/can functionality of Template::Alloy::JS

=cut

use strict;
use warnings;

use Test::More tests => 6;

###----------------------------------------------------------------###
### loading via can, use, and import

use_ok('Template::Alloy');

### autoload via can
ok(! $INC{'Template/Alloy/JS.pm'},     "Parse role isn't loaded yet");
ok(Template::Alloy->can('process_js'), "But it can load anyway");
ok($INC{'Template/Alloy/JS.pm'},       "Now it is loaded");

use_ok('Template::Alloy::JS');

my $ta = Template::Alloy::JS->new;
my $out = '';
$ta->process(\q{[% JS %] write("Hello from "+vars.foo) [% END %]}, {foo => 'javascript'}, \$out);
is($out, 'Hello from javascript', 'Can get expected output from javascript');

# same as

#use Template::Alloy;
#my $ta = Template::Alloy->new(COMPILE_JS => 1);


