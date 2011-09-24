var alloy = (function () {
//if (!Array.prototype.each) Array.prototype.each = function (code) { var a = []; for (var i=0;i<this.length;i++) a.push(code(this[i])); return a };

function Alloy () { this.templates={} }

Alloy.prototype.set_variable  = function (expr, value) { return $_call_native('set_variable', expr, value) };

Alloy.prototype.undefined_get = function (expr) { return $_call_native('undefined_get', expr) };

Alloy.prototype.register_template = function (path, info) { this.templates[path] = info };

Alloy.prototype.process = function (path, out_ref, args) {
  var info = this.templates[path];
  if (! info) throw("Not ready to handle non-loaded templates");
  return info.code(this, out_ref, args);
}

Alloy.prototype.play_oper = function (op) {
  var ref;
  if (op[1] == '~') ref = ''+this.play_expr(op[2])+this.play_expr(op[3]);
  else if (op[1] == '-') ref = (op.length == 3) ? -this.play_expr(op[2]) : this.play_expr(op[2]) - this.play_expr(op[3]);
  else if (op[1] == '+') ref = this.play_expr(op[2]) + this.play_expr(op[3]);
  else if (op[1] == '-temp-') ref = op[2];
  else if (op[1] == '[]') { ref = []; for (var j=2;j<op.length;j++) {
    var val = this.play_expr(op[j]);
    if (typeof op[j] != 'object' || typeof op[j][0] != 'object' || op[j][0][0] != null || op[j][0][1] != '..' || !(val instanceof Array)) ref.push(val);
    else for (var j = 0; j < val.length; j++) ref.push(val[j]);
  } }
  else if (op[1] == '..') {
    ref = [];  var from = this.play_expr(op[2]);  var to = this.play_expr(op[3]);
    if (/^[\D.]/.test(from) || /^[\D.]/.test(to)) throw("Non-numeric range not supported in V8");
    from = parseInt(from); to = parseInt(to);
    for (var i = from; i <= to; i++) ref.push(i);
  }
  else throw("operator: "+op[1]+"\n");
  //return $self->play_operator($name) if wantarray && $name->[1] eq '..';
  return ref;
};

Alloy.prototype.play_expr = function (expr, ARGS) {
  if (typeof expr != 'object') return expr;

  var i = 0;
  var name = expr[i++];
  var args = expr[i++];
  if (typeof ARGS != 'object') ARGS = {};
  var ref;

  if (name == null) return undefined;
  if (typeof name == 'object') {
    if (name[0] == null) {
      ref = this.play_oper(name);
    } else { // a named variable access (ie via $name.foo)
      name = this.play_expr(name);
      if (name == null) return undefined;
      if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
      if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
      ref = $_vars[name];
    }
  } else {
    if ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE)) return undefined;
    if (i >= expr.length-1 && ARGS.return_ref) throw("   return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};");
    ref = $_vars[name];
  }

  if (ref == null) {
    throw("VirtualMethod " + name);
    //$ref = ($name eq 'template' || $name eq 'component') ? $self->{"_$name"} : $VOBJS->{$name};
    //$ref = $ITEM_METHODS->{$name} || $ITEM_OPS->{$name} if ! $ref && (! defined($self->{'VMETHOD_FUNCTIONS'}) || $self->{'VMETHOD_FUNCTIONS'});
    //$ref = $self->{'_vars'}->{lc $name} if ! defined $ref && $self->{'LOWER_CASE_VAR_FALLBACK'};
  }

  while (ref != null) {

    if (typeof ref == 'function') {
      // return $ref if $i >= $#$var && $ARGS->{'return_ref'};
      var _args = [];
      if (args) for (var j=0;j<args.length;j++) _args.push(this.play_expr(args[j]));
      ref = ref.call(ref, _args);
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
    if (typeof name == 'object') {
      name = this.play_expr(name);
      if (name == null || ($_env.QR_PRIVATE && (""+name).match($_env.QR_PRIVATE))) {
        ref = undefined;
        break;
      }
    }
    if (name == null) { ref = undefined; break }

    if (typeof ref == 'object') {
      if (ref instanceof Array) {
        if (/^-?(?:\d*\.\d+|\d+)$/.test(name)) {
          var index = parseInt(name);
          if (index < 0) index = ref.length + index;
          //return \ $ref->[$name] if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $ref->[$name];
          ref = ref[index];
        } else {
          throw('Array unknown access');
          //if ($LIST_OPS->{$name}) {
          //          $ref = $LIST_OPS->{$name}->($ref, $args ? map { $self->play_expr($_) } @$args : ());
          //      } else {
          //          $ref = undef;
          //      }
        }
      } else {
        if (was_dot_call && ref[name]) {
          ref = ref[name];
        } else {
          throw('object - but no matching prop');
        }
      }
    } else {
      if (name == 'length') ref = (''+ref).length;
      else if (name == '0') ref = ref;
      else throw('nested item - no matching vmethod');
    }
  }

  if (ref == null) {
    ref = '';
  }

  return ref;
};
return (new Alloy());
})();
1;
