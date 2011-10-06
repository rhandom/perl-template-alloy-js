var alloy = (function () {
function Alloy () { this.docs={}; this.blocks={} }

Alloy.prototype = {
undefined_get: function (expr) { return $_env.UNDEFINED_GET ? $_call_native('undefined_get', expr) : '' },
register_template: function (path, info) { this.docs[path] = info },
process: function (path, out_ref, args, top_level) {
  var info = this.docs[path];
  if (! info) {
    if (this.blocks[path]) {
      info = this.blocks[path]._js;
    } else {
      throw "Not ready to handle non-loaded templates";
    }
  }
  try {
    info.code(this, out_ref, args);
  } catch (e) {
    if (!top_level || typeof e != 'object' || !e.type || (e.type != 'stop' && e.type != 'return')) throw e;
  }
  return out_ref;
},
process_d: function (files, args, dir, out_ref) {
  if ($_env.NO_INCLUDES) throw "file - NO_INCLUDES was set during a "+dir+" directive";

  for (var i = 0, I = args.length; i < I; i+=2) {
    var val = this.play_expr(args[i+1]);
    var key = args[i];
//      if (ref($key) && @$key == 2 && $key->[0] eq 'import' && UNIVERSAL::isa($val, 'HASH')) { # import ?! - whatever
//          foreach my $key (keys %$val) {
//              $self->set_variable([$key,0], $val->{$key});
//          }
//          next;
//      }
    this.set_variable(key, val);
  }

  for (var i = 0, I = files.length; i < I; i++) {
    var file = files[i];
    if (file == null) continue;
    file = this.play_expr(file);
    if (file == null) continue;

    var tmp_out = [''];
    var err;
    if (typeof file != 'object' || file instanceof Array) {
      try { this.process(file, tmp_out, args) } catch (e) { err = e };
    } else { // allow for $template which is used in some odd instances
      var old_val = this._process_dollar_template;
      var old_com = this._component;
      if (old_val) throw 'process - Recursion detected in '+dir+' \$template';
      this._process_dollar_template = 1;
      this._component = file;
//            ### run the document however we can
//            if (ref($doc) ne 'HASH' || (! $doc->{'_perl'} && ! $doc->{'_tree'})) {
//                $self->throw('process', "Passed item doesn't appear to be a valid document");
//            } elsif ($doc->{'_perl'}) {
//                eval { $doc->{'_perl'}->{'code'}->($self, \$out) };
//            } else {
//                eval { $self->play_tree($doc->{'_tree'}, \$out) };
//            }
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
saveScope: function () { if (this.oldScope) { this.oldScope.unshift({}) } else this.oldScope = [{}] },
restoreScope: function () {
  if (!this.oldScope) return;
  var s = this.oldScope.shift();
  if (!this.oldScope.length) delete this.oldScope;
  for (var i in s) $_vars[i] = s[i];
},
play_oper: function (op) {
  switch (op[1]) {
  case '+':      return this.play_expr(op[2],{},true) + this.play_expr(op[3],{},true);
  case '*':      return this.play_expr(op[2],{},true) * this.play_expr(op[3],{},true);
  case '/':      return this.play_expr(op[2],{},true) / this.play_expr(op[3],{},true);
  case 'div':    return parseInt(this.play_expr(op[2],{},true) / this.play_expr(op[3],{},true));
  case '%':      return this.play_expr(op[2],{},true) % this.play_expr(op[3],{},true);
  case '**':     return Math.pow(this.play_expr(op[2],{},true), this.play_expr(op[3],{},true));
  case '=':      return this.set_variable(op[2], this.play_expr(op[3]));
  case '++':     var v1=1*this.play_expr(op[2],{},true); this.set_variable(op[2], v1+1); return op[3] ? v1 : v1+1;
  case '--':     var v1=1*this.play_expr(op[2],{},true); this.set_variable(op[2], v1-1); return op[3] ? v1 : v1-1;
  case '&&':     return this.play_expr(op[2]) && this.play_expr(op[3]);
  case '||': case 'or':  case 'OR':  return this.play_expr(op[2]) || this.play_expr(op[3]);
  case '//': case 'err': case 'ERR': var v1=this.play_expr(op[2]); return v1==null ? this.play_expr(op[3]) : v1;
  case '!':      return !this.play_expr(op[2]);
  case '?':      return this.play_expr(op[2]) ? this.play_expr(op[3]) : this.play_expr(op[4]);
  case 'gt':     return this.play_expr(op[2]).toString() >  this.play_expr(op[3]) ? 1 : '';
  case 'ge':     return this.play_expr(op[2]).toString() >= this.play_expr(op[3]) ? 1 : '';
  case 'lt':     return this.play_expr(op[2]).toString() <  this.play_expr(op[3]) ? 1 : '';
  case 'le':     return this.play_expr(op[2]).toString() <= this.play_expr(op[3]) ? 1 : '';
  case '>':      return parseFloat(this.play_expr(op[2],{},true)) >  this.play_expr(op[3],{},true) ? 1 : '';
  case '>=':     return parseFloat(this.play_expr(op[2],{},true)) >= this.play_expr(op[3],{},true) ? 1 : '';
  case '<':      return parseFloat(this.play_expr(op[2],{},true)) <  this.play_expr(op[3],{},true) ? 1 : '';
  case '<=':     return parseFloat(this.play_expr(op[2],{},true)) <= this.play_expr(op[3],{},true) ? 1 : '';
  case 'eq':     return this.play_expr(op[2]).toString() == this.play_expr(op[3]) ? 1 : '';
  case 'ne':     return this.play_expr(op[2]).toString() != this.play_expr(op[3]) ? 1 : '';
  case 'cmp':    var v1=this.play_expr(op[2]).toString(); var v2=this.play_expr(op[3]); return v1 < v2 ? -1 : v1 > v2 ? 1 : 0;
  case '<=>':    var v1=parseFloat(this.play_expr(op[2])); var v2=this.play_expr(op[3]); return v1 < v2 ? -1 : v1 > v2 ? 1 : 0;
  case '-temp-': return op[2];
  case '-':
    return (op.length == 3) ? -this.play_expr(op[2]) : this.play_expr(op[2]) - this.play_expr(op[3]);
  case '~': case '_':
    var s=''; for (var i = 2; i < op.length; i++) { s+=this.play_expr(op[i]) }; return s;
  case 'qr': return new RegExp(this.play_expr(op[2]), this.play_expr(op[3]));
  case '[]':
    var ref = [];
    for (var j=2;j<op.length;j++) {
      var val = this.play_expr(op[j]);
      if (typeof op[j] != 'object' || typeof op[j][0] != 'object' || op[j][0][0] != null || op[j][0][1] != '..' || !(val instanceof Array)) ref.push(val);
      else for (var k = 0; k < val.length; k++) ref.push(val[k]);
    }
    return ref;
  case '{}':
    var ref = {};
    for (var j=2;j<op.length;j+=2) {
      var k = this.play_expr(op[j]);
      ref[k] = (j+1 > op.length-1) ? null : this.play_expr(op[j+1]);
    }
    return ref;
  case '..':
    var ref = [];  var from = this.play_expr(op[2]);  var to = this.play_expr(op[3]);
    if (!/^-?.?\d/.test(from) || !/^-?.?\d/.test(to)) throw("Non-numeric range ("+from+" to "+to+") not supported in V8");
    from = parseInt(from); to = parseInt(to);
    for (var i = from; i <= to; i++) ref.push(i);
    return ref;
  default:
    throw "operator: "+op[1]+"\n";
  }
},
set_variable: function (expr, val, ARGS) {
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
      name = this.play_expr(name);
      if (name == null) return undefined;
      if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
      if (i >= expr_max) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = $_vars[name]; $_vars[name] = val; return val }
      if (!$_vars[name]) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = null; $_vars[name] = {} }
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
    //if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
    if (i >= expr_max) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = $_vars[name]; $_vars[name] = val; return val }
    if (!$_vars[name]) { if (this.oldScope && !this.oldScope[0].hasOwnProperty(name)) this.oldScope[0][name] = null; $_vars[name] = {} }
    ref = $_vars[name];
  }

  while (ref != null) {

    if (typeof ref == 'function') {
      // return $ref if $i >= $#$var && $ARGS->{'return_ref'};
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
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
    if (typeof name == 'object') name = this.play_expr(name);
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
play_expr: function (expr, ARGS, nctx) {
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
      ref = this.play_oper(name);
    } else { // a named variable access (ie via $name.foo)
      name = this.play_expr(name);
      if (name == null) return nctx ? 0 : null;
      if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return nctx ? 0 : null;
      if (i >= max && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return nctx ? 0 : null;
    if (i >= max && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
    ref = $_vars[name];
  }

  if (ref == null) {
    //$ref = ($name eq 'template' || $name eq 'component') ? $self->{"_$name"} : $VOBJS->{$name};
    if (name == 'Text') {ref = $_item} else if (name == 'List') {ref = $_list} else if (name == 'Hash') ref = $_hash;
    if (ref == null) {
      if ($_env.VMETHOD_FUNCTIONS || $_env.VMETHOD_FUNCTIONS == null) ref = $_item[name];
      if (ref == null && $_env.LOWER_CASE_VAR_FALLBACK) ref = $_vars[(''+name).toLowerCase()];
    }
  }

  var seen_filters = {};
  while (ref != null) {

    if (typeof ref == 'function' && !(ref instanceof RegExp)) {
      // return $ref if $i >= $#$var && $ARGS->{'return_ref'};
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
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
    if (typeof name == 'object') name = this.play_expr(name);
    if (name == null || ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE))) {
      ref = null;
      break;
    }

    if (typeof ref == 'object') {
      if (ref instanceof Array) {
        if (/^-?(?:\d*\.\d+|\d+)$/.test(name)) {
          var index = parseInt(name);
          if (index < 0) index = ref.length + index;
          //return \ $ref->[$name] if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $ref->[$name];
          ref = ref[index];
        } else if ($_list[name]) {
          var _args = [ref];
          if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
          ref = $_list[name].apply(this, _args);
        } else {
          throw('nested array - no matching vmethod '+name);
        }
      } else if (was_dot_call && ref[name] && typeof ref[name] == 'function') {
        if (i >= max && ARGS.return_ref) throw "   return $ref if $i >= $#$var && $ARGS->{'return_ref'}";
        var _args = [];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
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
        if (was_dot_call && ref[name]) {
          ref = ref[name];
        } else if ($_hash[name]) {
          var _args = [ref];
          if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
          ref = $_hash[name].apply(this, _args);
        } else {
          ref = null;
        }
      }
    } else {
      if ($_item[name]) {
        var _args = [ref];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
        ref = $_item[name].apply(this, _args);
      } else if ($_list[name]) {
        var _args = [[ref]];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
        ref = $_list[name].apply(this, _args);
      } else if (name == 'eval' || name == 'evaltt') {
        var _args = ['item_method_eval', ref];
        if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
        ref = $_call_native.apply(this, _args);
      } else {
        var filter;
        if (filter = ($_env && $_env.FILTERS && $_env.FILTERS[name])) {
          if (typeof filter == 'function') {
            try { ref = filter(ref) } catch (e) { throw "Filter error: "+e };
          } else if (! (filter instanceof Array)) {
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
          throw('nested item - no matching vmethod '+name);
          ref = null;
        }
      }
    }
  }

  if (ref == null) {
//    ref = '';
    if (nctx) return 0
  }

  return ref;
},
setBlocks: function (blocks) { for (var i in blocks) this.blocks[i] = blocks[i] },
iterator: function (items) {
  if (items == null) items = [];
//  else if (!items.as_list) items = items.as_list()
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
