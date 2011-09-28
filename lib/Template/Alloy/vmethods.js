var $_item = {
'0': function (s) { return s },
abs: function (s) { return Math.abs(s) },
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
cos: function (s) { return Math.cos(s) },
defined: function (s) { return (s==null)?'':1 },
exp: function (s) { return Math.exp(s) },
fmt: null,
format: null,
hash: function (s) { say("here "); return {'value': s} },
hex: function (s) { return parseInt(s, 16) },
html: function (s) { return (''+s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;') },
indent: function (s, pre) {
	if (s == null) s = '';
	if (pre == null) pre = 4;
	if (/^\d$/.test(pre)) pre = Array(1+parseInt(pre)).join(" ");
	return s.replace(/^/mg, pre);
},
int: function (s) { if (s == null || !/^\d/.test(s)) return 0; return parseInt(s) },
item: function (s) { return s },
js: function (s) { if (!s) return ''; return (''+s).replace(/\n/g,'\\n').replace(/\r/g,'\\r').replace(/(?<!\\)([\"\'])/g,'\\$1') },
lc: function (s) { return (''+s).toLowerCase() },
lcfirst: function (s) { if (s == null) return ''; return (''+s).substring(0,1).toLowerCase()+('',s).substr(1) },
length: function (s) { if (s == null) return 0; return (''+s).length },
list: function (s) { return [s] },
log: function (s) { return Math.log(s) },
lower: function (s) { return (''+s).toLowerCase() },
match: function (s, pat, g) {
	if (s == null || pat == null) return [];
	var m = (''+s).match(g ? new RegExp(pat,'g') : new RegExp(pat));
	if (! m) return;
	if (g) return m;
	if (m.length > 1) { var a = []; for (var i = 1; i < m.length; i++) a.push(m[i]); return a }
	return 1;
},
'new': function (s) { return s == null ? '' : s },
none: function (s) { return s },
null: function (s) { return '' },
oct: function (s) { return parseInt(s, 8) },
print: function () { return arguments.join(" ") },
rand: function (s) { return Math.random(s) },
remove: function (s, pat) {
	if (s == null || pat == null) return '';
	return (''+s).replace(new RegExp(pat,'g'),'');
},
repeat: function (s, n, join) {
	if (s == null || !(''+s).length) return '';
	n = (n == null || !(''+n).length) ? 1 : parseInt(n);
	var a = []; for (var i = 0; i < n; i++) a.push(s);
	return a.join(join == null ? '' : join);
},
replace: function (s, pat, rep, g) {
	if (s == null) s = '';
	if (pat == null) pat = '';
	if (rep == null) rep = '';
	if (g == null) g = 1;
	return (''+s).replace(g ? new RegExp(pat,'g') : new RegExp(pat), function () {
		var a = arguments;
		return rep.replace(/\\(\\|\$)|\$(\d+)/g, function (m,one,two) {
			if (one) return one;
			two = parseInt(two);
			return (!two || two+1 > a.length) ? '' : a[two];
		});
	});
},
//'return' => \&vmethod_return,
search: function (s, pat) { if (s == null || pat == null) return s; return (''+s).match(new RegExp(pat)) ? 1 : '' },
sin: function (s) { return Math.sin(s) },
size: function (s) { return 1 },
split: function (s, pat, lim) {
	s = (s == null) ? '' : s.toString();
	if (pat == null || !(''+pat).length) pat = ' ';
	if (!lim) return s.split(pat);
	lim = parseInt(lim);
	if (lim < 0) return s.split(pat, -lim); //non-perl behavior use -lim
	var a = [];
	if (!(pat instanceof RegExp)) pat = new RegExp(pat,'g');
	var old_g = pat.global;
	for (var i = 0; i < lim; i++) {
		var m = pat.exec(s);
		if (!m) break;
		a.push(s.substring(0, pat.lastIndex-m[0].length));
		for (var j = 1; j < m.length; j++) a.push(m[j]);
		s = s.substr(pat.lastIndex);
	}
	if (s.length) a.push(s);
	pat.global = old_g;
	return a;
},
substr: function (s, i, len, replace) {
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
	var i = 0;           // 1 |   2        3            |   4          5      6             |     7     8       9          10
	return (''+s).replace(/%(%|(?:(\d+)\$|)([-+#0 ]*)(?:|(?:([1-9]\d*)|(\*)(?:(\d+)\$|)))(?:|\.(?:(\d+)|(\*)(?:|(\d+)\$))))([scbBoxXuidfegEG])/g, function () {
		var m = arguments;
		if (m[1] == '%') return '%';
		var f		 = m[3];
		var width = m[4] != null ? m[4] : m[5] ? a[++i] : m[6] ? a[m[6]] : null;
		var preci = m[7] != null ? m[7] : m[8] ? a[++i] : m[9] ? a[m[9]] : null;
		var type	= m[10];
		var val	 = m[2] != null ? a[m[2]] : a[++i];
		width = (width == null) ? 0 : parseInt(width);
		if (val == null) val = '';
		if (width < 0) { width *= -1; flags += '-' }
		if (type == 's') { val = preci ? (''+val).substr(0, preci) : val.toString() }
		else if (type == 'c') val = String.fromCharCode(parseInt(val));
		else {
			val = parseFloat(val);
			var pre = '';
			var up = type.charCodeAt(0) < 91;
			if (up) type = type.toLowerCase();
			if (preci != null) preci = parseInt(preci);
			if			(type == 'x') { val = (val>>>0).toString(16); if (/#/.test(f)) pre = '0x' }
			else if (type == 'b') { val = (val>>>0).toString(2);	if (/#/.test(f)) pre = '0b' }
			else if (type == 'o') { val = (val>>>0).toString(8);	if (/#/.test(f) && val != '0') pre = '0' }
			else {
				if (type == 'u') { val = val >>> 0; type = d }
				else if (val < 0) { pre = '-'; val *= -1 }
				if			(type == 'e') val = val.toExponential(preci == null ? 6 : preci);
				else if (type == 'g') val = val.toPrecision(	preci == null ? 6 : preci);
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

sqrt: function (s) { return Math.sqrt(s) },
srand: function (s) { throw "srand is not supported in v8" },
//stderr => sub { print STDERR $_[0]; '' },
trim: function (s) { return (''+s).replace(/^\s+/,'').replace(/\s+$/,'') },
uc: function (s) { return (''+s).toUpperCase() },
ucfirst: function (s) { if (s == null) return ''; return (''+s).substring(0,1).toUpperCase()+('',s).substr(1) },
upper: function (s) { return (''+s).toUpperCase() },
uri: function (s) { if (s == null) return ''; return encodeURIComponent(s) },
url: function (s) { if (s == null) return ''; return encodeURIComponent(s) },
xml: function (s) { return (''+s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;').replace(/\'/g, '&apos;') }
};

$_item.fmt = function (s, pat) {
if (s == null) return '';
if (pat == null) pat = '%s';
if (arguments.length <= 2) return $_item.sprintf(pat, s);
return $_item.sprintf(pat, arguments[2], s);
};

$_item.format = function (s, pat) {
if (s == null) return '';
if (pat == null) pat = '%s';
var a = (''+s).split(/\n/);
var s = '';
for (var i = 0; i < a.length; i++) a[i] = (arguments.length <= 2) ? $_item.sprintf(pat, a[i]) : $_item.sprintf(pat, arguments[2], a[i]);
return a.join("\n");
}

var $_list = {
defined: function (a, index) { if (arguments.length == 1) return 1; return a[index == null ? 0 : index] == null ? '' : 1 },
first: function (a, n) { if (!n) return a[0]; return a.slice(0, n) },
fmt: function (a, pat, sep, width) {
	if (pat == null) pat = '%s';
	var b = [];
	if (width == null) { for (var i = 0; i < a.length; i++) b.push($_item.sprintf(pat, a[i])) }
	else for (var i = 0; i < a.length; i++) b.push($_item.sprintf(pat, width, a[i]));
	return b.join(sep == null ? ' ' : sep);
},
grep: function (a, pat) {
	var b = [];
	if (typeof pat == 'function') { for (var i = 0; i < a.length; i++) if (pat(a[i], i)) b.push(a[i]) }
	else { if (!(pat instanceof RegExp)) pat = new RegExp(pat); for (var i = 0; i < a.length; i++) if (pat.test(a[i])) b.push(a[i]) }
	return b;
},
hash: function (a, index) {
	var h = {};
	if (arguments.length == 1) { for (var i = 0; i < a.length; i+=2) h[a[i]] = a[i+1] }
	else { index = parseInt(index); for (var i = 0; i < a.length; i++) h[index++] = a[i] }
	return h;
},
import: function (a) { for (var i=1; i<arguments.length;i++) if (arguments[i] instanceof Array) for (var j=0; j<arguments[i].length; j++) a.push(arguments[i][j]) },
item: function (a, index) { return a[index ? index : 0] },
join: function (a, j) { if (j==null) j=' '; return a.join(j) },
last: function (a, n) { if (!n) return a[a.length-1]; return a.slice(n > a.length ? 0 : a.length - n) },
list: function (a) { return a },
//map => sub { no warnings; my ($ref, $code) = @_; UNIVERSAL::isa($code, 'CODE') ? [map {$code->($_)} @$ref] : [map {$code} @$ref] },
max: function (a) { return a.length - 1 },
merge: function (a) { for (var i = 1; i < arguments.length; i++) if (arguments[i] instanceof Array) a = a.concat(arguments[i]); return a },
new: function () { var a = []; for (var i = 0; i < arguments.length; i++) a.push(arguments[i]); return a },
null: function (a) { return '' },
nsort: function (a, field) {
	var b = [];
	for (var i = 0; i < a.length; i++) b.push([a[i], field == null ? parseFloat(a[i]) : a[i][field]]);
	b = b.sort(function (c, d) { return c[1] < d[1] ? -1 : c[1] > d[1] ? 1 : 0 });
	a = [];
	for (var i = 0; i < b.length; i++) a.push(b[i][0]);
	return a;
},
pick: function (a, n) {
	n = (n == null) ? 1 : parseInt(n);
	if (n < 1) n == 1;
	var b = []; for (var i = 0; i < n; i++) b.push(a[parseInt(Math.random()*a.length)]);
	return (n == 1) ? b[0] : b;
},
pop: function (a) { return a.pop() },
push: function (a) { for (var i = 1; i < arguments.length; i++) a.push(arguments[i]) },
//'return' => \&vmethod_return,
reverse: function (a) { return a.reverse() },
shift: function (a) { return a.shift() },
size: function (a) { return a.length },
slice: function (a, from, to) { if (!from) from = 0; return (to == null) ? a.slice(from) : a.slice(from, to+1) },
sort: function (a, field) {
	var b = [];
	for (var i = 0; i < a.length; i++) b.push([a[i], field == null ? (''+a[i]).toLowerCase() : a[i][field]]);
	b = b.sort(function (c, d) { return c[1] < d[1] ? -1 : c[1] > d[1] ? 1 : 0 });
	a = [];
	for (var i = 0; i < b.length; i++) a.push(b[i][0]);
	return a;
},
splice: function (a, i, len, replace) {
	var args = [i?parseInt(i):0];
	args.push(len==null ? a.length - args[0] : parseInt(len));
	if (arguments.length == 4 && typeof arguments[3] == 'Array') { for (var j=0; j<arguments[3].length; j++) args.push(arguments[3][j]) }
	else for (var j=3; j<arguments.length; j++) args.push(arguments[j]);
	return Array.prototype.splice.apply(a, args);
},
unique: function (a) { var u={}; var b=[]; for (var i=0; i<a.length; i++) if (!u[a[i]]) { u[a[i]]=1; b.push(a[i]) }; return b },
unshift: function (a) { for (var i = arguments.length-1; i >= 1; i--) a.unshift(arguments[i]); }
};

var $_hash = {
defined: function (h, key) { if (arguments.length == 1) return 1; return h[key == null ? '' : key] == null ? '' : 1 },
delete: function (h) { for (var i=1; i<arguments.length;i++) delete h[arguments[i]==null ? '' : arguments[i]] },
each: function (h) { var a = []; for (var i in h) { a.push(i); a.push(h[i]) }; return a },
exists: function (h, key) { return h.hasOwnProperty(key == null ? '' : key) ? 1 : '' },
fmt: function (h, pat, sep, w1, w2) {
	if (pat == null) pat = '%s\t%s';
	var k = []; for (var i in h) k.push(i); k=k.sort();
	var b = [];
	if (arguments.length >= 5) { for (var i = 0; i < k.length; i++) b.push($_item.sprintf(pat, w1, k[i], w2, h[k[i]])) }
	else if (arguments.length == 4) { for (var i = 0; i < k.length; i++) b.push($_item.sprintf(pat, w1, k[i], h[k[i]])) }
	else for (var i = 0; i < k.length; i++) b.push($_item.sprintf(pat, k[i], h[k[i]]));
	return b.join(sep == null ? '\n' : sep);
},
hash: function (h) { return h },
import: function (h) { for (var i=1; i<arguments.length;i++) if (typeof arguments[i] == 'object') for (var j in arguments[i]) h[j] = arguments[i][j] },
item: function (h, key) { if (key == null) key = ''; if ($_env && $_env.QR_PRIVATE && (''+key).match($_env.QR_PRIVATE)) return null; return h[key] },
items: function (h) { var a=[]; for (var i in h) { a.push(i); a.push(h[i]) }; return a },
	keys: function (h) { var a=[]; for (var i in h) a.push(i); return a },
list:		null,
new: function (h) { if (arguments.length == 1 && typeof h == 'object') return h; var H={}; for (var i = 0; i < arguments.length; i+=2) H[arguments[i]] = arguments[i+1]; return H },
null: function (h) { return '' },
nsort: function (h) {
	var b=[]; for (var i in h) b.push([i, parseFloat(h[i])]);
	b = b.sort(function (c, d) { return c[1] < d[1] ? -1 : c[1] > d[1] ? 1 : 0 });
	var a = []; for (var i = 0; i < b.length; i++) a.push(b[i][0]);
	return a;
},
pairs: function (h) { var k=[]; for (var i in h) k.push(i); k = k.sort(); var a = []; for (var i = 0; i < k.length; i++) a.push({key:k[i], value:h[k[i]]}); return a },
//'return' => \&vmethod_return,
size: function (h) { var n=0; for (var i in h) n++; return n },
sort: function (h) {
	var b=[]; for (var i in h) b.push([i, (''+h[i]).toLowerCase()]);
	b = b.sort(function (c, d) { return c[1] < d[1] ? -1 : c[1] > d[1] ? 1 : 0 });
	var a = []; for (var i = 0; i < b.length; i++) a.push(b[i][0]);
	return a;
},
values: function (h) { var a=[]; for (var i in h) a.push(h[i]); return a }
};

$_hash['list'] = function (h, what) { if (what == 'null' || !/^(keys|values|each|pairs)$/.test(what)) what = 'pairs'; return $_hash[what](h) };

$_item.Text = $_item.fmt; $_item.List = $_item.list; $_item.Hash = $_item.hash;
$_list.Text = $_list.fmt; $_list.List = $_list.list; $_list.Hash = $_list.hash;
$_hash.Text = $_hash.fmt; $_hash.List = $_hash.list; $_hash.Hash = $_hash.hash;

1;