var alloy = (function () {
function Alloy () { this.templates={} }

Alloy.prototype = {
undefined_get: function (expr) { return $_call_native('undefined_get', expr) },
register_template: function (path, info) { this.templates[path] = info },
process: function (path, out_ref, args) {
  var info = this.templates[path];
  if (! info) throw("Not ready to handle non-loaded templates");
  return info.code(this, out_ref, args);
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
      if (i >= expr_max) { $_vars[name] = val; return val }
      if (!$_vars[name]) $_vars[name] = {};
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
    //if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
    if (i >= expr_max) { $_vars[name] = val; return val }
    if (!$_vars[name]) $_vars[name] = {};
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
      if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return nctx ? 0 : null;
    if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
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

    if (i >= expr.length-1) break;
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
iterator: function (items) {
    if (items == null) items = [];
//    else if (!items.as_list) items = items.as_list()
    else if (typeof items == 'object') items = $_hash.pairs(items);
    else items = [items];
    this.items = items;
    this.index = 0;
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
max:    function () { return this.items.length - 1},
size:   function () { return this.items.length },
count:  function () { return this.index + 1 },
number: function () { return this.index + 1 },
first:  function () { return this.index == 0 ? 1 : 0 },
last:   function () { return this.index == this.max ? 1 : 0 },
odd:    function () { return this.count % 2 ? 1 : 0 },
even:   function () { return this.count % 2 ? 0 : 1 },
parity: function () { return this.count % 2 ? 'odd' : 'even' },
prev:   function () {
    if (this.index <= 0) return null;
    return this.items[this.index - 1];
},
next: function () {
    if (this.index >= this.max) return null;
    return this.items[this.count];
}
};

return (new Alloy());
})();
1;
