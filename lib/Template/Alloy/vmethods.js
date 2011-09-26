var $_item_ops = {
  '0':   function (s) { return s },
  abs:   function (s) { return Math.abs(s) },
  atan2: function (x,y) { if (y==null) y=0; return Math.atan2(x,y) },
  chunk: function (s, size) {
    s = ''+s;
    if (!size) size = 1;
    var list = [];
    var i = 0;
    if (size < 0) { size *= -1; i = s.length % size; list.push(s.substr(0,i)) }
    for (; i < s.length; i+=size) list.push(s.substr(i, size));
    return list;
  },
  collapse: function (s) { return (''+s).replace(/^\s+/,'').replace(/\s+$/,'').replace(/\s+/g,' ') },
  cos:      function (s) { return Math.cos(s) },
  defined:  function (s) { return (s==null)?0:1 },
  exp:      function (s) { return Math.exp(s) },
  fmt:      null,
  format:   null,
  hash:     function (s) { say("here "); return {'value': s} },
  hex:      function (s) { return parseInt(s, 16) },
  html:     function (s) { return (''+s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;') },
//    indent   => \&vmethod_indent,
  'int':    function (s) { return parseInt(s) },
  item:     function (s) { return s },
  js:       function (s) { if (!s) return ''; return (''+s).replace(/\n/g,'\\n').replace(/\r/g,'\\r').replace(/(?<!\\)([\"\'])/g,'\\$1') },
  lc:       function (s) { return (''+s).toLowerCase() },
//    lcfirst  => sub { lcfirst $_[0] },
  'length': function (s) { return (''+s).length },
  list:     function (s) { return [s] },
  log:      function (s) { return Math.log(s) },
  lower:    function (s) { return (''+s).toLowerCase() },
//    match    => \&vmethod_match,
//    new      => sub { defined $_[0] ? $_[0] : '' },
  none:     function (s) { return s },
  'null':   function (s) { return '' },
  oct:      function (s) { return parseInt(s, 8) },
//    print    => sub { no warnings; "@_" },
  rand:     function (s) { return Math.random(s) },
//    remove   => sub { vmethod_replace(shift, shift, '', 1) },
//    repeat   => \&vmethod_repeat,
//    replace  => \&vmethod_replace,
//    'return' => \&vmethod_return,
//    search   => sub { my ($str, $pat) = @_; return $str if ! defined $str || ! defined $pat; return $str =~ /$pat/ },
  sin:      function (s) { return Math.sin(s) },
  size:     function (s) { 1 },
//    split    => \&vmethod_split,
  substr:   function (s, i, len, replace) {
      if (!i) i=0;
      if (s == null) return '';
      if (len == null) return (''+s).substr(i);
      s = (''+s).substr(i, len);
      if (replace == null) return s;
      var tail = s.substr(i);
      return s.substr(0,i)+replace+tail;
  },
  reverse: function (s) { var t=''; s=''+s; for (var i = s.length-1; i >= 0; i--) t+= s.charAt(i); return t },
  sprintf: function (s) {
    var a = arguments;
    var i = 0;           // 1 |   2        3            |   4          5      6             |  7     8       9          10
    return (''+s).replace(/%(%|(?:(\d+)\$|)([-+#0 ]*)(?:|(?:([1-9]\d*)|(\*)(?:(\d+)\$|)))(?:|\.(?:(\d+)|(\*)(?:|(\d+)\$))))([scbBoxXuidfegEG])/g, function () {
      var m = arguments;
      if (m[1] == '%') return '%';
      var val   = m[2] != null ? a[m[2]] : a[++i];
      var f     = m[3];
      var width = m[4] != null ? m[4] : m[5] ? a[++i] : m[6] ? a[m[6]] : null;
      var preci = m[7] != null ? m[7] : m[8] ? a[++i] : m[9] ? a[m[9]] : null;
      var type  = m[10];
      width = (width == null) ? 0 : parseInt(width);
      if (val == null) val = '';
      if (width < 0) { width *= -1; flags += '-' }
      if (type == 's') { if (preci) val = (''+val).substr(0, preci) }
      else if (type == 'c') val = String.fromCharCode(parseInt(val));
      else {
        val = parseFloat(val);
        var pre = '';
        var up = type.charCodeAt(0) < 91;
        if (up) type = type.toLowerCase();
        if (preci != null) preci = parseInt(preci);
        if      (type == 'x') { val = (val>>>0).toString(16); if (/#/.test(f)) pre = '0x' }
        else if (type == 'b') { val = (val>>>0).toString(2);  if (/#/.test(f)) pre = '0b' }
        else if (type == 'o') { val = (val>>>0).toString(8);  if (/#/.test(f) && val != '0') pre = '0' }
        else {
          if (type == 'u') { val = val >>> 0; type = d }
          else if (val < 0) { pre = '-'; val *= -1 }
          if      (type == 'e') val = val.toExponential(preci == null ? 6 : preci);
          else if (type == 'g') val = val.toPrecision(  preci == null ? 6 : preci);
          else {
            if (type == i) type = 'd';
            val = val.toFixed(type == 'd' ? 0 : preci == null ? 6 : preci);
            if (!pre) {
              if (/\+/.test(f)) pre = '+';
              else if (/\ /.test(f)) pre = ' ';
            }
          }
        }
        if (/0/.test(f)) {
          if (preci == null || (preci < width && type != 'd')) preci = width;
          var diff = preci - val.length - (type == 'd' ? 0 : pre.length);
          if (diff > 0) val = Array(1+diff).join('0') + val;
        }
        if (pre) val = pre + val;
        if (up) val = val.toUpperCase();
      }
      if (width && val.length < width) {
        var pad = Array(1+width-val.length).join(' ');
        val = /-/.test(f) ? val + pad : pad + val;
      }
      return val;
    });
  },

  sqrt:      function (s) { return Math.sqrt(s) },
  srand:     function (s) { throw "srand is not supported in v8" },
//    stderr   => sub { print STDERR $_[0]; '' },
  trim:      function (s) { return (''+s).replace(/^\s+/,'').replace(/\s+$/,'') },
  uc:        function (s) { return (''+s).toUpperCase() },
//    ucfirst  => sub { ucfirst $_[0] },
  upper:     function (s) { return (''+s).toUpperCase() },
//    upper    => sub { uc $_[0] },
//    uri      => \&vmethod_uri,
//    url      => \&vmethod_url,
  xml:      function (s) { return (''+s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;').replace(/\'/g, '&apos;') }
};
$_item_ops.fmt = function (s, pat) {
  if (s == null) return '';
  if (pat == null) pat = '%s';
  if (arguments.length <= 2) return $_item_ops.sprintf(pat, s);
  return $_item_ops.sprintf(pat, arguments[2], s);
};
$_item_ops.format = function (s, pat) {
  if (s == null) return '';
  if (pat == null) pat = '%s';
  var a = (''+s).split(/\n/);
  var s = '';
  for (var i = 0; i < a.length; i++) a[i] = (arguments.length <= 2)
    ?  $_item_ops.sprintf(pat, a[i])
    :  $_item_ops.sprintf(pat, arguments[2], a[i])
  return a.join("\n");
}

var $_item_methods = {};

var $_hash_ops = {
  hash:  function (h) { return h },
  items: function (h) { var a=[]; for (var i in h) { a.push(i); a.push(h[i]) }; return a },
  keys:  function (h) { var a=[]; for (var i in h) a.push(i); return a },
  size:  function (h) { var n=0; for (var i in h) n++; return n }
};

var $_list_ops = {
  size: function (a) { return a.length },
  join: function (a, j) { if (j==null) j=' '; return a.join(j) }
};

1;