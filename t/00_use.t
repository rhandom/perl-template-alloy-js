# -*- Mode: Perl; -*-

=head1 NAME

00_use.t - Test the use/import/can functionality of Template::Alloy::JS

=cut

use strict;
use warnings;

use Test::More tests => 34;

###----------------------------------------------------------------###
### loading via can, use, and import

use_ok('Template::Alloy');

### autoload via can
ok(! $INC{'Template/Alloy/JS.pm'},     "Parse role isn't loaded yet");
ok(Template::Alloy->can('process_js'), "But it can load anyway");
ok($INC{'Template/Alloy/JS.pm'},       "Now it is loaded");

use_ok('Template::Alloy::JS');

my $process = sub {
    my $line = (caller)[2];
    my ($obj, $in, $test, $vars, $method) = @_;
    my $out  = '';
    $method ||= 'process';
    $obj->$method(\$in, $vars, \$out);

    my $ok = ref($test) ? $out =~ $test : $out eq $test;
    if ($ok) {
        ok(1, "Line $line   \"$in\" => \"$out\"");
    } else {
        ok(0, "Line $line   \"$in\"");
        warn "# Was:\n$out\n# Should've been:\n$test\n";
        print map {"$_\n"} grep { defined } $obj->error if $obj->can('error');
        if ($method eq 'process') {
            print $obj->dump_parse_tree(\$in) if $obj->can('dump_parse_tree');
        } else {
            my ($k,$v) = each %{ $obj->{'_documents'} };
            use Data::Dumper;
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            print "    ".Data::Dumper::Dumper($v->{'_tree'}),"\n";
        }
        exit;
    }

};

for my $ta (Template::Alloy->new(COMPILE_JS => 1, EVAL_JS => 1), Template::Alloy::JS->new(EVAL_JS => 1)) {
    print "# ".ref($ta)."\n";

    $process->($ta, q{[% JS %] write("Hello from "+get('foo')) [% END %]} => 'Hello from javascript', {foo => 'javascript'});
    $process->($ta, q{[% a = 43; JS %] write(get('a')); set('b', 67) [% END %]~[% b %]} => '43~67', {});
    $process->($ta, q{([% write("Hello from "+get('foo')) %])} => '(Hello from javascript)', {foo => 'javascript'}, 'process_js');
    $process->($ta, q{ write("Hello from "+get('foo')) }, 'Hello from javascript', {foo => 'javascript'}, 'process_jsr');
}

for my $ta (Template::Alloy->new(COMPILE_JS => 1, EVAL_JS => 'raw'), Template::Alloy::JS->new(EVAL_JS => 'raw')) {
    print "# ".ref($ta)."\n";

    $process->($ta, q{[% JS %] write("Hello from "+vars.foo) [% END %]} => 'Hello from javascript', {foo => 'javascript'});
    $process->($ta, q{[% a = 43; JS %] write(vars.a); vars.b = 67 [% END %]~[% b %]} => '43~67', {});
    $process->($ta, q{([% write("Hello from "+vars.foo) %])} => '(Hello from javascript)', {foo => 'javascript'}, 'process_js');
    $process->($ta, q{ write("Hello from "+vars.foo) }, 'Hello from javascript', {foo => 'javascript'}, 'process_jsr');
}
#, Template::Alloy->new(COMPILE_JS => 1, EVAL_JS => 'raw')) {

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
