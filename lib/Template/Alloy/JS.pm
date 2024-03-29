package Template::Alloy::JS;

=head1 NAME

Template::Alloy::JS - Compile JS role - allows for compiling the AST to javascript and running on the js engine

=cut

use strict;
use warnings;
use Template::Alloy 1.017;
our @ISA = qw(Template::Alloy); # for objects blessed as Template::Alloy::JS

eval { require JSON } || die "Cannot load JSON library used by Template::Alloy::JS: $@";
my $json = eval { JSON->new->allow_nonref->allow_unknown } || eval { JSON->new };
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
    local $self->{'EVAL_JS'} = 1 if ! $self->{'EVAL_JS'};
    local $self->{'COMPILE_JS'} = 1 if ! $self->{'COMPILE_JS'};
    return $self->process_simple(@_);
}

sub parse_tree_jsr {
    my $self    = shift;
    my $str_ref = shift;
    if (! $str_ref || ! defined $$str_ref) {
        $self->throw('parse.no_string', "No string or undefined during parse", undef, 1);
    }
    return [['JS', 0, length($$str_ref), 2, [$$str_ref]]];
}

our $js_self;
sub process_js {
    my $self = shift;
    local $self->{'SYNTAX'} = 'js';
    local $self->{'EVAL_JS'} = 1 if ! $self->{'EVAL_JS'};
    local $self->{'COMPILE_JS'} = 1 if ! $self->{'COMPILE_JS'};
#    local $js_context;
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
        push @tree, [$1, $begin, pos($$str_ref)];
        $post_chomp = $2 || $self->{'POST_CHOMP'};
        $post_chomp =~ y/-=~+/1230/ if $post_chomp;
        $tree[-1]->[0] =~ s/(?<![\n\;])([\ \t]*)$/;$1/;
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

    return [['JS', 0, length($$str_ref), 1, \@tree]];
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
            $file .= $Template::Alloy::JS_COMPILE_EXT if defined $Template::Alloy::JS_COMPILE_EXT;

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

    my $name = $json->encode($doc->{'_is_str_ref'} ? $doc->{'_filename'} : $doc->{'name'});
    $doc->{'_js_name'} = $name;
    $self->js_context->eval("alloy.register_template($name, $$js)") || $self->throw('compile_js', "Trouble loading compiled js for $name: $@");
    return defined(wantarray) ? \$js : 1;
}

sub play_js {
    my ($self, $doc, $out_ref) = @_;

    my $ctx = $self->js_context;

    local $js_self = $self;
    $ctx->bind('$_vars' => $self->{'_vars'});
    $ctx->bind('$_env'  => {
        QR_PRIVATE        => $Template::Alloy::QR_PRIVATE ? "^[_.]" : 0,
        SYNTAX            => $self->{'SYNTAX'},
        WHILE_MAX         => $Template::Alloy::WHILE_MAX,
        MAX_EVAL_RECURSE  => $self->{'MAX_EVAL_RECURSE'}  || $Template::Alloy::MAX_EVAL_RECURSE,
        MAX_MACRO_RECURSE => $self->{'MAX_MACRO_RECURSE'} || $Template::Alloy::MAX_MACRO_RECURSE,
        (map {$_ => $self->{$_}} grep {defined $self->{$_}} qw(_debug_dirs _debug_off _debug_undef _debug_format DEBUG_FORMAT VMETHOD_FUNCTIONS FILTERS CACHE_STR_REFS)),
        (map {$_ => 1} grep {$self->{$_}} qw(GLOBAL_VARS LOOP_CONTEXT_VARS LOWER_CASE_VAR_FALLBACK NO_INCLUDES RECURSION STRICT TRIM UNDEFINED_GET)),
    });

    my $name = $doc->{'_js_name'} || die "Missing _js_name for $doc->{'name'}";
    my $out  = $ctx->eval("(function (\$_env, \$_vars) { try { var r = alloy.process($name, [''], 1); return r } catch (e) { return {_call_native_throw:e} } })()");
    if (ref($out) eq 'ARRAY') {
        $$out_ref = $out->[0];
    } else {
        my $e = ref($out) eq 'HASH' && $out->{'_call_native_throw'}  || {};
        my $type = ref($e) eq 'HASH' && $e->{'type'} || 'jsthrow';
        my $info = ref($e) eq 'HASH' && $e->{'info'} || $e;
        $info = eval { $json->encode($info) } || "Error encoding error info: $@" if ref($info) && ref($info) ne 'ARRAY';
        $self->throw($type, $info);
    }
    return 1;
}

sub js_context {
    my $self = shift;
    if (!$js_context) {
        eval {require JavaScript::V8} || $self->throw('compile_js', "Trouble loading JavaScript::V8: $@");
        $js_context = JavaScript::V8::Context->new;

        $js_context->bind(say => sub { print $_[0],"\n" });
        $js_context->bind(debug => sub { require CGI::Ex::Dump; CGI::Ex::Dump::debug(@_) });

        $js_context->bind('$_call_native' => \&_call_native);
        $js_context->bind('$_UNITTEST', 1) if $self->{'UNITTEST'}; # enable a few extensions used only during testing
        (my $file = __FILE__) =~ s|JS\.pm$|alloy.js|;
        $js_context->eval(${ $self->slurp($file) }); $self->throw('compile_js', "Trouble loading javascript pre-amble: $@") if $@;
    }
    $js_context;
}

###----------------------------------------------------------------###

sub _call_native {
    my $meth = shift;
    my $code = __PACKAGE__->can("_native_$meth") || return {_call_native_error => [undef => "Unknown method $meth"]};
    my $val;
    return $val if eval { $val = $code->($js_self, @_); 1 };
    my $err = $@;
    return {_call_native_error => [$err->type, $err->info]} if UNIVERSAL::can($err,'type');
    return {_call_native_error => [native => "trouble running native method $meth: $@"]};
}

sub _native_insert {
    my ($self, $files)  = @_;
    $self->throw(file => 'NO_INCLUDES was set during an INSERT directive') if $self->{'NO_INCLUDES'};
    return join '', map {${$self->slurp($self->include_filename($_))}} @$files;
}

sub _native_load_template {
    my ($self, $file, $extra_str, $extra_args) = @_;
    my $doc;
    if (@_ > 2) {
        my $args = ref($extra_args) eq 'HASH' ? $extra_args : {};
        delete @{ $args }{ grep {! $Template::Alloy::EVAL_CONFIG->{$_}} keys %$args };
        local @$self{ keys %$args } = values %$args;
        $doc = $self->load_template(\$extra_str);
    } else {
        $doc = $self->load_template($file);
    }
    $self->throw(file => "Failed to load file $file during native_load") if ! $doc->{'_js_name'};
    return 1;
}

sub _native_load_jslib {
    my ($self, $jsfile) = @_;
    $self->throw(undef => "Invalid jsfile \"$jsfile\"") if $jsfile !~ /^\w+$/;
    (my $file = __FILE__) =~ s|JS\.pm$|$jsfile.js|;
    return ${ $self->slurp($file) };
}

sub _native_undefined_get {
    my $self = shift;
    my $code = $self->{'UNDEFINED_GET'};
    return ref($code) ne 'CODE' ? '' : $code->(@_);
}

sub _native_dump {
    my ($self, $stuff, $from, $to, $name) = @_;
    $stuff = [$stuff] if ref($stuff) ne 'ARRAY';
    local $self->{'_vars'} = $js_context->eval('$_vars') if !@$stuff;
    my @dump = ([[undef, '{}'],0], map {[[undef, '-temp-', $_], 0]} @$stuff);
    my $node = ['DUMP', $from, $to]; # only as insecure as INCLUDE

    require Template::Alloy::Play;
    my $out = "";
    my $docs = $self->{'GLOBAL_CACHE'} || $self->{'_documents'}; $docs = $Template::Alloy::GLOBAL_CACHE if ! ref $docs;
    local $self->{'_component'} = $docs->{$name} if $docs->{$name};
    $Template::Alloy::Play::DIRECTIVES->{'DUMP'}->($self, \@dump, $node, \$out);
    return $out;
}

sub _native_config {
    my ($self, $key, $val) = @_;
    return 0 if !$Template::Alloy::EVAL_CONFIG->{$key};
    $self->throw("config.strict", "Cannot disable STRICT once it is enabled") if $key eq 'STRICT' && ! $val;
    $self->{$key} = $val;
    return 1;
}

sub _native_list_filters {
    my $self = shift;
    my $fil = $self->list_filters;
    return {map {$_ => $fil->{$_};} grep {!$Template::Alloy::ITEM_OPS->{$_} && !$Template::Alloy::ITEM_METHODS->{$_}} keys %$fil};
}

sub _native_dynamic_filter {
    my ($self, $name, $sub, $args) = @_;
    #($sub, my $err) = $sub->($self->context, @$args);
    ($sub, my $err) = $sub->(undef, @$args); # for now this will squash warnings until sv2v8 supports blessed objects - though it will break certain filters
    return $sub if UNIVERSAL::isa($sub, 'CODE');
    if (! $sub && $err) {
        $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
        die $err;
    } else {
        $self->throw('filter', "invalid FILTER for '$name' (not a CODE ref)") if ! UNIVERSAL::can($sub, 'type');
        die $sub;
    }
}

sub _native_PERL {
    my ($self, $node, $raw) = @_;
    require Template::Alloy::Play;
    local $self->{'_vars'} = $js_context->eval('$_vars');
    my $out = '';
    my $ok = eval { $Template::Alloy::Play::DIRECTIVES->{$raw ? 'RAWPERL' : 'PERL'}->($self, $node->[3], $node, \$out); 1 };
    my $err = $@;
    $js_context->bind('$_vars', $self->{'_vars'});
    die $err if ! $ok;
    return $out;
}

sub _native_RAWPERL {
    my ($self, $node) = @_;
    return _native_PERL($self, $node, 1);
}

sub _native_USE {
    my ($self, $module, $args) = @_;
    require Template::Alloy::Play;
    return $Template::Alloy::Play::DIRECTIVES->{'USE'}->($self, [undef, $module, [[[undef, '{}'],0]]], undef, undef, $args || {});
}

###----------------------------------------------------------------###

sub compile_template_js {
    my ($self, $doc) = @_;

    local $self->{'_component'} = $doc;
    my $tree = $doc->{'_tree'} ||= $self->load_tree($doc);

    local $self->{'_blocks'} = '';
    local $self->{'_meta'}   = '';
    local $self->{'_extra_head'} = '';
    local $self->{'_userfunc'} = my $uf = [];

    my $code = $self->compile_tree_js($tree, $INDENT);
    ($uf, my $ufh) = (@$uf) ? (join('', "\n", @$uf), "\n\nvar userfunc   = [];") : ('', '');
    $self->{'_blocks'} .= "\n" if $self->{'_blocks'};
    $self->{'_meta'}   .= "\n" if $self->{'_meta'};

    my $str = "(function () {
// Generated by ".__PACKAGE__." v$VERSION on ".localtime()."
// From file ".($doc->{'_filename'} || $doc->{'name'})."$ufh

var blocks = {$self->{'_blocks'}};
var meta   = {$self->{'_meta'}};
var code   = function (alloy, out_ref) {"
.($self->{'_blocks'} ? "\n${INDENT}alloy.setBlocks(blocks);" : "")
.($self->{'_meta'}   ? "\n${INDENT}alloy.setMeta(meta);" : "")
."$code
};$uf

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
    my $note = "\n\n${indent}// \"$node->[0]\" Line $line char $char (chars $node->[1] to $node->[2])";
    return wantarray ? ($note, $line, $char) : $note;
}

sub compile_tree_js {
    my ($self, $tree, $indent) = @_;
    local $self->{'_compile_args'};
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
            $code .= "\n${indent}out_ref[0] += alloy.tt_debug(".$json->encode($info)."); // DEBUG";
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

sub _compile_expr_js {
    my ($s,$v,$nctx,$sctx) = @_;
    if (! ref $v) {
        if ($nctx) {
            no warnings;
            return $v*1;
        }
        $v .= '' if $sctx; # force numbers to str
        return $json->encode($v);
    }
    my $name = $v->[0];
    my $args = $v->[1];
    return _encode($s,$name,1) if @$v == 2 && ref($name) && !defined($name->[0]) && (! $args || $name->[1] ne '->');
    my @var = (ref($name) ? _encode($s,$name) : $json->encode($name), _compile_args($s, $args));
    my $i = 2;
    while ($i < @$v) {
        my $dot = $v->[$i++];
        $name = $v->[$i++];
        $args = $v->[$i++];
        push @var, "'$dot'", ref($name) ? _encode($s,$name) : $json->encode($name), _compile_args($s, $args);
    }
    $s->{'_compile_args'} ||= 1;
    return 'alloy.get(['.join(',',@var).']'.($nctx?',{},true':'').')';
}
sub _compile_args {
    my ($s, $args) = @_;
    return 0 if !$args;
    return '['.join(',',map{
        local $s->{'_compile_args'} = 0;
        my $arg = _compile_expr_js($s,$_);
        $s->{'_compile_args'} ? "function(){return $arg}" : $arg;
    } @$args).']';
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
        : ($op eq 'qr') ? 'function(){return new RegExp('._compile_expr_js($s,$v->[2]).','._compile_expr_js($s,$v->[3]).')}'
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
        : ($op eq '\\') ? do {
            (my $var = _compile_expr_js($s, $v->[2])) =~ s/\)$/,{return_ref:1})/;
            $var = "(function () { var ref = $var;
${INDENT}if (!(ref instanceof Array)) return ref;
${INDENT}if (!ref[ref.length-1]) ref[ref.length-1]=[]; var args=ref[ref.length-1];
${INDENT}return function () { for (var i=0;i<arguments.length;i++) args.push(arguments[i]); return alloy.get(ref) }; })()"
        }
        : ($op eq '$()') ? "alloy.get(".$json->encode($v->[2]).")" # V8 only supports scalar
        : ($op eq '@()') ? die("@() context is not available via ".__PACKAGE__."\n")
        : die "Unimplemented Op (@$v)";
    return $_[2] ? $n : "[null,$n]";
}

sub _compile_defer_to_play {
    my ($self, $node, $str_ref, $indent) = @_;
    my $directive = uc $node->[0];
    die "Invalid node name \"$directive\"" if $directive !~ /^\w+$/;

    $$str_ref .= "
${indent}ref = ".$json->encode($node).";
${indent}ref = alloy.call_native('$directive', ref);
${indent}if (typeof ref !== 'undefined') out_ref[0] += ref;";
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
${INDENT}${INDENT}_js: {name: '$name2', code: function (alloy, out_ref, args) {
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
    my $config = $node->[3];
    my ($named, @the_rest) = @$config;

    $$str_ref .= "
${indent}ref = "._compile_expr_js($self, $named).";
${indent}for (var k in ref) if (ref.hasOwnProperty(k)) alloy.config(k, ref[k]);"
        if @{ $named->[0] } > 2;

    for my $i (0 .. $#the_rest) {
        my $k = $the_rest[$i];
        if (!$Template::Alloy::EVAL_CONFIG->{$k}) {
            $$str_ref .= "\n${indent}out_ref[0] += ".$json->encode($k).";";
        } else {
            $$str_ref .= "
${indent}ref = alloy.config(".$json->encode($k).");
${indent}out_ref[0] += 'CONFIG $k = '+(typeof ref === 'undefined' ? 'undef' : ref);";
        }
        $$str_ref .= "out_ref[0] += '\\n';" if $i != $#the_rest;
    }
}

sub compile_js_DEBUG {
    my ($self, $node, $str_ref, $indent) = @_;

    my $text = $node->[3]->[0];

    if ($text eq 'on') {
        $$str_ref .= "\n${indent}alloy.config('_debug_off', false);";
    } elsif ($text eq 'off') {
        $$str_ref .= "\n${indent}alloy.config('_debug_off', true);";
    } elsif ($text eq 'format') {
        $$str_ref .= "\n${indent}alloy.config('_debug_format', ".$json->encode($node->[3]->[1]).");";
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
    my $dump = $node->[3];
    my ($named, @dump) = @$dump;
    push @dump, $named if @{ $named->[0] } > 2;
    my $doc  = $self->{'_component'};
    my $name = $doc->{'_is_str_ref'} ? $doc->{'_filename'} : $doc->{'name'};
    $$str_ref .= "
${indent}ref = [".join(", ", map {_compile_expr_js($self, $_)} @dump)."];
${indent}out_ref[0] += alloy.call_native('dump', ref, ".$json->encode($node->[1]).", ".$json->encode($node->[2]).", ".$json->encode($name).");";
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

    for my $str (@strs) {
        $$str_ref .= "
${indent}ref = "._compile_expr_js($self, $str).";
${indent}if (typeof ref !== 'undefined')
${indent}${INDENT}out_ref[0] += alloy.process_s(ref, ["._compile_expr_js($self, $named)."])";
    }
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
        $$str_ref .= "\n${indent}${INDENT}alloy.setFilter(".$json->encode($name).", filter); // alias for future calls";
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
${indent}var \$_v = alloy.vars();
${indent}var old_loop${i} = \$_v.loop;
${indent}var err;
${indent}try {
${indent}var loop${i} = "._compile_expr_js($self, $items).";
${indent}if (loop${i} == null) loop${i} = [];
${indent}if (!loop${i}.get_first) loop${i} = new alloy.iterator(loop${i});
${indent}\$_v.loop = loop${i};";
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
${indent}\$_v.loop = old_loop${i};
${indent}if (err != null) throw err;";
    return;
}

sub compile_js_FOREACH { shift->compile_FOR(@_) }

sub compile_js_IF {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "\n${indent}if ("._compile_expr_js($self, $node->[3]).") {";
    $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");

    while ($node = $node->[5]) { # ELSE, ELSIF's
        $$str_ref .= _node_info($self, $node, $indent);
        if ($node->[0] eq 'ELSE') {
            $$str_ref .= "\n${indent}} else {";
            $$str_ref .= $self->compile_tree_js($node->[4], "$indent$INDENT");
            last;
        } else {
            $$str_ref .= "\n${indent}} else if ("._compile_expr_js($self, $node->[3]).") {";
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
${indent}if (alloy.config('NO_INCLUDES')) alloy.throw('file', 'NO_INCLUDES was set during an INSERT directive');
${indent}alloy.insert([".join(',',map{_compile_expr_js($self,$_)} @files)."], out_ref);\n";
}

sub compile_js_JS {
    my ($self, $node, $str_ref, $indent) = @_;
    $self->throw('js', 'EVAL_JS not set') if ! $self->{'EVAL_JS'};

    if ($self->{'EVAL_JS'} =~ /^[Rr][Aa][Ww]$/) {
        $$str_ref .= "\n${indent}var write = function (s) { out_ref[0] += s }, vars = alloy.vars(), process = function (f,a,l) { return alloy.process_ex(f, a, l) }";
        if ($node->[3] && $node->[3] == 2) {
            $$str_ref .= "\n${indent}".$node->[4]->[0];
            return;
        }
        for my $n ($node->[3] ? @{ $node->[4] } : [$node->[4]->[0]]) {
            if (! ref $n) {
                $$str_ref .= "\n${indent}out_ref[0] += ".$json->encode($n).";";
            } else {
                $$str_ref .= join '', map {"\n${indent}$_"} split /(<=\n)/, $n->[0];
            }
        }
    } else {
        my ($note, $line, $col) = _node_info($self, $node, '');
        my $i = @{ $self->{'_userfunc'} };
        push @{ $self->{'_userfunc'} }, "$note\ntry { userfunc[$i] = (function (\$_vars, \$_env, alloy, userfunc) {
  return eval('(function (write, process, get, set) {'
    +".($node->[3] && $node->[3] == 2 ? $json->encode($node->[4]->[0]): join("
    +", map {!ref($_)
                 ? $json->encode("write(".$json->encode($_).");")
                 : join("\n    +", map {$json->encode($_)} split /(?<=\n)/, $_->[0])
            } ($node->[3] ? @{ $node->[4] } : [$node->[4]->[0]])))."
    +'})');
})() } catch (e) { throw 'Error during eval of JS block starting at line $line col $col: '+e };";
        $$str_ref .= "\n${indent}userfunc[$i](function(s){out_ref[0]+=s},alloy._process, alloy._get, alloy._set);";
    }
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
${indent}ref = "._compile_expr_js($self, $ref).";
${indent}if (ref) {
${indent}${INDENT}var global${i} = !alloy.config('SYNTAX') || alloy.config('SYNTAX') !== 'ht' || alloy.config('GLOBAL_VARS');
${indent}${INDENT}var oldvars${i}; if (! global${i}) oldvars${i} = alloy.vars();
${indent}${INDENT}var items${i}  = ref instanceof Array ? ref : typeof ref == 'object' ? [ref] : [];
${indent}${INDENT}var err${i}; try {
${indent}${INDENT}var lcv${i} = alloy.config('LOOP_CONTEXT_VARS') && ! alloy.config('QR_PRIVATE');
${indent}${INDENT}for (var i${i} = 0, I${i} = items${i}.length-1; i${i} <= I${i}; i${i}++) {
${indent}${INDENT}${INDENT}ref = items${i}[i${i}];
${indent}${INDENT}${INDENT}if (ref && typeof ref !== 'object') alloy.throw('loop', 'Scalar value used in LOOP');
${indent}${INDENT}${INDENT}if (! global${i}) alloy.vars(ref || {});
${indent}${INDENT}${INDENT}else {
${indent}${INDENT}${INDENT}${INDENT}if (i${i} !== 0) alloy.restoreScope();
${indent}${INDENT}${INDENT}${INDENT}alloy.saveScope();
${indent}${INDENT}${INDENT}${INDENT}for (var i in ref) alloy.set(i, ref[i]);
${indent}${INDENT}${INDENT}}
${indent}${INDENT}${INDENT}if (lcv${i}) {
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__counter__', i${i}+1);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__first__', i${i}===0?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__last__', i${i}===I${i}?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__inner__', i${i}>0&&i${i}<I${i}?1:0);
${indent}${INDENT}${INDENT}${INDENT}alloy.set('__odd__', (i${i}%2)?0:1);
${indent}${INDENT}${INDENT}}"
.$self->compile_tree_js($node->[4], "$indent$INDENT$INDENT")."

${indent}${INDENT}}
${indent}${INDENT}} catch (e) { err${i} = e }
${indent}${INDENT}if (!global${i}) alloy.vars(oldvars${i});
${indent}${INDENT}else alloy.restoreScope();
${indent}${INDENT}if (err${i} != null) throw err${i};
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
${indent}${INDENT}var err; var max = alloy.config('MAX_MACRO_RECURSE');
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
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}


sub compile_js_PROCESS {
    my ($self, $node, $str_ref, $indent) = @_;
    my ($args, @files) = @{ $node->[3] };
    my $A = $args->[0];
$$str_ref .= "
${indent}alloy.process_d(["
.join(',',map{_compile_expr_js($self,$_)} @files)."],["
.join(',',map{_encode($self,$A->[$_*2]), _compile_expr_js($self,$A->[$_*2+1])} 1..$#$A/2)
."],'$node->[0]', out_ref);\n";
}

sub compile_js_RAWPERL {
    my ($self, $node, $str_ref, $indent) = @_;
    _compile_defer_to_play($self, $node, $str_ref, $indent);
}

sub compile_js_RETURN {
    my ($self, $node, $str_ref, $indent) = @_;

    if (defined($node->[3])) {
        $$str_ref .= "
${indent}throw (new alloy.exception('return', {return_val => "._compile_expr_js($self, $node->[3])."}));";
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
${indent}ref = "._compile_expr_js($self, $top->[3])."
${indent}switch (ref) {";
        for my $node (@cases) {
            $$str_ref .= _node_info($self, $node, "$indent$INDENT");
            $$str_ref .= "\n${indent}${INDENT}case "._compile_expr_js($self, $node->[3]).":\n";
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
${indent}var switch${i} = "._compile_expr_js($self, $top->[3]).";";
        for my $node (@cases) {
            $$str_ref .= _node_info($self, $node, "$indent$INDENT");
            $$str_ref .= "\n$indent" .($j++ ? "} else " : ""). "if ((function () {
${indent}${INDENT}var val = "._compile_expr_js($self, $node->[3]).";
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
${indent}alloy.throw("._compile_expr_js($self, $name).", [".join(", ", map{_compile_expr_js($self, $_)} @args)."]);";
    return;
}


sub compile_js_TRY {
    my ($self, $node, $str_ref, $indent) = @_;

    $$str_ref .= "
${indent}(function () {
${indent}var err;
${indent}try {"
    . $self->compile_tree_js($node->[4], "$indent$INDENT") ."
${indent}} catch (e) { err = e };
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
${indent}${INDENT}alloy.set('error', err);
${indent}${INDENT}alloy.set('e', err);
${indent}${INDENT}var index${i};
${indent}${INDENT}var names${i} = [";
        my $j = 0;
        foreach $j (0 .. $#names) {
            if (defined $names[$j]) {
                $$str_ref .= "\n${indent}${INDENT}${INDENT}"._compile_expr_js($self, $names[$j]).", // $j;";
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
    my ($var, $module, $args) = @{ $node->[3] };
    $var = $module if ! defined $var;
    my @var = map {($_, 0, '.')} split /(?:\.|::)/, $var;
    pop @var; # remove the trailing '.'

    my ($named, @args) = @$args;
    push @args, $named if @{ $named->[0] } > 2;

    if (lc($module) eq 'iterator') {
        $$str_ref .= "\n${indent}alloy.set(".$json->encode(\@var).", new alloy.iterator("._compile_expr_js($self, $args[0])."));";
        return;
    }

    $$str_ref .= "
${indent}ref = [".join(', ', map {_compile_expr_js($self, $_)} @args)."];
${indent}for (var i = 0; i < ref.length; i++) if (typeof ref[i] === 'function') ref[i] = ref[i]();
${indent}ref = alloy.call_native('USE', ".$json->encode($module).", ref);
${indent}alloy.set(".$json->encode(\@var).", ref);";
}

sub compile_js_VIEW { shift->throw('compile_js', 'The VIEW directive is not supported in COMPILE_JS') }

sub compile_js_WHILE {
    my ($self, $node, $str_ref, $indent) = @_;

    local $self->{'_in_loop'} = 'WHILE';
    local $self->{'_loop_index'} = ($self->{'_loop_index'} || 0) + 1;
    my $i = $self->{'_loop_index'};

    $$str_ref .= "
${indent}var count${i} = alloy.config('WHILE_MAX');
${indent}while (--count${i} > 0) {
${indent}${INDENT}var ref = "._compile_expr_js($self, $node->[3]).";
${indent}${INDENT}if (! ref) break;"
.$self->compile_tree_js($node->[4], "$indent$INDENT")."
${indent}}";
    return;
}

sub compile_js_WRAPPER {
    my ($self, $node, $str_ref, $indent) = @_;

    my ($args, @files) = @{ $node->[3] };
    $$str_ref .= "
${indent}ref = (function () {
${indent}${INDENT}var out_ref = [''];"
.$self->compile_tree_js($node->[4], "${indent}${INDENT}")."
${indent}${INDENT}return out_ref[0];
${indent}})();
${indent}alloy.set('content', ref);
${indent}alloy.process_d_i([".join(',',map{_compile_expr_js($self,$_)} @files)."],[".join(',',map{_encode($self,$_)} @{$args->[0]}[2..$#{$args->[0]}])."],'$node->[0]', out_ref);\n";
    return;
}


###----------------------------------------------------------------###

1;

