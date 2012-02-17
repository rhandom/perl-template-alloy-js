var alloy = (function ($call_native) {
var Alloy = function () {}, md5_hex, $in = {}, $_vm, $item, $list, $hash, $blocks = {}, $docs = {}, $eval_recurse = 0, $scopeVars, $scopeConfig, $scopeBlocks;

Alloy.prototype = {
call_native: function () {
  var r = $call_native.apply(null, arguments);
  if (r && r._call_native_error) this.throw.apply(this, r._call_native_error);
  return r;
},
undefined_get: function (expr) { return $_env.UNDEFINED_GET ? this.call_native('undefined_get', expr) : '' },
register_template: function (path, info) { $docs[path] = info },
insert: function (paths, out_ref) { out_ref[0] += $_call_native('insert', paths) },
process: function (path, out_ref, top_level) {
  var info = $docs[path];
  if (! info) {
    if ($blocks[path]) {
      info = $blocks[path]._js;
    } else {
      this.call_native('load', path);
      info = $docs[path];
      if (!info) this.throw('file', 'native_load handshake error - path '+path+' was not registered');
    }
  }
  var err;
  try {
    if (top_level) this._template = info;
    this._component = info;
    if (! $_env.RECURSION && $in[info.name] && info.name !== 'input text') this.throw('file', "recursion into '"+info.name+"'")
    $in[info.name] = 1;
    info.code(this, out_ref);
  } catch (e) { err = e };
  if (top_level) delete this._template;
  delete this._component;
  delete $in[info.name];
  if (err != null) if (!top_level || typeof err != 'object' || !err.type || (err.type != 'stop' && err.type != 'return')) throw err;
  return out_ref;
},
process_d: function (files, args, dir, out_ref) {
  if ($_env.NO_INCLUDES) throw "file - NO_INCLUDES was set during a "+dir+" directive";
  for (var i = 0, I = args.length; i < I; i+=2) this.set(args[i], this.get(args[i+1]));
  for (var i = 0, I = files.length; i < I; i++) {
    var file = files[i];
    if (file == null) continue;

    var tmp_out = [''];
    var err;
    var old_com = this._component;
    if (typeof file != 'object' || file instanceof Array) {
      this.saveConfig();
      try { this.process(file, tmp_out) } catch (e) { err = e };
      this.restoreConfig();
    } else { // allow for $template which is used in some odd instances
      var old_val = this._process_dollar_template;
      if (old_val) throw 'process - Recursion detected in '+dir+' \$template';
      this._process_dollar_template = 1;
      this._component = file;
      if ($_env.TRIM) tmp_out[0] = tmp_out[0].replace(/\s+$/,'').replace(/^\s+/,'');
      if (err) {
        //$err = $self->exception('undef', $err) if ! UNIVERSAL::can($err, 'type');
        if (0) err.doc(file);
      }
      this._process_dollar_template = old_val;
    }
    this._component = old_com;
    out_ref[0]+=tmp_out[0];
    if (err) if (typeof err != 'object' || !err.type || err.type != 'return') throw err;
  }
},
process_d_i: function (files, args, dir, out_ref) {
  var err;
  this.saveScope();
  this.saveBlocks();
  try { this.process_d(files, args, dir, out_ref) } catch (e) { err = e };
  this.restoreBlocks();
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
process_s: function (str, argsa) {
  if (typeof str === 'undefined') return '';
  var args = (argsa && argsa[argsa.length-1]) || {};
  if (!md5_hex) {
    eval(this.call_native('load_js', 'md5'));
    if (!md5_hex) this.throw('undef', 'Failed to load md5 js library');
  }
  var m = md5_hex(str);
  var path = 'Alloy_str_ref_cache/'+m.substr(0,3)+'/'+m;
  var out_ref = [''];
  var err;
  this.saveConfig();
  try {
    if (++$eval_recurse > $_env.MAX_EVAL_RECURSE) this.throw('eval_recurse', "MAX_EVAL_RECURSE "+$_env.MAX_EVAL_RECURSE+" reached");

    var a = {}; for (var i in args) a[i.toUpperCase()] = args[i];
    if (a.hasOwnProperty('STRICT') && !a.STRICT) this.throw('eval_strict', 'Cannot disable STRICT once it is enabled');

    this.call_native('load', path, str, a);
    var info = $docs[path];
    if (!info) this.throw('file', 'native_load handshake error - path '+path+' was not registered');

    // delete @ARGS{ grep {! $Template::Alloy::EVAL_CONFIG->{$_}} keys %ARGS }; TODO - which items do we need
    for (var i in a) this.config(i, a[i]);

    this.process(path, out_ref);
  } catch (e) { err = e };
  $eval_recurse--;
  this.restoreConfig();
  if (err) throw err;
  return out_ref[0];
},
saveScope: function () { if ($scopeVars) { $scopeVars.unshift({}) } else $scopeVars = [{}] },
restoreScope: function () {
  if (!$scopeVars) return;
  var s = $scopeVars.shift();
  if (!$scopeVars.length) $scopeVars = null;
  for (var i in s) $_vars[i] = s[i];
},
load_vm: function () {
  if ($item) return;
  eval(this.call_native('load_js', 'vmethods'));
  if (!$_vmethods) this.throw('undef', 'Failed to load vmethods js library');
  $item = $_vmethods.item;
  $list = $_vmethods.list;
  $hash = $_vmethods.hash;
},
vars: function (v) {
  if (v) $_vars = v;
  return $_vars;
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
      if (i >= expr_max) { if ($scopeVars && !$scopeVars[0].hasOwnProperty(name)) $scopeVars[0][name] = $_vars[name]; $_vars[name] = val; return val }
      if (!$_vars[name]) { if ($scopeVars && !$scopeVars[0].hasOwnProperty(name)) $scopeVars[0][name] = null; $_vars[name] = {} }
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
    if (i >= expr_max) { if ($scopeVars && !$scopeVars[0].hasOwnProperty(name)) $scopeVars[0][name] = $_vars[name]; $_vars[name] = val; return val }
    if (!$_vars[name]) { if ($scopeVars && !$scopeVars[0].hasOwnProperty(name)) $scopeVars[0][name] = null; $_vars[name] = {} }
    ref = $_vars[name];
  }

  while (ref != null) {

    if (typeof ref == 'function') {
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
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
    if (!$item) this.load_vm();
    if (name == 'Text') {ref = $item} else if (name == 'List') {ref = $list} else if (name == 'Hash') ref = $hash;
    else if (ref == null) {
      if ($_env.VMETHOD_FUNCTIONS || $_env.VMETHOD_FUNCTIONS == null) ref = $item[name];
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
      if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
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
        } else {
          if (!$item) this.load_vm();
          if ($list[name]) {
            var _args = [ref];
            if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
            ref = $list[name].apply(this, _args);
          } else {
            throw('nested array - no matching vmethod '+name);
          }
        }
      } else if (was_dot_call && ref[name] && typeof ref[name] == 'function') {
        if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
        var _args = [];
        if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
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
        } else {
          if (!$item) this.load_vm();
          if ($hash[name]) {
            var _args = [ref];
            if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
            ref = $hash[name].apply(this, _args);
          } else {
              if (i >= max && ARGS.return_ref) return [[null, ref], 0, '.', name, args];
            ref = null;
          }
        }
      }
    } else {
      if (!$item) this.load_vm();
      if ($item[name]) {
        var _args = [ref];
        if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
        ref = $item[name].apply(this, _args);
      } else if ($list[name]) {
        var _args = [[ref]];
        if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
        ref = $list[name].apply(this, _args);
      } else if (name == 'eval' || name == 'evaltt') {
        var _args = [];
        if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
        ref = this.process_s(ref, _args);
      } else if (typeof name === 'function') {
          try { ref = name(ref) } catch (e) { if (typeof e != 'object' || ! e.type) this.throw('filter', e); throw e };
      } else {
        var filter = $_env && $_env.FILTERS && $_env.FILTERS[name];
        if (filter) {
          if (typeof filter === 'function') {
            try { ref = filter(ref) } catch (e) { if (typeof e != 'object' || ! e.type) this.throw('filter', e); throw e };
          } else if (! (filter instanceof Array)) {
            throw 'filter - invalid FILTER entry for '+name+' (not a CODE ref)';
          } else if (filter.length == 2 && typeof filter[0] === 'function') { // these are the TT style filters
            try {
              var code = filter[0];
              if (filter[1]) { // it is a "dynamic filter" that will return a sub
                var _args = [];
                if (args) for (var j=0;j<args.length;j++) _args.push(typeof args[j] === 'function' ? args[j]() : args[j]);
                code = this.call_native('dynamic_filter', name, code, args);
              }
              ref = code(ref);
            } catch (e) { if (typeof e != 'object' || ! e.type) this.throw('filter', e); throw e };
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
    if ($scopeBlocks && !$scopeBlocks[0].hasOwnProperty(i)) $scopeBlocks[0][i] = $blocks[i];
    $blocks[i] = blocks[i];
  }
},
saveBlocks: function () { if ($scopeBlocks) { $scopeBlocks.unshift({}) } else $scopeBlocks = [{}] },
restoreBlocks: function () {
  if (!$scopeBlocks) return;
  var s = $scopeBlocks.shift();
  if (!$scopeBlocks.length) $scopeBlocks = null;
  for (var i in s) $blocks[i] = s[i];
},
setMeta: function (meta) { for (var i in meta) this._component[i] = meta[i] },
setFilter: function (name, filter) {
  if (!$_env.FILTERS) $_env.FILTERS = {};
  $_env.FILTERS[name] = filter;
},
iterator: function (items) {
  if (items == null) items = [];
  else if (items instanceof Array) items = items;
  else if (typeof items == 'object') { if (!$item) this.load_vm(); items = $hash.pairs(items) }
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
},
tt_debug: function (info) {
  if (! $_env._debug_dirs || $_env._debug_off) return '';
  var format = $_env._debug_format || $_env.DEBUG_FORMAT || "\n## $file line $line : [% $text %] ##\n";
  return (''+format).replace(/\$(file|line|text)/g, function (m, one) { return info[one] });
},
saveConfig: function () { if ($scopeConfig) { $scopeConfig.unshift({}) } else $scopeConfig = [{}] },
restoreConfig: function () {
  if (!$scopeConfig) return;
  var c = $scopeConfig.shift();
  if (!$scopeConfig.length) $scopeConfig = null;
  for (var key in c) {
    $_env[key] = c[key];
    if (key == 'DUMP' || key == 'ADD_LOCAL_PATH') this.call_native('config', key, c[key]);
  }
},
config: function (key, val) {
  if (arguments.length === 1) return $_env[key];
  if (key === 'STRICT' && ! val) this.throw("config.strict", "Cannot disable STRICT once it is enabled");

  var loc = /^(ADD_LOCAL_PATH|CALL_CONTEXT|DUMP|VMETHOD_FUNCTIONS|STRICT|_debug_off|_debug_format)/;
  if (loc.test(key)) {
    if ($scopeConfig && !$scopeConfig[0].hasOwnProperty(key)) $scopeConfig[0][key] = $_env[key];
    $_env[key] = val;
  }
  if (!loc.test(key) || key == 'DUMP' || key == 'ADD_LOCAL_PATH') this.call_native('config', key, val);
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
})($_call_native);
$_call_native = null; // captured, lets get rid of it
1;
