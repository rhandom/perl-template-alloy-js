# -*- Mode: Perl; -*-

=head1 NAME

00_use.t - Test the use/import/can functionality of Template::Alloy::JS

=cut

use strict;
use warnings;

use Test::More tests => 30;

###----------------------------------------------------------------###
### loading via can, use, and import

use_ok('Template::Alloy');

### autoload via can
ok(! $INC{'Template/Alloy/JS.pm'},     "Parse role isn't loaded yet");
ok(Template::Alloy->can('process_js'), "But it can load anyway");
ok($INC{'Template/Alloy/JS.pm'},       "Now it is loaded");

use_ok('Template::Alloy::JS');

for my $ta (Template::Alloy->new(COMPILE_JS => 1, EVAL_JS => 1), Template::Alloy::JS->new(EVAL_JS => 1), Template::Alloy->new(COMPILE_JS => 1, EVAL_JS => 'raw')) {
    print "# ".ref($ta)."\n";

    my $out  = '';
    my $in   = q{[% JS %] write("Hello from "+get('foo')) [% END %]};
    my $test = 'Hello from javascript';
    $ta->process(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{[% a = 43; JS %] write(get('a')); set('b', 67) [% END %]~[% b %]};
    $test = '43~67';
    $ta->process(\$in, {}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{([% write("Hello from "+get('foo')) %])};
    $test = '(Hello from javascript)';
    $ta->process_js(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

    $out = '';
    $in   = q{ write("Hello from "+get('foo')) };
    $test = 'Hello from javascript';
    $ta->process_jsr(\$in, {foo => 'javascript'}, \$out) || diag($ta->error);
    is($out, $test, "$in ===> $test");

}

print "# compilation\n";
my $ta = Template::Alloy->new(COMPILE_JS => 1);
for my $row (
    ["23" => "23"],
    ["''" => '""'],
    ["2 + 3" => "(2+3)"],
    ["2 + 3 * 4" => "(2+(3*4))"],
    ["'foo' ~ 3" => '(""+"foo"+3)'],
    ["a" => 'alloy.get(["a",0])'],
    ["a()" => 'alloy.get(["a",[]])'],
    ["a(1)" => 'alloy.get(["a",[1]])'],
    ["a(1+2)" => 'alloy.get(["a",[(1+2)]])'],
    ["a(1+2)" => 'alloy.get(["a",[(1+2)]])'],
    ["{foo => 5}" => '{"foo":5}'],
    ['{$foo => 5}' => '(function () { var h = {}; h[alloy.get(["foo",0])] = 5; return h })()'],
    ["a(b)" => 'alloy.get(["a",[function(){return alloy.get(["b",0])}]])'],
    ) {
    my ($from, $to) = @$row;
    my $parse = $ta->parse_expr(\$from);
    is(Template::Alloy::JS::_compile_expr_js($ta, $parse), $to, "$from  ==>  $to");
}
