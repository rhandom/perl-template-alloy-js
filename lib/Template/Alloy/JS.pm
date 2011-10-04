package Template::Alloy::JS;

=head1 NAME

Template::Alloy::JS - Compile JS role - allows for compiling the AST to javascript and running on the js engine

=cut

use strict;
use warnings;
use Template::Alloy;
use Template::Alloy::Iterator;

eval { require JSON } || die "Cannot load JSON library used by Template::Alloy::JS: $@";
my $json = eval { JSON->new->allow_nonref } || eval { JSON->new };
die "The loaded JSON library does not support the encode method needed by Template::Alloy::JS\n" if ! $json || !$json->can('encode');

our $VERSION = $Template::Alloy::VERSION;
our $INDENT  = ' ' x 2;
our $DIRECTIVES = {
    BLOCK   => \&compile_js_BLOCK,
    BREAK   => \&compile_js_LAST,
    CALL    => \&compile_js_CALL,
    CASE    => undef,
    CATCH   => undef,
    CLEAR   => \&compile_js_CLEAR,
    '#'     => sub {},
    COMMENT => sub {},
    CONFIG  => \&compile_js_CONFIG,
    DEBUG   => \&compile_js_DEBUG,
    DEFAULT => \&compile_js_DEFAULT,
    DUMP    => \&compile_js_DUMP,
    ELSE    => undef,
    ELSIF   => undef,
    END     => sub {},
    EVAL    => \&compile_js_EVAL,
    FILTER  => \&compile_js_FILTER,
    '|'     => \&compile_js_FILTER,
    FINAL   => undef,
    FOR     => \&compile_js_FOR,
    FOREACH => \&compile_js_FOR,
    GET     => \&compile_js_GET,
    IF      => \&compile_js_IF,
    INCLUDE => \&compile_js_INCLUDE,
    INSERT  => \&compile_js_INSERT,
    LAST    => \&compile_js_LAST,
    LOOP    => \&compile_js_LOOP,
    MACRO   => \&compile_js_MACRO,
    META    => \&compile_js_META,
    NEXT    => \&compile_js_NEXT,
    PERL    => \&compile_js_PERL,
    PROCESS => \&compile_js_PROCESS,
    RAWPERL => \&compile_js_RAWPERL,
    RETURN  => \&compile_js_RETURN,
    SET     => \&compile_js_SET,
    STOP    => \&compile_js_STOP,
    SWITCH  => \&compile_js_SWITCH,
    TAGS    => sub {},
    THROW   => \&compile_js_THROW,
    TRY     => \&compile_js_TRY,
    UNLESS  => \&compile_js_UNLESS,
    USE     => \&compile_js_USE,
    VIEW    => \&compile_js_VIEW,
    WHILE   => \&compile_js_WHILE,
    WRAPPER => \&compile_js_WRAPPER,
};

sub new { die "This class is a role for use by packages such as Template::Alloy" }

our $js_context;
sub load_js {
    my ($self, $doc) = @_;

    ### first look for a compiled perl document
    my $js;
    if ($doc->{'_filename'}) {
        $doc->{'modtime'} ||= (stat $doc->{'_filename'})[9];
        if ($self->{'COMPILE_DIR'} || $self->{'COMPILE_EXT'}) {
            my $file = $doc->{'_filename'};
            if ($self->{'COMPILE_DIR'}) {
                $file =~ y|:|/| if $^O eq 'MSWin32';
                $file = $self->{'COMPILE_DIR'} .'/'. $file;
            } elsif ($doc->{'_is_str_ref'}) {
                $file = ($self->include_paths->[0] || '.') .'/'. $file;
            }
            $file .= $self->{'COMPILE_EXT'} if defined($self->{'COMPILE_EXT'});
            $file .= $Template::Alloy::JS_COMPILE_EXT if defined $JS::Alloy::JS_COMPILE_EXT;

            if (-e $file && ($doc->{'_is_str_ref'} || (stat $file)[9] == $doc->{'modtime'})) {
                $js = $self->slurp($file);
            } else {
                $doc->{'_compile_filename'} = $file;
            }
        }
    }

    $js ||= $self->compile_template_js($doc);

    ### save a cache on the fileside as asked
    if ($doc->{'_compile_filename'}) {
        my $dir = $doc->{'_compile_filename'};
        $dir =~ s|/[^/]+$||;
        if (! -d $dir) {
            require File::Path;
            File::Path::mkpath($dir);
        }
        open(my $fh, ">", $doc->{'_compile_filename'}) || $self->throw('compile_js', "Could not open file \"$doc->{'_compile_filename'}\" for writing: $!");
        ### todo - think about locking
        if ($self->{'ENCODING'} && eval { require Encode } && defined &Encode::encode) {
            print {$fh} Encode::encode($self->{'ENCODING'}, $$js);
        } else {
            print {$fh} $$js;
        }
        close $fh;
        utime $doc->{'modtime'}, $doc->{'modtime'}, $doc->{'_compile_filename'};
    }

    if ($ENV{'DUMPJS'}) {
        print "---------------------------------------------\n";
        print $$js,"\n";
        print "---------------------------------------------\n";
    }

    # initialize the context
    my $ctx = $self->{'js_context'};
    if (!$ctx) {
        eval {require JavaScript::V8} || $self->throw('compile_js', "Trouble loading JavaScript::V8: $@");
        eval {require Scalar::Util}   || $self->throw('compile_js', "Trouble loading Scalar::Util: $@");
        $ctx = $self->{'js_context'} = JavaScript::V8::Context->new;

        my $copy = shift;
        $ctx->bind('$_call_native' => sub { my $m = shift; print "-------------callnative: $m\n"; my $val; eval { $val = $copy->$m(@_); 1 } || $ctx->eval('throw'); $val });
        $ctx->bind(say => sub { print $_[0],"\n" });
        $ctx->bind(debug => sub { require CGI::Ex::Dump; CGI::Ex::Dump::debug(@_) });
        Scalar::Util::weaken($copy);

        #(my $file2 = __FILE__) =~ s|JS\.pm$|stack.js|;
        #$ctx->eval(${ $self->slurp($file2) }) || $self->throw('compile_js', "Trouble loading javascript stacktrace: $@");

        (my $file = __FILE__) =~ s|JS\.pm$|vmethods.js|;
        $ctx->eval(${ $self->slurp($file) }) || $self->throw('compile_js', "Trouble loading javascript vmethods: $@");

        ($file = __FILE__) =~ s|JS\.pm$|alloy.js|;
        $ctx->eval(${ $self->slurp($file) }) || $self->throw('compile_js', "Trouble loading javascript pre-amble: $@");
    }

    my $callback = $ctx->eval(qq{
        alloy.register_template('$doc->{_filename}',$$js);
        (function (out_ref) { return alloy.process('$doc->{_filename}', out_ref) })
    }) || $self->throw('compile_js', "Trouble loading compiled js for $doc->{_filename}: $@");

    return {code => sub {
        my ($self, $out_ref) = @_;
        $ctx->bind('$_vars' => $self->{'_vars'});
        $ctx->bind('$_env'  => {
            QR_PRIVATE => "^[_.]", #$Template::Alloy::QR_PRIVATE"});
            VMETHOD_FUNCTIONS => $self->{'VMETHOD_FUNCTIONS'},
            LOWER_CASE_VAR_FALLBACK => $self->{'LOWER_CASE_VAR_FALLBACK'},
            NO_INCLUDES => $self->{'NO_INCLUDES'},
            TRIM => $self->{'TRIM'},
            UNDEFINED_GET => $self->{'UNDEFINED_GET'} ? 1 : 0,
        });
        my $out = $callback->([$$out_ref]);
        $$out_ref = $out->[0];
        return 1;
    }};
}

###----------------------------------------------------------------###

sub compile_template_js {
    my ($self, $doc) = @_;

    local $self->{'_component'} = $doc;
    my $tree = $doc->{'_tree'} ||= $self->load_tree($doc);

    local $self->{'_blocks'} = '';
    local $self->{'_meta'}   = '';

    my $code = $self->compile_tree_js($tree, $INDENT);
    $self->{'_blocks'} .= "\n" if $self->{'_blocks'};
    $self->{'_meta'}   .= "\n" if $self->{'_meta'};

    my $str = "(function () {
// Generated by ".__PACKAGE__." v$VERSION on ".localtime()."
// From file ".($doc->{'_filename'} || $doc->{'name'})."

var blocks = {$self->{'_blocks'}};
var meta   = {$self->{'_meta'}};
var code   = function (alloy, out_ref, args) {"
.($self->{'_blocks'} ? "\n${INDENT}alloy.setBlocks(blocks);" : "")
.($self->{'_meta'}   ? "\n${INDENT}alloy.setMeta(meta);" : "")
."$code

${INDENT}return out_ref;
};

return {
${INDENT}'blocks' : blocks,
${INDENT}'meta'   : meta,
${INDENT}'code'   : code
};
})()";
#    print $str;
    return \$str;
}

###----------------------------------------------------------------###

sub _node_info {
    my ($self, $node, $indent) = @_;
    my $doc = $self->{'_component'} || return '';
    $doc->{'_content'} ||= $self->slurp($doc->{'_filename'});
    my ($line, $char) = $self->get_line_number_by_index($doc, $node->[1], 'include_chars');
    return "\n\n${indent}// \"$node->[0]\" Line $line char $char (chars $node->[1] to $node->[2])";
}

sub compile_tree_js {
    my ($self, $tree, $indent) = @_;
    my $code = '';
    # node contains (0: DIRECTIVE,
    #                1: start_index,
    #                2: end_index,
    #                3: parsed tag details,
    #                4: sub tree for block types
    #                5: continuation sub trees for sub continuation block types (elsif, else, etc)
    #                6: flag to capture next directive
    my @doc;
    my $func;
    for my $node (@$tree) {

        # text nodes are just the bare text
        if (! ref $node) {
            $node =~ s/([\'\\])/\\$1/g;
            $code .= "\n\n${indent}out_ref[0] += ".$json->encode($node).";";
            next;
        }

        if ($self->{'_debug_dirs'} && ! $self->{'_debug_off'}) {
            my $info = $self->node_info($node);
            my ($file, $line, $text) = @{ $info }{qw(file line text)};
            s/\'/\\\'/g foreach $file, $line, $text;
            $code .= "\n
${indent}if (alloy._debug_dirs && ! alloy._debug_off) { // DEBUG
${indent}${INDENT}var info = {'file': '$file', 'line': '$line', 'text': '$text'};
${indent}${INDENT}var format = alloy._debug_format || alloy.DEBUG_FORMAT || \"\\n/* \\\$file line \\\$line : [% \\\$text %] */\\n\";
${indent}${INDENT}out_ref[0] += (''+format).replace(/\\\$(file|line|text)/, function (m, one) { info[one] }, 1);
${indent}}";
        }

        $code .= _node_info($self, $node, $indent);

        if ($func = $DIRECTIVES->{$node->[0]}) {
            $func->($self, $node, \$code, $indent);
        } else {
            ### if the method isn't defined - delegate to the play directive (if there is one)
            require Template::Alloy::Play;
            if ($func = $Template::Alloy::Play::DIRECTIVES->{$node->[0]}) {
                _compile_defer_to_play($self, $node, \$code, $indent);
            } else {
                die "Couldn't find compile or play method for directive \"$node->[0]\"";
            }
        }
    }
    return $code;
}

sub compile_expr_js {
    my ($self, $var, $indent) = @_;
    return ref($var) ? "alloy.play_expr(".$json->encode($var).")" : $json->encode($var);
}

sub _compile_defer_to_play {
    my ($self, $node, $str_ref, $indent) = @_;
    my $directive = $node->[0];
    die "Invalid node name \"$directive\"" if $directive !~ /^\w+$/;

    $$str_ref .= "
${indent}ref = ".$json->encode($node->[3]).";
${indent}alloy.call_directive('$directive', ref, ".$json->encode($node).", out_ref);";

    return;
}

sub _is_empty_named_args {
    my ($hash_ident) = @_;
    # [[undef, '{}', 'key1', 'val1', 'key2, 'val2'], 0]
    return @{ $hash_ident->[0] } <= 2;
}

###----------------------------------------------------------------###

sub compile_js_BLOCK {
    my ($self, $node, $str_ref, $indent) = @_;

    my $ref  = \ $self->{'_blocks'};
    my $name = $node->[3];
    $name =~ s/\'/\\\'/g;
    my $name2 = $self->{'_component'}->{'name'} .'/'. $node->[3];
    $name2 =~ s/\'/\\\'/g;

    my $code = $self->compile_tree_js($node->[4], "$INDENT$INDENT$INDENT");

    $$ref .= "
${INDENT}'$name': {
${INDENT}${INDENT}name: '$name2',
${INDENT}${INDENT}_js: {code: function (alloy, out_ref, args) {
${INDENT}${INDENT}${INDENT}$code

${INDENT}${INDENT}${INDENT}return 1;
${INDENT}${INDENT}}}
${INDENT}},";

    return;
}

sub compile_js_CALL {
    my ($self, $node, $str_ref, $indent) = @_;
    $$str_ref .= "\n${indent}".$self->compile_expr_js($node->[3], $indent).";";
    return;
}

sub compile_js_CLEAR {
    my ($self, $node, $str_ref, $indent) = @_;
    $$str_ref .= "
${indent}out_ref[0] = '';";
}

sub compile_js_CONFIG {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_DEBUG {
    my ($self, $node, $str_ref, $indent) = @_;

    my $text = $node->[3]->[0];

    if ($text eq 'on') {
        $$str_ref .= "\n${indent}delete \$self->{'_debug_off'};";
    } elsif ($text eq 'off') {
        $$str_ref .= "\n${indent}\$self->{'_debug_off'} = 1;";
    } elsif ($text eq 'format') {
        my $format = $node->[3]->[1];
        $format =~ s/\'/\\\'/g;
        $$str_ref .= "\n${indent}\$self->{'_debug_format'} = '$format';";
    }
    return;
}

sub compile_js_DEFAULT {
    my ($self, $node, $str_ref, $indent) = @_;
    local $self->{'_is_default'} = 1;
    $DIRECTIVES->{'SET'}->($self, $node, $str_ref, $indent);
}

sub compile_js_DUMP {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_GET {
    my ($self, $node, $str_ref, $indent) = @_;
    $$str_ref .= "
${indent}ref = ".$self->compile_expr_js($node->[3], $indent).";
${indent}out_ref[0] += (ref != null) ? ref : alloy.undefined_get(".$json->encode($node->[3]).");";
    return;
}

sub compile_js_EVAL {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($named, @strs) = @{ $node->[3] };

    $$str_ref .= "
${indent}foreach (".join(",\n", map {$json->encode($_)} @strs).") {
${indent}${INDENT}my \$str = \$self->play_expr(\$_);
${indent}${INDENT}next if ! defined \$str;
${indent}${INDENT}\$\$out_ref .= \$self->play_expr([[undef, '-temp-', \$str], 0, '|', 'eval', [".$json->encode($named)."]]);
${indent}}";
}

sub compile_js_FILTER {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($name, $filter) = @{ $node->[3] };
    return if ! @$filter;

    $$str_ref .= "
${indent}ref = (function () {
${indent}${INDENT}var filter = ".$json->encode($filter).";";

    ### allow for alias
    if (length $name) {
        $name =~ s/\'/\\\'/g;
        $$str_ref .= "\n${indent}${INDENT}if (!\$_env.FILTERS) \$_env.FILTERS = {};\n";
        $$str_ref .= "\n${indent}${INDENT}\$_env.FILTERS['$name'] = filter; // alias for future calls\n";
    }

    $$str_ref .= "
${indent}${INDENT}var out_ref = [''];"
.$self->compile_tree_js($node->[4], "$indent$INDENT")."

${indent}${INDENT}var expr = [[null, '-temp-', out_ref[0]], 0, '|'];
${indent}${INDENT}for (var i = 0; i < filter.length; i++) expr.push(filter[i]);
${indent}${INDENT}return alloy.play_expr(expr);
${indent}})();
${indent}if (ref != null) out_ref[0] += ref;";

}

sub compile_js_FOR {
    my ($self, $node, $str_ref, $indent) = @_;

    my ($name, $items) = @{ $node->[3] };
    local $self->{'_in_loop'} = 'FOREACH';
    local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
    my $i = $self->{'_loop_index'};
    my $code = $self->compile_tree_js($node->[4], "$indent$INDENT");

    $$str_ref .= "
${indent}var old_loop${i} = \$_vars.loop;
${indent}var err;
${indent}try {
${indent}var loop${i} = ".$self->compile_expr_js($items, $indent).";
${indent}if (loop${i} == null) loop${i} = [];
${indent}if (!loop${i}.get_first) loop${i} = new alloy.iterator(loop${i});
${indent}\$_vars.loop = loop${i};";
    if (! defined $name) {
        $$str_ref .= "
${indent}alloy.saveScope();";
    }

    $$str_ref .= "
${indent}ref = loop${i}.get_first();
${indent}var val = ref[0];
${indent}var error = ref[1];
${indent}while (!error) {";

    if (defined $name) {
        $$str_ref .= "
$indent${INDENT}alloy.set_variable(".$json->encode($name).", val);";
    } else {
        $$str_ref .= "
$indent${INDENT}if (val && typeof val == 'object' && !(val instanceof Array || val instanceof RegExp)) for (var k in val) alloy.set_variable(k, val[k]);";
    }

    $$str_ref .= "$code
${indent}${INDENT}ref = loop${i}.get_next();
${indent}${INDENT}val   = ref[0];
${indent}${INDENT}error = ref[1];
${indent}${INDENT}}
${indent}} catch (e) { err = e }";
    if (!defined $name) {
        $$str_ref .= "
${indent}alloy.restoreScope();";
    }
    $$str_ref .= "
${indent}\$_vars.loop = old_loop${i};
${indent}if (err != null) throw 'Got some sort of error '+err;";
    return;
}

sub compile_js_FOREACH { shift->compile_FOR(@_) }

sub compile_js_IF {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "\n${indent}if (".$self->compile_expr_js($node->[3], $indent).") {";
    $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");

    while ($node = $node->[5]) { # ELSE, ELSIF's
        $$str_ref .= _node_info($self, $node, $indent);
        if ($node->[0] eq 'ELSE') {
            $$str_ref .= "\n${indent}} else {";
            $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");
            last;
        } else {
            $$str_ref .= "\n${indent}} else if (".$self->compile_expr_js($node->[3], $indent).") {";
            $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");
        }
    }
    $$str_ref .= "\n${indent}}";
}

sub compile_js_INCLUDE {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_INSERT {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_LAST {
    my ($self, $node, $str_ref, $indent) = @_;
    my $type = $self->{'_in_loop'} || die "Found LAST while not in FOR, FOREACH or WHILE";
    $$str_ref .= "\n${indent}break;"; #last $type;";
    return;
}

sub compile_js_LOOP {
    my ($self, $node, $str_ref, $indent) = @_;
    my $ref = $node->[3];
    $ref = [$ref, 0] if ! ref $ref;

    $$str_ref .= "
${indent}\$var = ".$self->compile_expr($ref, $indent).";
${indent}if (\$var) {
${indent}${INDENT}my \$global = ! \$self->{'SYNTAX'} || \$self->{'SYNTAX'} ne 'ht' || \$self->{'GLOBAL_VARS'};
${indent}${INDENT}my \$items  = ref(\$var) eq 'ARRAY' ? \$var : ref(\$var) eq 'HASH' ? [\$var] : [];
${indent}${INDENT}my \$i = 0;
${indent}${INDENT}for my \$ref (\@\$items) {
${indent}${INDENT}${INDENT}\$self->throw('loop', 'Scalar value used in LOOP') if \$ref && ref(\$ref) ne 'HASH';
${indent}${INDENT}${INDENT}local \$self->{'_vars'} = (! \$global) ? (\$ref || {}) : (ref(\$ref) eq 'HASH') ? {%{ \$self->{'_vars'} }, %\$ref} : \$self->{'_vars'};
${indent}${INDENT}${INDENT}\@{ \$self->{'_vars'} }{qw(__counter__ __first__ __last__ __inner__ __odd__)}
${indent}${INDENT}${INDENT}${INDENT}= (++\$i, (\$i == 1 ? 1 : 0), (\$i == \@\$items ? 1 : 0), (\$i == 1 || \$i == \@\$items ? 0 : 1), (\$i % 2) ? 1 : 0)
${indent}${INDENT}${INDENT}${INDENT}${INDENT}if \$self->{'LOOP_CONTEXT_VARS'} && ! \$Template::Alloy::QR_PRIVATE;"
.$self->compile_tree($node->[4], "$indent$INDENT$INDENT")."

${indent}${INDENT}}
${indent}}";
}

sub compile_js_MACRO {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($name, $args) = @{ $node->[3] };

    ### get the sub tree
    my $sub_tree = $node->[4];
    if (! $sub_tree || ! $sub_tree->[0]) {
        $$str_ref .= "
${indent}\$self->set_variable(".$json->encode($name).", undef);";
        return;
    } elsif (ref($sub_tree->[0]) && $sub_tree->[0]->[0] eq 'BLOCK') {
        $sub_tree = $sub_tree->[0]->[4];
    }

    my $code = $self->compile_tree($sub_tree, "$indent$INDENT");

    $$str_ref .= "
${indent}do {
${indent}my \$self_copy = \$self;
${indent}eval {require Scalar::Util; Scalar::Util::weaken(\$self_copy)};
${indent}\$var = sub {
${indent}${INDENT}my \$copy = \$self_copy->{'_vars'};
${indent}${INDENT}local \$self_copy->{'_vars'}= {%\$copy};

${indent}${INDENT}local \$self_copy->{'_macro_recurse'} = \$self_copy->{'_macro_recurse'} || 0;
${indent}${INDENT}my \$max = \$self_copy->{'MAX_MACRO_RECURSE'} || \$Template::Alloy::MAX_MACRO_RECURSE;
${indent}${INDENT}\$self_copy->throw('macro_recurse', \"MAX_MACRO_RECURSE \$max reached\")
${indent}${INDENT}${INDENT}if ++\$self_copy->{'_macro_recurse'} > \$max;
";

    foreach my $var (@$args) {
        $$str_ref .= "
${indent}${INDENT}\$self_copy->set_variable(";
        $$str_ref .= $json->encode($var);
        $$str_ref .= ", shift(\@_));";
    }
    $$str_ref .= "
${indent}${INDENT}if (\@_ && \$_[-1] && UNIVERSAL::isa(\$_[-1],'HASH')) {
${indent}${INDENT}${INDENT}my \$named = pop \@_;
${indent}${INDENT}${INDENT}foreach my \$name (sort keys %\$named) {
${indent}${INDENT}${INDENT}${INDENT}\$self_copy->set_variable([\$name, 0], \$named->{\$name});
${indent}${INDENT}${INDENT}}
${indent}${INDENT}}

${indent}${INDENT}my \$out = '';
${indent}${INDENT}my \$out_ref = \\\$out;$code
${indent}${INDENT}return \$out;
${indent}};
${indent}\$self->set_variable(".$json->encode($name).", \$var);
${indent}};";

    return;
}

sub compile_js_META {
    my ($self, $node, $str_ref, $indent) = @_;
    if ($node->[3]) {
        while (my($key, $val) = each %{ $node->[3] }) {
            s/\'/\\\'/g foreach $key, $val;
            $self->{'_meta'} .= "\n${indent}'$key' => '$val',";
        }
    }
    return;
}

sub compile_js_NEXT {
    my ($self, $node, $str_ref, $indent) = @_;
    my $type = $self->{'_in_loop'} || die "Found next while not in FOR, FOREACH or WHILE";
    my $i = $self->{'_loop_index'} || die "Missing loop_index";
    $$str_ref .= "\n${indent}ref = loop${i}.get_next(); val = ref[0]; error = ref[1];" if $type eq 'FOREACH';
    $$str_ref .= "\n${indent}continue;"; #next $type;";
    return;
}

sub compile_js_PERL{
    my ($self, $node, $str_ref, $indent) = @_;

    ### fill in any variables
    my $perl = $node->[4] || return;
    my $code = $self->compile_tree($perl, "$indent$INDENT");

    $$str_ref .= "
${indent}\$self->throw('perl', 'EVAL_PERL not set') if ! \$self->{'EVAL_PERL'};
${indent}require Template::Alloy::Play;
${indent}\$var = do {
${indent}${INDENT}my \$out = '';
${indent}${INDENT}my \$out_ref = \\\$out;$code
${indent}${INDENT}\$out;
${indent}};
${indent}#\$var = \$1 if \$var =~ /^(.+)\$/s; # blatant untaint

${indent}my \$err;
${indent}eval {
${indent}${INDENT}package Template::Alloy::Perl;
${indent}${INDENT}my \$context = \$self->context;
${indent}${INDENT}my \$stash   = \$context->stash;
${indent}${INDENT}local *PERLOUT;
${indent}${INDENT}tie *PERLOUT, 'Template::Alloy::EvalPerlHandle', \$out_ref;
${indent}${INDENT}my \$old_fh = select PERLOUT;
${indent}${INDENT}eval \$var;
${indent}${INDENT}\$err = \$\@;
${indent}${INDENT}select \$old_fh;
${indent}};
${indent}\$err ||= \$\@;
${indent}if (\$err) {
${indent}${INDENT}\$self->throw('undef', \$err) if ! UNIVERSAL::can(\$err, 'type');
${indent}${INDENT}die \$err;
${indent}}";

    return;
}


sub compile_js_PROCESS {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($args, @files) = @{ $node->[3] };
$$str_ref .= "
${indent}alloy.process_d(".$json->encode(\@files).",".$json->encode([@{$args->[0]}[2..$#{$args->[0]}]]).",'$node->[0]', out_ref);\n";
}

sub compile_js_RAWPERL {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_RETURN {
    my ($self, $node, $str_ref, $indent) = @_;

    if (defined($node->[3])) {
        $$str_ref .= "
${indent}\$var = {return_val => ".$self->compile_expr($node->[3])."};
${indent}\$self->throw('return', \$var);";
    } else {
        $$str_ref .= "
${indent}\$self->throw('return', undef);";
    }
}

sub compile_js_SET {
    my ($self, $node, $str_ref, $indent) = @_;
    my $sets = $node->[3];

    my $out = '';
    foreach (@$sets) {
        my ($op, $set, $val) = @$_;

        if ($self->{'_is_default'}) {
            $$str_ref .= "\n${indent}if (! ".$self->compile_expr_js($set, $indent).") {";
            $indent .= $INDENT;
        }
        $$str_ref .= "\n${indent}ref = ";

        if (! defined $val) { # not defined
            $$str_ref .= 'undefined';
        } elsif ($node->[4] && $val == $node->[4]) { # a captured directive
            my $sub_tree = $node->[4];
            $sub_tree = $sub_tree->[0]->[4] if $sub_tree->[0] && $sub_tree->[0]->[0] eq 'BLOCK';
            my $code = $self->compile_tree_js($sub_tree, "$indent$INDENT");
            $$str_ref .= "${indent}do {
${indent}${INDENT}my \$out = '';
${indent}${INDENT}my \$out_ref = \\\$out;$code
${indent}${INDENT}\$out;
${indent}}"
        } else { # normal var
            $$str_ref .= $self->compile_expr_js($val, $indent);
        }

        if ($Template::Alloy::OP_DISPATCH->{$op}) {
            $$str_ref .= ' }';
        }

        $$str_ref .= ";
${indent}alloy.set_variable(".$json->encode($set).", ref)";

        if ($self->{'_is_default'}) {
            substr($indent, -length($INDENT), length($INDENT), '');
            $$str_ref .= "\n$indent}";
        }

        $$str_ref .= ";";
    }

    return $out;
}

sub compile_js_STOP {
    my ($self, $node, $str_ref, $indent) = @_;
    $$str_ref .= "
${indent}\$self->throw('stop', 'Control Exception');";
}

sub compile_js_SWITCH {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "
${indent}\$var = ".$self->compile_expr($node->[3], $indent).";";

    my $default;
    my $i = 0;
    while ($node = $node->[5]) { # CASES
        if (! defined $node->[3]) {
            $default = $node;
            next;
        }

        $$str_ref .= _node_info($self, $node, $indent);
        $$str_ref .= "\n$indent" .($i++ ? "} els" : ""). "if (do {
${indent}${INDENT}no warnings;
${indent}${INDENT}my \$var2 = ".$self->compile_expr($node->[3], "$indent$INDENT").";
${indent}${INDENT}scalar grep {\$_ eq \$var} (UNIVERSAL::isa(\$var2, 'ARRAY') ? \@\$var2 : \$var2);
${indent}${INDENT}}) {
${indent}${INDENT}my \$var;";

        $$str_ref .= $self->compile_tree($node->[4], "$indent$INDENT");
    }

    if ($default) {
        $$str_ref .= _node_info($self, $default, $indent);
        $$str_ref .= "\n$indent" .($i++ ? "} else {" : "if (1) {");
        $$str_ref .= $self->compile_tree($default->[4], "$indent$INDENT");
    }

    $$str_ref .= "\n$indent}" if $i;

    return;
}

sub compile_js_THROW {
    my ($self, $node, $str_ref, $indent) = @_;

    my ($name, $args) = @{ $node->[3] };

    my ($named, @args) = @$args;
    push @args, $named if ! _is_empty_named_args($named); # add named args back on at end - if there are some

    $$str_ref .= "
${indent}\$self->throw(".$self->compile_expr($name, $indent).", [".join(", ", map{$self->compile_expr($_, $indent)} @args)."]);";
    return;
}


sub compile_js_TRY {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "
${indent}do {
${indent}my \$out = '';
${indent}eval {
${indent}${INDENT}my \$out_ref = \\\$out;"
    . $self->compile_tree($node->[4], "$indent$INDENT") ."
${indent}};
${indent}my \$err = \$\@;
${indent}\$\$out_ref .= \$out;
${indent}if (\$err) {";

    my $final;
    my $i = 0;
    my $catches_str = '';
    my @names;
    while ($node = $node->[5]) { # CATCHES
        if ($node->[0] eq 'FINAL') {
            $final = $node;
            next;
        }
        $catches_str .= _node_info($self, $node, "$indent$INDENT");
        $catches_str .= "\n${indent}${INDENT}} elsif (\$index == ".(scalar @names).") {";
        $catches_str .= $self->compile_tree($node->[4], "$indent$INDENT$INDENT");
        push @names, $node->[3];
    }
    if (@names) {
        $$str_ref .= "
${indent}${INDENT}\$err = \$self->exception('undef', \$err) if ! UNIVERSAL::can(\$err, 'type');
${indent}${INDENT}my \$type = \$err->type;
${indent}${INDENT}die \$err if \$type =~ /stop|return/;
${indent}${INDENT}local \$self->{'_vars'}->{'error'} = \$err;
${indent}${INDENT}local \$self->{'_vars'}->{'e'}     = \$err;

${indent}${INDENT}my \$index;
${indent}${INDENT}my \@names = (";
        $i = 0;
        foreach $i (0 .. $#names) {
            if (defined $names[$i]) {
                $$str_ref .= "\n${indent}${INDENT}${INDENT}scalar(".$self->compile_expr($names[$i], "$indent$INDENT$INDENT")."), # $i;";
            } else {
                $$str_ref .= "\n${indent}${INDENT}${INDENT}undef, # $i";
            }
        }
        $$str_ref .= "
${indent}${INDENT});
${indent}${INDENT}for my \$i (0 .. \$#names) {
${indent}${INDENT}${INDENT}my \$name = (! defined(\$names[\$i]) || lc(\$names[\$i]) eq 'default') ? '' : \$names[\$i];
${indent}${INDENT}${INDENT}\$index = \$i if \$type =~ m{^ \\Q\$name\\E \\b}x && (! defined(\$index) || length(\$names[\$index]) < length(\$name));
${indent}${INDENT}}
${indent}${INDENT}if (! defined \$index) {
${indent}${INDENT}${INDENT}die \$err;"
.$catches_str."
${indent}${INDENT}}";

    } else {
        $$str_ref .= "
${indent}\$self->throw('throw', 'Missing CATCH block');";
    }
    $$str_ref .= "
${indent}}";
    if ($final) {
        $$str_ref .= _node_info($self, $final, $indent);
        $$str_ref .= $self->compile_tree($final->[4], "$indent");
    }
    $$str_ref .="
${indent}};";

    return;
}

sub compile_js_UNLESS { $DIRECTIVES->{'IF'}->(@_) }

sub compile_js_USE {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_VIEW {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($blocks, $args, $name) = @{ $node->[3] };

    my $_name = $json->encode($name);

    # [[undef, '{}', 'key1', 'val1', 'key2', 'val2'], 0]
    $args = $args->[0];
    $$str_ref .= "
${indent}do {
${indent}${INDENT}my \$name = $_name;
${indent}${INDENT}my \$hash = {};";
    foreach (my $i = 2; $i < @$args; $i+=2) {
        $$str_ref .= "
${indent}${INDENT}\$var = ".$self->compile_expr($args->[$i+1], $indent).";
${indent}${INDENT}";
        my $key = $args->[$i];
        if (ref $key) {
            if (@$key == 2 && ! ref($key->[0]) && ! $key->[1]) {
                $key = $key->[0];
            } else {
                $$str_ref .= "
${indent}${INDENT}\$self->set_variable(".$self->compile_expr($key, $indent).", \$var);";
                next;
            }
        }
        $key =~ s/([\'\\])/\\$1/g;
        $$str_ref .= "\$hash->{'$key'} = \$var;";
    }

    $$str_ref .= "
${indent}${INDENT}my \$prefix = \$hash->{'prefix'} || (ref(\$name) && \@\$name == 2 && ! \$name->[1] && ! ref(\$name->[0])) ? \"\$name->[0]/\" : '';
${indent}${INDENT}my \$blocks = \$hash->{'blocks'} = {};";
    foreach my $key (keys %$blocks) {
        my $code = $self->compile_tree($blocks->{$key}, "$indent$INDENT$INDENT$INDENT");
        $key =~ s/([\'\\])/\\$1/g;
        $$str_ref .= "
${indent}${INDENT}\$blocks->{'$key'} = {
${indent}${INDENT}${INDENT}name  => \$prefix . '$key',
${indent}${INDENT}${INDENT}_perl => {code => sub {
${indent}${INDENT}${INDENT}${INDENT}my (\$self, \$out_ref, \$var) = \@_;$code

${indent}${INDENT}${INDENT}${INDENT}return 1;
${indent}${INDENT}${INDENT}} },
${indent}${INDENT}};";
    }

    $$str_ref .= "
${indent}${INDENT}\$self->throw('view', 'Could not load Template::View library')
${indent}${INDENT}${INDENT} if ! eval { require Template::View };
${indent}${INDENT}my \$view = Template::View->new(\$self->context, \$hash)
${indent}${INDENT}${INDENT}|| \$self->throw('view', \$Template::View::ERROR);
${indent}${INDENT}my \$old_view = \$self->play_expr(['view', 0]);
${indent}${INDENT}\$self->set_variable(\$name, \$view);
${indent}${INDENT}\$self->set_variable(['view', 0], \$view);";

    if ($node->[4]) {
        $$str_ref .= "
${indent}${INDENT}my \$out = '';
${indent}${INDENT}my \$out_ref = \\\$out;"
    .$self->compile_tree($node->[4], "$indent$INDENT");
    }

    $$str_ref .= "
${indent}${INDENT}\$self->set_variable(['view', 0], \$old_view);
${indent}${INDENT}\$view->seal;
${indent}};";


    return;
}

sub compile_js_WHILE {
    my ($self, $node, $str_ref, $indent) = @_;

    local $self->{'_in_loop'} = 'WHILE';
    my $code = $self->compile_tree($node->[4], "$indent$INDENT");

    $$str_ref .= "
${indent}my \$count = \$Template::Alloy::WHILE_MAX;
${indent}WHILE: while (--\$count > 0) {
${indent}my \$var = ".$self->compile_expr($node->[3], $indent).";
${indent}last if ! \$var;$code
${indent}}";
    return;
}

sub compile_js_WRAPPER {
    my ($self, $node, $str_ref, $indent) = @_;

    my ($named, @files) = @{ $node->[3] };
    $named = $json->encode($named);

    $$str_ref .= "
${indent}\$var = do {
${indent}${INDENT}my \$out = '';
${indent}${INDENT}my \$out_ref = \\\$out;"
.$self->compile_tree($node->[4], "$indent$INDENT")."
${indent}${INDENT}\$out;
${indent}};
${indent}for my \$file (reverse("
.join(",${indent}${INDENT}", map {"\$self->play_expr(".$json->encode($_).")"} @files).")) {
${indent}${INDENT}local \$self->{'_vars'}->{'content'} = \$var;
${indent}${INDENT}\$var = '';
${indent}${INDENT}require Template::Alloy::Play;
${indent}\$Template::Alloy::Play::DIRECTIVES->{'INCLUDE'}->(\$self, [$named, \$file], ['$node->[0]', $node->[1], $node->[2]], \\\$var);
${indent}}
${indent}\$\$out_ref .= \$var if defined \$var;";

    return;
}


###----------------------------------------------------------------###

1;

__END__

=head1 DESCRIPTION

The Template::Alloy::Compile role allows for taking the AST returned
by the Parse role, and translating it into a perl code document.  This
is in contrast Template::Alloy::Play which executes the AST directly.

=head1 TODO

=over 4

=item

Translate compile_RAWPERL to actually output rather than calling play_RAWPERL.

=back

=head1 ROLE METHODS

=over 4

=item C<compile_tree_js>

Takes an AST returned by parse_tree and translates it into
perl code using functions stored in the $DIRECTIVES hashref.

A template that looked like the following:

    Foo
    [% GET foo %]
    [% GET bar %]
    Bar

would parse to the following javascript code:

    (function (alloy) {
    // Generated by Template::Alloy::JS v1.016 on Sat Sep 24 00:38:55 2011
    // From file /home/paul/bar.tt

    var blocks = {};
    var meta   = {};
    var code   = function (alloy, out_ref, args) {

      out_ref[0] += "    Foo\n    ":

      // "GET" Line 2 char 6 (chars 14 to 22)
      ref = alloy.play_expr(["foo",0]);
      out_ref[0] += (typeof ref != 'undefined') ? ref : alloy.undefined_get(["foo",0]);

      out_ref[0] += "\n    ":

      // "GET" Line 3 char 6 (chars 32 to 40)
      ref = alloy.play_expr(["bar",0]);
      out_ref[0] += (typeof ref != 'undefined') ? ref : alloy.undefined_get(["bar",0]);

      out_ref[0] += "\n    Bar":

      return out_ref;
    };

    return {
      'blocks' : blocks,
      'meta'   : meta,
      'code'   : code
    };
    })()

As you can see the output is quite a bit more complex than the AST, but under
mod_perl conditions, the javascript will run faster than playing the AST each time.

=item C<compile_expr_js>

Takes an AST variable or expression and returns perl code that can lookup
the variable.

=back

=head1 AUTHOR

Paul Seamons <paul at seamons dot com>

=head1 LICENSE

This module may be distributed under the same terms as Perl itself.

=cut
