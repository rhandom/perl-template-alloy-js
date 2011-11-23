var alloy = (function () {
function Alloy () { this.docs={}; this.blocks={} }

Alloy.prototype = {
undefined_get: function (expr) { return $_env.UNDEFINED_GET ? $_call_native('undefined_get', expr) : '' },
register_template: function (path, info) { this.docs[path] = info },
insert: function (paths, out_ref) { out_ref[0] += $_call_native('insert', paths) },
process: function (path, out_ref, top_level) {
  var info = this.docs[path];
  if (! info) {
    if (this.blocks[path]) {
      info = this.blocks[path]._js;
    } else {
      $_call_native('load', path);
      info = this.docs[path];
      if (!info) this.throw('file', 'native_load handshake error - path '+path+' was not registered');
    }
  }
  var err;
  try {
    if (top_level) this._template = info;
    this._component = info;
    info.code(this, out_ref);
  } catch (e) { err = e };
  if (top_level) delete this._template;
  delete this._component;
  if (err != null) if (!top_level || typeof err != 'object' || !err.type || (err.type != 'stop' && err.type != 'return')) throw err;
  return out_ref;
},
process_s: function (str, args) {
  if (args == null) args = [];
  args.unshift(str);
  args.unshift('item_method_eval');
//  if (!md5_hex) { $_call_native
//    say(''+md5_vm_test());
  say(md5_hex(str));

//sub item_method_eval {
//    my $self = shift;
//    my $text = shift; return '' if ! defined $text;
//    my $args = shift || {};
//
//    local $self->{'_eval_recurse'} = $self->{'_eval_recurse'} || 0;
//    $self->throw('eval_recurse', "MAX_EVAL_RECURSE $Template::Alloy::MAX_EVAL_RECURSE reached")
//        if ++$self->{'_eval_recurse'} > ($self->{'MAX_EVAL_RECURSE'} || $MAX_EVAL_RECURSE);
//
//    my %ARGS;
//    @ARGS{ map {uc} keys %$args } = values %$args;
//    delete @ARGS{ grep {! $Template::Alloy::EVAL_CONFIG->{$_}} keys %ARGS };
//    $self->throw("eval_strict", "Cannot disable STRICT once it is enabled") if exists $ARGS{'STRICT'} && ! $ARGS{'STRICT'};
//
//    local @$self{ keys %ARGS } = values %ARGS;
//    my $out = '';
//    $self->process_simple(\$text, $self->_vars, \$out) || $self->throw($self->error);
//    return $out;
//}
    return $_call_native.apply(this, args);
},
process_d: function (files, args, dir, out_ref) {
  if ($_env.NO_INCLUDES) throw "file - NO_INCLUDES was set during a "+dir+" directive";
  for (var i = 0, I = args.length; i < I; i+=2) this.set(args[i], this.get(args[i+1]));
  for (var i = 0, I = files.length; i < I; i++) {
    var file = files[i];
    if (file == null) continue;

    var tmp_out = [''];
    var err;
    if (typeof file != 'object' || file instanceof Array) {
      try { this.process(file, tmp_out) } catch (e) { err = e };
    } else { // allow for $template which is used in some odd instances
      var old_val = this._process_dollar_template;
      var old_com = this._component;
      if (old_val) throw 'process - Recursion detected in '+dir+' \$template';
      this._process_dollar_template = 1;
      this._component = file;
      if ($_env.TRIM) tmp_out[0] = tmp_out[0].replace(/\s+$/,'').replace(/^\s+/,'');
      if (err) {
          //$err = $self->exception('undef', $err) if ! UNIVERSAL::can($err, 'type');
          if (0) err.doc(file);
      }
      this._process_dollar_template = old_val;
      this._component = old_com;
    }
    out_ref[0]+=tmp_out[0];
    if (err) if (typeof err != 'object' || !err.type || err.type != 'return') throw err;
  }
},
process_d_i: function (files, args, dir, out_ref) {
  var err;
  this.saveScope();
  this.saveBScope();
  try { this.process_d(files, args, dir, out_ref) } catch (e) { err = e };
  this.restoreBScope();
  this.restoreScope();
  if (err != null) throw err;
},
process_ex: function (file, args, local, out_ref) {
  if (!args) args = {};
  var out = out_ref ? out_ref : [''];
  var a = []; for (var k in args) { a.push(k); a.push(args[k]) }
  if (local) this.process_d_i([file], a, 'INCLUDE(JS)', out);
  else this.process_d([file], a, 'PROCESS(JS)', out);
  if (!out_ref) return out[0];
},
saveScope: function () { if (this.oldScope) { this.oldScope.unshift({}) } else this.oldScope = [{}] },
restoreScope: function () {
  if (!this.oldScope) return;
  var s = this.oldScope.shift();
  if (!this.oldScope.length) delete this.oldScope;
  for (var i in s) $_vars[i] = s[i];
},
set: function (expr, val, ARGS) {
  if (typeof expr != 'object') expr = [expr,0];
  var i = 0;
  var name = expr[i++];
  var args = expr[i++];
  var ref;
  var expr_max = expr.length - 1;
  if (typeof ARGS != 'object') ARGS = {};

  if (name == null) return undefined;
  if (typeof name == 'object') {
    if (name[0] == null) {
      throw('Operator access (no call context just yet)');
    } else { // a named variable access (ie via $name.foo)
      name = this.get(name);
      if (name == null) return undefined;
      if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
      if (i >= expr_max) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = $_vars[name]; $_vars[name] = val; return val }
      if (!$_vars[name]) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = null; $_vars[name] = {} }
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
    if (i >= expr_max) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = $_vars[name]; $_vars[name] = val; return val }
    if (!$_vars[name]) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = null; $_vars[name] = {} }
    ref = $_vars[name];
  }

  while (ref != null) {

    if (typeof ref == 'function') {
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(this.get(args[j]));
      ref = ref.apply(ref, _args);
        throw('set function access');
      //      my $type = $self->{'CALL_CONTEXT'} || '';
      //      if ($type eq 'item') {
      //          $ref = $ref->(@args);
      //      } else {
      //        my @results = $ref->(@args);
      //        if ($type eq 'list') {
      //            $ref = \@results;
      //        } elsif (defined $results[0]) {
      //            $ref = ($#results > 0) ? \@results : $results[0];
      //        } elsif (defined $results[1]) {
      //            die $results[1]; # TT behavior - why not just throw ?
      //        } else {
      //            $ref = undef;
      //            last;
      //        }
      //    }
    }

    if (i >= expr_max) break;
    var was_dot_call = ARGS.no_dots ? 1 : expr[i++] == '.';
    name = expr[i++];
    args = expr[i++];
    if (typeof name == 'object') name = this.get(name);
    if (name == null || ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE))) {
      ref = undefined;
      break;
    }
    if (typeof ref != 'object') return;

    if (ref instanceof Array) {
      if (!/^-?(?:\d*\.\d+|\d+)$/.test(name)) return;
      var index = parseInt(name);
      if (index < 0) index = ref.length + index;
      if (i >= expr_max) { ref[index] = val; return val }
      if (!ref[index]) ref[index] = {};
      ref = ref[index];
    } else {
      if (i >= expr_max) { ref[name] = val; return val }
      if (!ref[name]) ref[name] = {};
      ref = ref[name];
      continue;
    }
  }

  throw('set end of line');
},
get: function (expr, ARGS, nctx) {
  if (typeof expr != 'object') return expr;
  var i = 0;
  var name = expr[i++];
  var args = expr[i++];
  var max = expr.length-1;
  if (ARGS == null) ARGS = {};
  var ref;
  if (name == null) return undefined;
  if (typeof name == 'object') {
    if (name[0] == null) {
      ref = name[1];
    } else { // a named variable access (ie via $name.foo)
      name = this.get(name);
      if (name == null) return nctx ? 0 : null;
      if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return nctx ? 0 : null;
      if (i >= max && ARGS.return_ref) return [[null, $_vars], 0, '.', name, args];
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return nctx ? 0 : null;
    if (i >= max && ARGS.return_ref) return [[null, $_vars], 0, '.', name, args];
    ref = $_vars[name];
  }

  if (ref == null) {
    if (name == 'Text') {ref = $_item} else if (name == 'List') {ref = $_list} else if (name == 'Hash') ref = $_hash;
    else if (ref == null) {
      if ($_env.VMETHOD_FUNCTIONS || $_env.VMETHOD_FUNCTIONS == null) ref = $_item[name];
      if (ref == null && $_env.LOWER_CASE_VAR_FALLBACK) ref = $_vars[(''+name).toLowerCase()];
      if (ref == null) {
        if (name == 'template') ref = this._template;
        else if (name == 'component') ref = this._component;
      }
    }
  }

  var seen_filters = {};
  while (ref != null) {

    if (typeof ref == 'function' && !(ref instanceof RegExp)) {
      if (i >= max && ARGS.return_ref) return [[null, ref],0];
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(args[j]);
      ref = ref.apply(ref, _args);
      //      my $type = $self->{'CALL_CONTEXT'} || '';
      //      if ($type eq 'item') {
      //          $ref = $ref->(@args);
      //      } else {
      //        my @results = $ref->(@args);
      //        if ($type eq 'list') {
      //            $ref = \@results;
      //        } elsif (defined $results[0]) {
      //            $ref = ($#results > 0) ? \@results : $results[0];
      //        } elsif (defined $results[1]) {
      //            die $results[1]; # TT behavior - why not just throw ?
      //        } else {
      //            $ref = undef;
      //            last;
      //        }
      //    }
    }

    if (i >= max) break;
    var was_dot_call = ARGS.no_dots ? 1 : expr[i++] == '.';
    name = expr[i++];
    args = expr[i++];
    if (typeof name == 'object') name = this.get(name);
    if (name == null || ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE))) {
      ref = null;
      break;
    }

    if (typeof ref == 'object') {
      if (ref instanceof Array) {
        if (/^-?(?:\d*\.\d+|\d+)$/.test(name)) {
          var index = parseInt(name);
          if (index < 0) index = ref.length + index;
          if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
          ref = ref[index];
        } else if ($_list[name]) {
          var _args = [ref];
          if (args) for (var j=0;j<args.length;j++) _args.push(args[j]);
          ref = $_list[name].apply(this, _args);
        } else {
          throw('nested array - no matching vmethod '+name);
        }
      } else if (was_dot_call && ref[name] && typeof ref[name] == 'function') {
        if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
        var _args = [];
        if (args) for (var j=0;j<args.length;j++) _args.push(args[j]);
        ref = ref[name].apply(ref, _args);
        continue;
        //        my $type = $self->{'CALL_CONTEXT'} || '';
        //        my @args = $args ? map { $self->play_expr($_) } @$args : ();
        //        if ($type eq 'item') {
        //            $ref = $ref->$name(@args);
        //            next;
        //        } elsif ($type eq 'list') {
        //            $ref = [$ref->$name(@args)];
        //            next;
        //        }
        //        my @results = eval { $ref->$name(@args) };
        //        if ($@) {
        //            my $class = ref $ref;
        //            die $@ if ref $@ || $@ !~ /Can\'t locate object method "\Q$name\E" via package "\Q$class\E"/ || $type eq 'list';
        //        } elsif (defined $results[0]) {
        //            $ref = ($#results > 0) ? \@results : $results[0];
        //            next;
        //        } elsif (defined $results[1]) {
        //            die $results[1]; # TT behavior - why not just throw ?
        //        } else {
        //            $ref = undef;
        //            last;
        //        }
        //        # didn't find a method by that name - so fail down to hash and array access
      } else {
        if (was_dot_call && ref.hasOwnProperty(name)) {
          if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
          ref = ref[name];
        } else if ($_hash[name]) {
          var _args = [ref];
          if (args) for (var j=0;j<args.length;j++) _args.push(args[j]);
          ref = $_hash[name].apply(this, _args);
        } else {
            if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
          ref = null;
        }
      }
    } else {
      if ($_item[name]) {
        var _args = [ref];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.get(args[j]));
        ref = $_item[name].apply(this, _args);
      } else if ($_list[name]) {
        var _args = [[ref]];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.get(args[j]));
        ref = $_list[name].apply(this, _args);
      } else if (name == 'eval' || name == 'evaltt') {
        var _args = [];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.get(args[j]));
        ref = this.process_s(ref, _args);
      } else {
        var filter = $_env && $_env.FILTERS && $_env.FILTERS[name];
        if (filter) {
          if (! (filter instanceof Array)) {
            throw 'filter - invalid FILTER entry for '+name+' (not a CODE ref)';
          } else { // this looks like our vmethods turned into "filters" (a filter stored under a name)
            if (seen_filters[name]) throw 'Recursive filter alias "'+name+'"';
            seen_filters[name] = 1;
            var _var = [name, 0, '|'];
            for (var j=0;j<filter.length;j++) _var.push(filter[j]);
            for (var j=i;j<expr.length;j++) _var.push(expr[j]);
            expr = _var;
            i = 2;
          }
        } else {
          ref = null;
        }
      }
    }
  }

  if (ref == null) {
    if ($_env.STRICT) this.strict_throw(expr);
    if ($_env._debug_undef) throw this.tt_var_string(expr)+" is undefined\n";
    ref = this.undefined_any(expr,nctx);
  }

  return ref;
},
setBlocks: function (blocks) {
  for (var i in blocks) {
    if (this.oldBScope && !this.oldBScope[0].hasOwnProperty(i)) this.oldBScope[0][i] = this.blocks[i];
    this.blocks[i] = blocks[i];
  }
},
saveBScope: function () { if (this.oldBScope) { this.oldBScope.unshift({}) } else this.oldBScope = [{}] },
restoreBScope: function () {
  if (!this.oldBScope) return;
  var s = this.oldBScope.shift();
  if (!this.oldBScope.length) delete this.oldBScope;
  for (var i in s) this.blocks[i] = s[i];
},
setMeta: function (meta) { for (var i in meta) this._component[i] = meta[i] },
iterator: function (items) {
  if (items == null) items = [];
  else if (items instanceof Array) items = items;
  else if (typeof items == 'object') items = $_hash.pairs(items);
  else items = [items];
  this.items = items;
  this.index = 0;
},
exception: function (type, info) {
  this.type = type;
  this.info = info;
},
strict_throw: function (id) {
  var t = this._template.name;
  var c = this._component.name;
  this.throw('var.undef', 'undefined variable: '+this.tt_var_string(id)+' in '+c+(c != t ? ' while processing '+t : ''));
},
undefined_any: function (id, nctx) { if (nctx) return 0 },
throw: function (type, info) {
  if (typeof type == 'object' && type.type) throw type;
  if (info instanceof Array) {
    var p = info.length ? info[info.length-1] : null;
    var hash = (typeof p == 'object' && !(p instanceof Array)) ? info.pop() : {};
      if (info.length >= 2) {// || p) { //scalar keys %$hash) {
      for (var i = 0, I = info.length; i < I; i++) hash[i] = info[i];
      hash.args = info;
      info = hash;
    } else if (info.length == 1) {
      info = info[0];
    } else {
      info = type;
      type = 'undef';
    }
  }
  throw (new this.exception(type, info));
},
tt_var_string: function (id) {
  if (typeof id != 'object') { if ('0' == id || /^[1-9]\d{0,12}$/.test(id)) { return id }; return (''+id).replace(/\'/g, "\\\'") }
  var v = '';
  for (var i=0; i<id.length; ) v+=id[i++]+(id[i++] ? '('+id[i-1].map(function (el) {return this.tt_var_string(el)},this).join(',')+')' : '')+(id[i++]||'');
  return v;
}
};

Alloy.prototype.iterator.prototype = {
get_first: function () {
    if (!this.items.length) return [null, 3];
    this.index = 0;
    return [this.items[this.index], 0];
},
get_next: function () {
    if (++this.index > this.items.length-1) return [null, 3];
    return [this.items[this.index], 0];
},
items:  function () { return this.items },
index:  function () { return this.index },
max:    function () { return this.items.length-1},
size:   function () { return this.items.length },
count:  function () { return this.index+1 },
number: function () { return this.index+1 },
first:  function () { return this.index == 0 ? 1 : 0 },
last:   function () { return this.index == this.items.length-1 ? 1 : 0 },
odd:    function () { return ((this.index+1) % 2) ? 1 : 0 },
even:   function () { return ((this.index+1) % 2) ? 0 : 1 },
parity: function () { return ((this.index+1) % 2) ? 'odd' : 'even' },
prev:   function () {
    if (this.index <= 0) return null;
    return this.items[this.index - 1];
},
next: function () {
    if (this.index >= this.max) return null;
    return this.items[this.count];
}
};

Alloy.prototype.exception.prototype = {
toString: function () { return this.type + ' error - '+ this.info }
};

return (new Alloy());
})();
1;
