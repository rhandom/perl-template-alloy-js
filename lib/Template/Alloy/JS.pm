package Template::Alloy::JS;

=head1 NAME

Template::Alloy::JS - Compile JS role - allows for compiling the AST to javascript and running on the js engine

=cut

use strict;
use warnings;
use Template::Alloy;
our @ISA = qw(Template::Alloy); # for objects blessed as Template::Alloy::JS

eval { require JSON } || die "Cannot load JSON library used by Template::Alloy::JS: $@";
my $json = eval { JSON->new->allow_nonref } || eval { JSON->new };
die "The loaded JSON library does not support the encode method needed by Template::Alloy::JS\n" if ! $json || !$json->can('encode');
our $js_context;

our $VERSION = '1.000';
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
    JS      => \&compile_js_JS,
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

sub new {
    my $self = shift->SUPER::new(@_);
    $self->{'COMPILE_JS'} = 1;
    return $self;
}

sub process_jsr {
    my $self = shift;
    local $self->{'SYNTAX'} = 'jsr';
    local $self->{'COMPILE_JS'} = 1 if ! $self->{'COMPILE_JS'};
    return $self->process_simple(@_);
}

sub parse_tree_jsr {
    my $self    = shift;
    my $str_ref = shift;
    if (! $str_ref || ! defined $$str_ref) {
        $self->throw('parse.no_string', "No string or undefined during parse", undef, 1);
    }
    return [['JS', 0, length($$str_ref), undef, [$$str_ref]]];
}

our $js_self;
our $js_a;
our $js_v;
our $js_m;
sub process_js {
    my $self = shift;
    local $self->{'SYNTAX'} = 'js';
    local $self->{'COMPILE_JS'} = 1 if ! $self->{'COMPILE_JS'};
#    local $js_context;
#    local $js_self;
#    local $js_a;
#    local $js_v;
#    local $js_m;
    return $self->process_simple(@_);
}

sub parse_tree_js {
    my $self    = shift;
    my $str_ref = shift;
    if (! $str_ref || ! defined $$str_ref) {
        $self->throw('parse.no_string', "No string or undefined during parse", undef, 1);
    }

    my $STYLE = $self->{'TAG_STYLE'} || 'default';
    local $self->{'_end_tag'}   = $self->{'END_TAG'}   || $Template::Alloy::Parse::TAGS->{$STYLE}->[1];
    local $self->{'_start_tag'} = $self->{'START_TAG'} || $Template::Alloy::Parse::TAGS->{$STYLE}->[0];

    my @tree;             # the parsed tree
    my $post_chomp = 0;   # previous post_chomp setting
    pos($$str_ref) = 0;

    while (1) {

        ### find the next opening tag
        $$str_ref =~ m{ \G (.*?) $self->{'_start_tag'} }gcxs
            || last;
        my $text = $1;
        if (length $text) {
            if (! $post_chomp) { }
            elsif ($post_chomp == 1) { $text =~ s{ ^ [^\S\n]* \n }{}x  }
            elsif ($post_chomp == 2) { $text =~ s{ ^ \s+         }{ }x }
            elsif ($post_chomp == 3) { $text =~ s{ ^ \s+         }{}x  }
            push @tree, $text if length $text;
        }

        ### take care of whitespace and comments flags
        my $pre_chomp = $$str_ref =~ m{ \G ([+=~-]) }gcx ? $1 : $self->{'PRE_CHOMP'};
        $pre_chomp  =~ y/-=~+/1230/ if $pre_chomp;
        if ($pre_chomp && $tree[-1] && ! ref $tree[-1]) {
            if    ($pre_chomp == 1) { $tree[-1] =~ s{ (?:\n|^) [^\S\n]* \z }{}x  }
            elsif ($pre_chomp == 2) { $tree[-1] =~ s{             (\s+) \z }{ }x }
            elsif ($pre_chomp == 3) { $tree[-1] =~ s{             (\s+) \z }{}x  }
            splice(@tree, -1, 1, ()) if ! length $tree[-1]; # remove the node if it is zero length
        }
        my $begin = pos($$str_ref);

        ### look for the closing tag
        if ($$str_ref !~ m{ \G (.*?) ([+=~-]?) $self->{'_end_tag'} }gcxs) {
            $self->throw("Missing close tag", undef, pos($$str_ref));
        }
        push @tree, ['JS', $begin, pos($$str_ref), undef, [$1]];
        $post_chomp = $2 || $self->{'POST_CHOMP'};
        $post_chomp =~ y/-=~+/1230/ if $post_chomp;
        next;
    }

    ### pull off the last text portion - if any
    if (pos($$str_ref) != length($$str_ref)) {
        my $text  = substr $$str_ref, pos($$str_ref);
        if (! $post_chomp) { }
        elsif ($post_chomp == 1) { $text =~ s{ ^ [^\S\n]* \n }{}x  }
        elsif ($post_chomp == 2) { $text =~ s{ ^ \s+         }{ }x }
        elsif ($post_chomp == 3) { $text =~ s{ ^ \s+         }{}x  }
        push @tree, $text if length $text;
    }

    return \@tree;
}

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
    my $ctx = $js_context;
    if (!$ctx) {
        eval {require JavaScript::V8} || $self->throw('compile_js', "Trouble loading JavaScript::V8: $@");
        $ctx = $js_context = JavaScript::V8::Context->new;

        $ctx->bind(say => sub { print $_[0],"\n" });
        $ctx->bind(debug => sub { require CGI::Ex::Dump; CGI::Ex::Dump::debug(@_) });
        $ctx->bind('$_call_native' => \&_call_native);
        $ctx->eval('function $_n(n) {n==null?0:parseFloat(n)}');
    }

    if (!$js_a) {
        (my $file = __FILE__) =~ s|JS\.pm$|alloy.js|;
        $ctx->eval(${ $self->slurp($file) }); $self->throw('compile_js', "Trouble loading javascript pre-amble: $@") if $@;
        $js_a=1;
    }
    if (!$js_v && (!$self->{'SYNTAX'} || $self->{'SYNTAX'} ne 'js')) {
        (my $file = __FILE__) =~ s|JS\.pm$|vmethods.js|;
        $ctx->eval(${ $self->slurp($file) }); $self->throw('compile_js', "Trouble loading javascript vmethods: $@") if $@;
        $js_v=1;
    }
#    if (!$js_m) {
#        (my $file = __FILE__) =~ s|JS\.pm$|md5.js|;
#        $ctx->eval(${ $self->slurp($file) }); $self->throw('compile_js', "Trouble loading javascript md5: $@") if $@;
#        $js_m=1;
#    }

    my $callback = $ctx->eval(qq{
        alloy.register_template('$doc->{name}',$$js);
        (function (out_ref) { try { var r = alloy.process('$doc->{name}', out_ref, 1); return r } catch (e) { return {_call_native_throw:e} } })
    }) || $self->throw('compile_js', "Trouble loading compiled js for $doc->{name}: $@");

    return {code => sub {
        my ($self, $out_ref) = @_;
        local $js_self = $self;
        $ctx->bind('$_vars' => $self->{'_vars'});
        $ctx->bind('$_env'  => {
            QR_PRIVATE        => $Template::Alloy::QR_PRIVATE ? "^[_.]" : 0,
            SYNTAX            => $self->{'SYNTAX'},
            VMETHOD_FUNCTIONS => $self->{'VMETHOD_FUNCTIONS'},
            WHILE_MAX         => $Template::Alloy::WHILE_MAX,
            MAX_MACRO_RECURSE => $self->{'MAX_MACRO_RECURSE'} || $Template::Alloy::MAX_MACRO_RECURSE,
            (map {$_ => $self->{$_}} grep {defined $self->{$_}} qw(_debug_dirs _debug_off _debug_undef _debug_format DEBUG_FORMAT)),
            (map {$_ => 1} grep {$self->{$_}} qw(GLOBAL_VARS LOOP_CONTEXT_VARS LOWER_CASE_VAR_FALLBACK NO_INCLUDES STRICT TRIM UNDEFINED_GET)),
        });
        my $out = $callback->([$$out_ref]);
        if (ref($out) eq 'ARRAY') {
            $$out_ref = $out->[0];
        } else {
            my $e = ref($out) eq 'HASH' && $out->{'_call_native_throw'}  || {};
            my $type = ref($e) eq 'HASH' && $e->{'type'} || 'jsthrow';
            my $info = ref($e) eq 'HASH' && $e->{'info'} || $e;
            $self->throw($type, $info);
        }
        return 1;
    }};
}

###----------------------------------------------------------------###

sub _call_native {
    my $meth = shift;
    my $code = __PACKAGE__->can("_native_$meth") || return {_call_native_error => ['undef', "Unknown method $meth"]};
    my $val;
    return $val if eval { $val = $code->($js_self, @_); 1 };
    my $err = $@;
    return {_call_native_error => [$err->type, $err->info]} if UNIVERSAL::can($err,'type');
    return {_call_native_error => ['native', "trouble running method $meth: $@"]};
}

sub _native_insert {
    my ($self, $files)  = @_;
    $self->throw('file', 'NO_INCLUDES was set during an INSERT directive') if $self->{'NO_INCLUDES'};
    return join '', map {${$self->slurp($self->include_filename($_))}} @$files;
}

sub _native_load {
    my ($self, $file) = @_;
    my $doc = $self->load_template($file);
    $self->throw('file', "Failed to load file $file during native_load") if ! $doc->{'_js'}->{'code'};
    return 1;
}

sub _native_undefined_get {
    my $self = shift;
    my $code = $self->{'UNDEFINED_GET'};
    return ref($code) eq 'CODE' ? $code->(@_) : '';
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
var code   = function (alloy, out_ref) {"
.($self->{'_blocks'} ? "\n${INDENT}alloy.setBlocks(blocks);" : "")
.($self->{'_meta'}   ? "\n${INDENT}alloy.setMeta(meta);" : "")
."$code
};

return {
${INDENT}name: ".$json->encode($self->{'_component'}->{'name'}).",
${INDENT}blocks: blocks,
${INDENT}meta: meta,
${INDENT}code: code
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
            $code .= "\n\n${indent}out_ref[0] += ".$json->encode($node).";";
            next;
        }

        if ($self->{'_debug_dirs'} && ! $self->{'_debug_off'}) {
            my $info = $self->node_info($node);
            $code .= "\n
${indent}if (\$_env._debug_dirs && ! \$_env._debug_off) { // DEBUG
${indent}${INDENT}var info = ".$json->encode($info).";
${indent}${INDENT}var format = \$_env._debug_format || \$_env.DEBUG_FORMAT || \"\\n## \\\$file line \\\$line : [% \\\$text %] ##\\n\";
${indent}${INDENT}out_ref[0] += (''+format).replace(/\\\$(file|line|text)/g, function (m, one) { return info[one] });
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

sub compile_expr_js { _compile_expr_js($_[0],$_[1]) }
sub _compile_expr_js {
    my ($s,$v,$nctx,$sctx) = @_;
    if (! ref $v) {
        return $v*1 if $nctx;
        $v .= '' if $sctx; # force numbers to str
        return $json->encode($v);
    }
    my $name = $v->[0];
    my $args = $v->[1];
    return _encode($s,$name,1) if @$v == 2 && ref($name) && !defined($name->[0]) && (! $args || $name->[1] ne '->');
    my @var = (ref($name) ? _encode($s,$name) : $json->encode($name), $args ? '['.join(',',map{_compile_expr_js($s,$_)} @$args).']' : 0);
    my $i = 2;
    while ($i < @$v) {
        my $dot = $v->[$i++];
        $name = $v->[$i++];
        $args = $v->[$i++];
        push @var, "'$dot'", ref($name) ? _encode($s,$name) : $json->encode($name), $args ? '['.join(',',map{_compile_expr_js($s,$_)} @$args).']' : 0;
    }
    return 'alloy.get(['.join(',',@var).']'.($nctx?',{},true':'').')';
}
sub _encode {
    my ($s,$v) = @_;
    return $json->encode($v) if ! ref $v;
    return '['.join(',', map {_encode($s,$_)} @$v).']' if defined $v->[0];
    my $op = $v->[1];
    my $n = ($op eq '~' || $op eq '_') ? '(""+'.join('+',map{_compile_expr_js($s,$_)}@$v[2..$#$v]).")"
        : ($op eq '-')  ? (@$v==3 ? '-'._compile_expr_js($s,$v->[2],1) : '('._compile_expr_js($s,$v->[2],1).' - '._compile_expr_js($s,$v->[3],1).')')
        : ($op eq '+')  ? '('._compile_expr_js($s,$v->[2],1).'+'._compile_expr_js($s,$v->[3],1).')'
        : ($op eq '*')  ? '('._compile_expr_js($s,$v->[2],1).'*'._compile_expr_js($s,$v->[3],1).')'
        : ($op eq '/')  ? '('._compile_expr_js($s,$v->[2],1).'/'._compile_expr_js($s,$v->[3],1).')'
        : ($op eq 'div')? 'parseInt('._compile_expr_js($s,$v->[2],1).'/'._compile_expr_js($s,$v->[3],1).')'
        : ($op eq '**') ? 'Math.pow('._compile_expr_js($s,$v->[2],1).','._compile_expr_js($s,$v->[3],1).')'
        : ($op eq '++') ? '(function(){var v1='._compile_expr_js($s,$v->[2],1).'; alloy.set('.$json->encode($v->[2]).', v1+1); return v1'.($v->[3]?'':'+1').'})()'
        : ($op eq '--') ? '(function(){var v1='._compile_expr_js($s,$v->[2],1).'; alloy.set('.$json->encode($v->[2]).', v1-1); return v1'.($v->[3]?'':'-1').'})()'
        : ($op eq '%')  ? '('._compile_expr_js($s,$v->[2],1).'%'._compile_expr_js($s,$v->[3],1).')'
        : ($op eq '>')  ? '('._compile_expr_js($s,$v->[2],1).'>' ._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq '>=') ? '('._compile_expr_js($s,$v->[2],1).'>='._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq '<')  ? '('._compile_expr_js($s,$v->[2],1).'<' ._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq '<=') ? '('._compile_expr_js($s,$v->[2],1).'<='._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq '==') ? '('._compile_expr_js($s,$v->[2],1).'=='._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq '!=') ? '('._compile_expr_js($s,$v->[2],1).'!='._compile_expr_js($s,$v->[3],1).'?1:"")'
        : ($op eq 'gt') ? '(""+'._compile_expr_js($s,$v->[2]).'>' ._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq 'ge') ? '(""+'._compile_expr_js($s,$v->[2]).'>='._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq 'lt') ? '(""+'._compile_expr_js($s,$v->[2]).'<' ._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq 'le') ? '(""+'._compile_expr_js($s,$v->[2]).'<='._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq 'eq') ? '(""+'._compile_expr_js($s,$v->[2]).'=='._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq 'ne') ? '(""+'._compile_expr_js($s,$v->[2]).'!='._compile_expr_js($s,$v->[3]).'?1:"")'
        : ($op eq '?')  ? '('._compile_expr_js($s,$v->[2]).'?'._compile_expr_js($s,$v->[3]).':'._compile_expr_js($s,$v->[4]).')'
        : ($op eq '<=>')? '(function(){var v1='._compile_expr_js($s,$v->[2],1).';var v2='._compile_expr_js($s,$v->[3]).';return v1<v2 ? -1 : v1>v2 ? 1 : 0})()'
        : ($op eq 'cmp')? '(function(){var v1=""+'._compile_expr_js($s,$v->[2]).';var v2='._compile_expr_js($s,$v->[3]).';return v1<v2 ? -1 : v1>v2 ? 1 : 0})()'
        : ($op eq '=')  ? 'alloy.set('.$json->encode($v->[2]).','._compile_expr_js($s,$v->[3]).')'
        : ($op eq 'qr') ? '(new RegExp('._compile_expr_js($s,$v->[2]).','._compile_expr_js($s,$v->[3]).'))'
        : ($op eq '!' || $op eq 'not' || $op eq 'NOT') ? '!'._compile_expr_js($s,$v->[2])
        : ($op eq '&&' || $op eq 'and') ? '('._compile_expr_js($s,$v->[2]).'&&'._compile_expr_js($s,$v->[3]).')'
        : ($op eq '||' || $op eq 'or')  ? '('._compile_expr_js($s,$v->[2]).'||'._compile_expr_js($s,$v->[3]).')'
        : ($op eq '//' || $op eq 'err' || $op eq 'ERR') ? '(function(){var v1='._compile_expr_js($s,$v->[2]).'; return v1==null ? '._compile_expr_js($s,$v->[3]).' : v1})()'
        : ($op eq '{}') ? do {
            my @e;
            my $ok=1;
            for (my $i = 2; $i < @$v; $i+=2) {
                push @e, [my $k = _compile_expr_js($s,$v->[$i],0,1), _compile_expr_js($s,$v->[$i+1])];
                $ok = 0 if $k !~ /^\"/;
            }
            $ok ? '{'.join(',', map {"$_->[0]:$_->[1]"} @e).'}'
                : '(function () { var h = {}; '.join(' ',map{"h[$_->[0]] = $_->[1];"} @e). ' return h })()';
        }
        : ($op eq '[]') ? do {
            my @e;
            my $ok=1;
            for my $n (@$v[2..$#$v]) {
                if (!ref($n)) { push @e, $json->encode($n) }
                elsif (ref($n->[0])&&!$n->[0]->[0]) {
                    if ($n->[0]->[1]ne'..') { push @e, _compile_expr_js($s,$n,1) }
                    elsif (!ref($n->[0]->[2]) && !ref($n->[0]->[3])) { push @e, map{$json->encode($_)} $n->[0]->[2]..$n->[0]->[3] }
                    else { push @e, [_compile_expr_js($s,$n->[0]->[2],1), _compile_expr_js($s,$n->[0]->[3],1)]; $ok = 0 }
                } else { push @e, _compile_expr_js($s,$n) }
            }
            $ok ? '['.join(',', @e).']'
                : '(function () { var a = [];'.join(' ',map{!ref($_) ? "a.push($_);" : "for(var i=$_->[0];i<=$_->[1];i++) a.push(i);"}@e).' return a })()';
        }
        : ($op eq '->') ? 'function () { return '._macro_sub_js($s,$v->[2],$v->[3],'  ').' }'
        : ($op eq '\\') ? "(function () { var ref = alloy.get(".$json->encode($v->[2]).", {return_ref:1});
${INDENT}if (!(ref instanceof Array)) return ref;
${INDENT}if (!ref[ref.length-1]) ref[ref.length-1]=[]; var args=ref[ref.length-1];
${INDENT}return function () { for (var i=0;i<arguments.length;i++) args.push(arguments[i]); return alloy.get(ref) }; })()"
        : die "Unimplemented Op (@$v)";
    return $_[2] ? $n : "[null,$n]";
}

sub _compile_defer_to_play {
    my ($self, $node, $str_ref, $indent) = @_;
    my $directive = $node->[0];
    die "Invalid node name \"$directive\"" if $directive !~ /^\w+$/;
    die;
    $$str_ref .= "
${indent}ref = ".$json->encode($node->[3]).";
${indent}\$_call_native('$directive', ref, ".$json->encode($node).", out_ref);";

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
    $$str_ref .= "\n${indent}"._compile_expr_js($self, $node->[3]).";";
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
        $$str_ref .= "\n${indent}delete \$_env._debug_off;";
    } elsif ($text eq 'off') {
        $$str_ref .= "\n${indent}\$_env._debug_off = 1;";
    } elsif ($text eq 'format') {
        $$str_ref .= "\n${indent}\$_env._debug_format = ".$json->encode($node->[3]->[1]).";";
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
    my $v = _compile_expr_js($self, $node->[3]);
    if ($v =~ /^alloy\./) {
        $$str_ref .= "
${indent}ref = $v;
${indent}out_ref[0] += (ref != null) ? ref : alloy.undefined_get(".$json->encode($node->[3]).");";
    } else {
        $$str_ref .= "
${indent}out_ref[0] += $v;";
    }
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

${indent}${INDENT}var expr = [[null, out_ref[0]], 0, '|'];
${indent}${INDENT}for (var i = 0; i < filter.length; i++) expr.push(filter[i]);
${indent}${INDENT}return alloy.get(expr);
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
${indent}var loop${i} = ".$self->compile_expr_js($items).";
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
$indent${INDENT}alloy.set(".$json->encode($name).", val);";
    } else {
        $$str_ref .= "
$indent${INDENT}if (val && typeof val == 'object' && !(val instanceof Array || val instanceof RegExp)) for (var k in val) alloy.set(k, val[k]);";
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
${indent}if (err != null) throw err;";
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
    my ($args, @files) = @{ $node->[3] };
$$str_ref .= "
${indent}alloy.process_d_i([".join(',',map{_compile_expr_js($self,$_)} @files)."],[".join(',',map{_encode($self,$_)} @{$args->[0]}[2..$#{$args->[0]}])."],'$node->[0]', out_ref);\n";
}

sub compile_js_INSERT {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($args, @files) = @{ $node->[3] };
$$str_ref .= "
${indent}if (\$_env.NO_INCLUDES) alloy.throw('file', 'NO_INCLUDES was set during an INSERT directive');
${indent}alloy.insert([".join(',',map{_compile_expr_js($self,$_)} @files)."], out_ref);\n";
}

sub compile_js_JS {
    my ($self, $node, $str_ref, $indent) = @_;
    $$str_ref .= "\n${indent}(function (write, vars, env, process) {
${indent}var out_ref = [''];
${indent}var \$_env, \$_vars, alloy;
${indent}$node->[4]->[0]
${indent}})(function (s) {out_ref[0]+=s}, \$_vars, \$_env, function (f,a,l,r) { return alloy.process_ex(f,a,l,r ? null : out_ref) })
";
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
    local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
    my $i = $self->{'_loop_index'};

    $$str_ref .= "
${indent}ref = ".$self->compile_expr_js($ref, $indent).";
${indent}if (ref) {
${indent}${INDENT}var global${i} = !\$_env.SYNTAX || \$_env.SYNTAX != 'ht' || \$_env.GLOBAL_VARS;
${indent}${INDENT}var old_vars${i} = \$_vars;
${indent}${INDENT}var items${i}  = ref instanceof Array ? ref : typeof ref == 'object' ? [ref] : [];
${indent}${INDENT}var err${i}; try {
${indent}${INDENT}for (var i${i} = 0, I${i} = items${i}.length-1; i${i} <= I${i}; i${i}++) {
${indent}${INDENT}${INDENT}ref = items${i}[i${i}];
${indent}${INDENT}${INDENT}if (typeof ref != 'object') throw 'loop - Scalar value used in LOOP';
${indent}${INDENT}${INDENT}if (! global${i}) \$_vars = ref;
${indent}${INDENT}${INDENT}else for (var i in ref) alloy.set(i, ref[i]);
${indent}${INDENT}${INDENT}if (\$_env.LOOP_CONTEXT_VARS && ! \$_env.QR_PRIVATE) {
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__counter__', i${i}+1);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__first__', i${i}==0?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__last__', i${i}==I${i}?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__inner__', i${i}>0&&i${i}<I${i}?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__odd__', (i${i}%2)?0:1);
${indent}${INDENT}${INDENT}}"
.$self->compile_tree_js($node->[4], "$indent$INDENT$INDENT")."

${indent}${INDENT}}
${indent}${INDENT}} catch (e) { err${i} = e }
${indent}${INDENT}if (!global${i}) \$_vars = old_vars${i};
${indent}${INDENT}if (err${i} != null) throw err;
${indent}}";
}

sub compile_js_MACRO {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($name, $args) = @{ $node->[3] };

    ### get the sub tree
    my $sub_tree = $node->[4];
    if (! $sub_tree || ! $sub_tree->[0]) {
        $$str_ref .= "
${indent}alloy.set(".$json->encode($name).", null);";
        return;
    } elsif (ref($sub_tree->[0]) && $sub_tree->[0]->[0] eq 'BLOCK') {
        $sub_tree = $sub_tree->[0]->[4];
    }

    $$str_ref .= "
alloy.set(".$json->encode($name).", "._macro_sub_js($self, $args, $sub_tree, $indent).");";
    return;
}

sub _macro_sub_js {
    my ($self, $args, $sub_tree, $indent) = @_;

    my $code = $self->compile_tree_js($sub_tree, "$indent$INDENT");

    my $str = "function () {
${indent}${INDENT}if (!alloy._macro_recurse) alloy._macro_recurse = 0;
${indent}${INDENT}var err; var max = \$_env.MAX_MACRO_RECURSE;
${indent}${INDENT}if (alloy._macro_recurse + 1 > max) alloy.throw('macro_recurse', 'MAX_MACRO_RECURSE '+max+' reached');
${indent}${INDENT}alloy._macro_recurse++;
${indent}${INDENT}alloy.saveScope();
${indent}${INDENT}var out_ref = [''];
${indent}${INDENT}try {";

    my $i = 0;
    foreach my $var (@$args) {
        $str .= "
${indent}${INDENT}alloy.set(".$json->encode($var).", arguments[".$i++."]);";
    }
    $str .= "
${indent}${INDENT}var named = ($i < arguments.length) ? arguments[arguments.length-1] : null;
${indent}${INDENT}if (named && typeof named == 'object' && !(named instanceof Array))
${indent}${INDENT}${INDENT}for (var k in named) alloy.set([k, 0], named[k]);
${indent}${INDENT}$code
${indent}${INDENT}} catch (e) { err = e };
${indent}${INDENT}alloy.restoreScope();
${indent}${INDENT}alloy._macro_recurse--;
${indent}${INDENT}if (err != null) throw err;
${indent}${INDENT}return out_ref[0]
${indent}}";

    return $str;
}

sub compile_js_META {
    my ($self, $node, $str_ref, $indent) = @_;
    if (my $kp = $node->[3]) {
        $kp = {@$kp} if ref($kp) eq 'ARRAY';
        while (my($key, $val) = each %$kp) {
            $self->{'_meta'} .= "\n${indent}".$json->encode($key).":".$json->encode($val).",";
        }
        chop $self->{'_meta'} if $self->{'_meta'};
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
${indent}alloy.process_d([".join(',',map{_compile_expr_js($self,$_)} @files)."],[".join(',',map{_encode($self,$_)} @{$args->[0]}[2..$#{$args->[0]}])."],'$node->[0]', out_ref);\n";
}

sub compile_js_RAWPERL {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_RETURN {
    my ($self, $node, $str_ref, $indent) = @_;

    if (defined($node->[3])) {
        $$str_ref .= "
${indent}throw (new alloy.exception('return', {return_val => ".$self->compile_expr_js($node->[3])."}));";
    } else {
        $$str_ref .= "
${indent}throw (new alloy.exception('return',null));";
    }
}

sub compile_js_SET {
    my ($self, $node, $str_ref, $indent) = @_;
    my $sets = $node->[3];

    my $out = '';
    foreach (@$sets) {
        my ($op, $set, $val) = @$_;

        if ($self->{'_is_default'}) {
            $$str_ref .= "\n${indent}if (! "._compile_expr_js($self,$set).") {";
            $indent .= $INDENT;
        }
        $$str_ref .= "\n${indent}ref = ";

        if (! defined $val) { # not defined
            $$str_ref .= 'null';
        } elsif ($node->[4] && $val == $node->[4]) { # a captured directive
            my $sub_tree = $node->[4];
            $sub_tree = $sub_tree->[0]->[4] if $sub_tree->[0] && $sub_tree->[0]->[0] eq 'BLOCK';
            my $code = $self->compile_tree_js($sub_tree, "$indent$INDENT");
            $$str_ref .= "${indent}(function () {
${indent}${INDENT}var out_ref = [''];$code
${indent}${INDENT}return out_ref[0];
${indent}})();";
        } else { # normal var
            $$str_ref .= _compile_expr_js($self, $val);
        }

        if ($Template::Alloy::OP_DISPATCH->{$op}) {
            $$str_ref .= ' }';
        }

        $$str_ref .= ";
${indent}alloy.set(".$json->encode($set).", ref)";

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
${indent}throw (new alloy.exception('stop', 'Control Exception'));";
}

sub compile_js_SWITCH {
    my ($self, $node, $str_ref, $indent) = @_;

    my $top = $node;
    my @cases;
    my $default;
    my $literal = 1;
    while ($node = $node->[5]) { # CASES
        if (! defined $node->[3]) {
            $default = $node;
            next;
        }
        push @cases, $node;
        $literal = 0 if ref $node->[3];
    }

    if ($literal) {
        $$str_ref .= "
${indent}ref = ".$self->compile_expr_js($top->[3], $indent)."
${indent}switch (ref) {";
        for my $node (@cases) {
            $$str_ref .= _node_info($self, $node, "$indent$INDENT");
            $$str_ref .= "\n${indent}${INDENT}case ".$self->compile_expr_js($node->[3]).":\n";
            $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT$INDENT");
            $$str_ref .= "\n${indent}${INDENT}${INDENT}break;";
        }
        if ($default) {
            $$str_ref .= _node_info($self, $default, "$indent$INDENT");
            $$str_ref .= "\n${indent}${INDENT}default:";
            $$str_ref .= $self->compile_tree_js($default->[4], "$indent$INDENT");
        }
        $$str_ref .= "\n$indent}";
    } else {
        local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
        my $i = $self->{'_loop_index'};
        my $j = 0;
        $$str_ref .= "
${indent}var switch${i} = ".$self->compile_expr_js($top->[3], $indent).";";
        for my $node (@cases) {
            $$str_ref .= _node_info($self, $node, "$indent$INDENT");
            $$str_ref .= "\n$indent" .($j++ ? "} else " : ""). "if ((function () {
${indent}${INDENT}var val = ".$self->compile_expr_js($node->[3], "$indent$INDENT").";
${indent}${INDENT}if (!(val instanceof Array)) return switch${i} == val ? 1 : 0;
${indent}${INDENT}for (var i = 0; i < val.length; i++) if (val[i] == switch${i}) return 1;
${indent}${INDENT}})()) {
${indent}${INDENT}var ref;";
            $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");
        }
        if ($default) {
            $$str_ref .= _node_info($self, $default, "$indent$INDENT");
            $$str_ref .= "\n$indent" .($j++ ? "} else {" : "if (1) {");
            $$str_ref .= $self->compile_tree_js($default->[4], "$indent$INDENT");
        }
        $$str_ref .= "\n$indent}" if $j;
    }

    return;
}

sub compile_js_THROW {
    my ($self, $node, $str_ref, $indent) = @_;

    my ($name, $args) = @{ $node->[3] };

    my ($named, @args) = @$args;
    push @args, $named if ! _is_empty_named_args($named); # add named args back on at end - if there are some

    $$str_ref .= "
${indent}alloy.throw(".$self->compile_expr_js($name, $indent).", [".join(", ", map{$self->compile_expr_js($_, $indent)} @args)."]);";
    return;
}


sub compile_js_TRY {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "
${indent}(function () {
${indent}var err;
//${indent}var out_ref = [''];
${indent}try {"
    . $self->compile_tree_js($node->[4], "$indent$INDENT") ."
${indent}} catch (e) { err = e };
//${indent}\$\$out_ref .= \$out;
${indent}if (err != null) {";

    my $final;
    my $catches_str = '';
    my @names;
    local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
    my $i = $self->{'_loop_index'};
    while ($node = $node->[5]) { # CATCHES
        if ($node->[0] eq 'FINAL') {
            $final = $node;
            next;
        }
        $catches_str .= _node_info($self, $node, "$indent$INDENT");
        $catches_str .= "\n${indent}${INDENT}} else if (index${i} == ".(scalar @names).") {";
        $catches_str .= $self->compile_tree_js($node->[4], "$indent$INDENT$INDENT");
        push @names, $node->[3];
    }
    if (@names) {
        $$str_ref .= "
${indent}${INDENT}if (typeof err != 'object' || ! err.type) err = new alloy.exception('undef', err);
${indent}${INDENT}if (err.type == 'stop' || err.type == 'return') throw err;
${indent}${INDENT}var old_error${i} = \$_vars.error; \$_vars.error = err;
${indent}${INDENT}var old_e${i} = \$_vars.e; \$_vars.e = err;
${indent}${INDENT}var index${i};
${indent}${INDENT}var names${i} = [";
        my $j = 0;
        foreach $j (0 .. $#names) {
            if (defined $names[$j]) {
                $$str_ref .= "\n${indent}${INDENT}${INDENT}".$self->compile_expr_js($names[$j], "$indent$INDENT$INDENT").", // $j;";
            } else {
                $$str_ref .= "\n${indent}${INDENT}${INDENT}null, // $j";
            }
        }
        $$str_ref .= "
${indent}${INDENT}];
${indent}${INDENT}for (var i = 0, I = names${i}.length; i < I; i++) {
${indent}${INDENT}${INDENT}var name = (names${i}[i] == null || (''+names${i}[i]).toLowerCase() == 'default') ? '' : ''+names${i}[i];
${indent}${INDENT}${INDENT}if ((index${i} == null || name.length > (''+names${i}[index${i}]).length) && (new RegExp(name+'\\\\b')).test(err.type))  index${i} = i;
${indent}${INDENT}}
${indent}${INDENT}if (index${i} == null) {
${indent}${INDENT}${INDENT}throw err;"
.$catches_str."
${indent}${INDENT}}";

    } else {
        $$str_ref .= "
${indent}throw (new alloy.exception('throw', 'Missing CATCH block'));";
    }
    $$str_ref .= "
${indent}}";
    if ($final) {
        $$str_ref .= _node_info($self, $final, $indent);
        $$str_ref .= $self->compile_tree_js($final->[4], $indent);
    }
    $$str_ref .="
${indent}})();";

    return;
}

sub compile_js_UNLESS { $DIRECTIVES->{'IF'}->(@_) }

sub compile_js_USE {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_VIEW { shift->throw('compile_js', 'The VIEW directive is not supported in compile_js') }

sub compile_js_WHILE {
    my ($self, $node, $str_ref, $indent) = @_;

    local $self->{'_in_loop'} = 'WHILE';
    local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
    my $i = $self->{'_loop_index'};

    $$str_ref .= "
${indent}var count${i} = \$_env.WHILE_MAX;
${indent}while (--count${i} > 0) {
${indent}${INDENT}var ref = ".$self->compile_expr_js($node->[3], $indent).";
${indent}${INDENT}if (! ref) break;"
.$self->compile_tree_js($node->[4], "$indent$INDENT")."
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

