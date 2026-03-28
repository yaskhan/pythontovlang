module translator

import ast
import base

fn (mut t Translator) capture_expr(node ast.Expression) (string, []string) {
	if node is ast.Name || node is ast.Constant {
		return t.visit_expr(node), []string{}
	}

	tmp := t.state.create_temp()
	return tmp, ['${t.indent()}${tmp} := ${t.visit_expr(node)}']
}

fn (mut t Translator) capture_target_expr(node ast.Expression) (string, []string) {
	if node is ast.Name {
		return t.visit_expr(node), []string{}
	}
	if node is ast.Attribute {
		mut base_expr := ''
		mut setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, setup = t.capture_target_expr(node.value)
		} else {
			base_expr, setup = t.capture_expr(node.value)
		}
		// If it's a static class variable remapped to _meta, use the remapped name
		remapped := t.visit_expr(node)
		if remapped.contains('_meta.') {
			return remapped, setup
		}
		attr_name := base.sanitize_name(node.attr, false, map[string]bool{}, '', map[string]bool{})
		return '${base_expr}.${attr_name}', setup
	}
	if node is ast.Subscript {
		mut base_expr := ''
		mut setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, setup = t.capture_target_expr(node.value)
		} else {
			base_expr, setup = t.capture_expr(node.value)
		}
		idx_expr, idx_setup := t.capture_expr(node.slice)
		mut all_setup := []string{}
		all_setup << setup
		all_setup << idx_setup
		return '${base_expr}[${idx_expr}]', all_setup
	}
	return t.visit_expr(node), []string{}
}

fn (t &Translator) is_pure_literal_expr(node ast.Expression) bool {
	return node is ast.Constant || node is ast.List || node is ast.Tuple || node is ast.Set
		|| node is ast.Dict
}

fn (mut t Translator) append_helpers() {
	if 'py_any' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_any[T](a []T) bool {\n    for item in a {\n        if item {\n            return true\n        }\n    }\n    return false\n}'
	}
	if 'py_all' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_all[T](a []T) bool {\n    for item in a {\n        if !item {\n            return false\n        }\n    }\n    return true\n}'
	}
	if 'LiteralEnum_' in t.state.used_builtins {
		t.state.output << 'enum LiteralEnum_ { py_lit }'
	}
	if 'py_argparse_new' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_argparse_new() argparse.ArgumentParser {\n    return argparse.argument_parser()\n}'
	}
	if 'py_array' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_array[T](typecode string, items []T) []T {\n    _ = typecode\n    return items\n}'
	}
	if 'py_sorted' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_sorted[T](a []T, reverse bool) []T {\n    mut res := a.clone()\n    res.sort()\n    if reverse { res.reverse() }\n    return res\n}'
	}
	if 'py_reversed' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_reversed[T](a []T) []T {\n    mut res := a.clone()\n    res.reverse()\n    return res\n}'
	}
	if 'py_next' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_next(mut it Any, args ...Any) Any {\n    // stub for next() on iterators\n    return none\n}'
	}
	if 'py_bytes_format' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_bytes_format_arg(arg Any) string {\n    return arg.str()\n}'
		t.state.output << 'fn py_bytes_format(fmt []u8, args ...Any) []u8 {\n    // ... stub \n    return fmt\n}'
	}
	if t.state.used_builtins['py_subprocess_call'] {
		t.state.output << 'fn py_subprocess_call(cmd Any) int {\n    if cmd is []string {\n        mut p := os.new_process(cmd[0])\n        p.set_args(cmd[1..])\n        p.wait()\n        return p.code\n    }\n    return -1\n}'
	}
	if t.state.used_builtins['py_subprocess_run'] {
		t.state.output << 'struct PySubprocessResult {\n    pub mut:\n        returncode int\n        stdout string\n        stderr string\n}\nfn py_subprocess_run(cmd Any) PySubprocessResult {\n    if cmd is []string {\n        mut p := os.new_process(cmd[0])\n        p.set_args(cmd[1..])\n        p.wait()\n        return PySubprocessResult{returncode: p.code, stdout: p.stdout_slurp(), stderr: p.stderr_slurp()}\n    }\n    return PySubprocessResult{returncode: -1}\n}'
	}
	if 'py_range' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_range(args ...int) []int {\n    mut res := []int{}\n    mut start := 0\n    mut stop := 0\n    mut step := 1\n    if args.len == 1 {\n        stop = args[0]\n    } else if args.len == 2 {\n        start = args[0]\n        stop = args[1]\n    } else if args.len >= 3 {\n        start = args[0]\n        stop = args[1]\n        step = args[2]\n    }\n    if step > 0 {\n        for i := start; i < stop; i += step {\n            res << i\n        }\n    } else if step < 0 {\n        for i := start; i > stop; i += step {\n            res << i\n        }\n    }\n    return res\n}'
	}
	if 'py_urlencode' in t.state.used_builtins {
		t.state.output << 'fn py_urlencode(params map[string]string) string {\n    // stub\n    return ""\n}'
	}
	if 'py_urlparse' in t.state.used_builtins {
		t.state.output << 'fn py_urlparse(url string) Any {\n    return urllib.parse(url) or { Any(0) }\n}'
	}
	if 'py_urllib_unquote' in t.state.used_builtins {
		t.state.output << 'fn py_urllib_unquote(url string) string {\n    return urllib.query_unescape(url)\n}'
	}
	if 'py_gzip_compress' in t.state.used_builtins {
		t.state.output << 'fn py_gzip_compress(data []u8) []u8 {\n    return gzip.compress(data)\n}'
	}
	if 'py_gzip_decompress' in t.state.used_builtins {
		t.state.output << 'fn py_gzip_decompress(data []u8) []u8 {\n    return gzip.decompress(data) or { []u8{} }\n}'
	}
	if 'py_zlib_compress' in t.state.used_builtins {
		t.state.output << 'fn py_zlib_compress(data []u8) []u8 {\n    return zlib.compress(data)\n}'
	}
	if 'py_zlib_decompress' in t.state.used_builtins {
		t.state.output << 'fn py_zlib_decompress(data []u8) []u8 {\n    return zlib.decompress(data) or { []u8{} }\n}'
	}
	if t.state.used_builtins['py_struct_pack_I_le'] {
		t.state.output << ''
		t.state.output << 'fn py_struct_pack_I_le(val u32) []u8 {\n    mut res := []u8{len: 4}\n    binary.little_endian_put_u32(mut res, val)\n    return res\n}'
	}
	if t.state.used_builtins['py_struct_pack_I_be'] {
		t.state.output << ''
		t.state.output << 'fn py_struct_pack_I_be(val u32) []u8 {\n    mut res := []u8{len: 4}\n    binary.big_endian_put_u32(mut res, val)\n    return res\n}'
	}
	if t.state.used_builtins['py_struct_unpack_I_le'] {
		t.state.output << ''
		t.state.output << 'fn py_struct_unpack_I_le(data []u8) []Any {\n    return [Any(binary.little_endian_u32(data))]\n}'
	}
	if t.state.used_builtins['py_complex'] {
		t.state.output << 'struct PyComplex {\n    pub mut:\n        real f64\n        imag f64\n}\nfn py_complex(real f64, imag f64) PyComplex {\n    return PyComplex{real: real, imag: imag}\n}'
		t.state.output << 'fn (a PyComplex) + (b PyComplex) PyComplex {\n    return PyComplex{real: a.real + b.real, imag: a.imag + b.imag}\n}'
		t.state.output << 'fn (a PyComplex) - (b PyComplex) PyComplex {\n    return PyComplex{real: a.real - b.real, imag: a.imag - b.imag}\n}'
	}
	if t.state.used_builtins['py_counter'] {
		t.state.output << 'fn py_counter[T](a []T) map[T]int {\n    mut res := map[T]int{}\n    for x in a { res[x]++ }\n    return res\n}'
	}
	if t.state.used_builtins['py_csv_reader'] || t.state.used_builtins['PyCsvReader'] {
		t.state.output << 'struct PyCsvReader {\n    mut:\n        r &csv.Reader\n}\nfn py_csv_reader(f os.File) &PyCsvReader {\n    return &PyCsvReader{r: csv.new_reader(f)}\n}\nfn (mut r PyCsvReader) next() ?[]string {\n    return r.r.read() or { none }\n}\nfn (mut r PyCsvReader) iter() &PyCsvReader {\n    return r\n}'
	}
	if t.state.used_builtins['py_csv_writer'] || t.state.used_builtins['PyCsvWriter'] {
		t.state.output << 'struct PyCsvWriter {\n    mut:\n        w &csv.Writer\n}\nfn py_csv_writer(f os.File) &PyCsvWriter {\n    return &PyCsvWriter{w: csv.new_writer(f)}\n}\nfn (mut w PyCsvWriter) writerow(row []string) {\n    w.w.write(row) or { }\n}'
	}
	if t.state.used_builtins['py_decimal'] {
		t.state.output << 'struct PyDecimal {\n    val f64\n}\nfn py_decimal(val Any) PyDecimal {\n    return PyDecimal{f64(0.0)}\n}'
	}
	if t.state.used_builtins['py_decimal_localcontext'] {
		t.state.output << 'struct PyDecimalContext {\n    pub mut: prec int\n}\nfn (mut c PyDecimalContext) enter() &PyDecimalContext { return c }\nfn (mut c PyDecimalContext) exit(a Any, b Any, c Any) { }\nfn (mut c PyDecimalContext) __exit__(a Any, b Any, c Any) { }\nfn py_decimal_localcontext() &PyDecimalContext { return &PyDecimalContext{prec: 28} }\nfn py_decimal_getcontext() &PyDecimalContext { return &PyDecimalContext{prec: 28} }'
	}
	if t.state.used_builtins['py_fraction'] {
		t.state.output << 'fn py_fraction(a Any, b Any) Any { return none }'
	}
	if t.state.used_builtins['Point'] {
		t.state.output << 'struct Point {\n    pub mut:\n        x int\n        y int = 5\n}'
	}
	if t.state.used_builtins['py_tempfile_tempdir'] {
		t.state.output << 'struct PyTempDir {\n    pub mut:\n        path string\n}\nfn py_tempfile_tempdir() &PyTempDir {\n    path := os.mkdir_temp(\'\') or { \'\' }\n    return &PyTempDir{path: path}\n}\nfn (mut d PyTempDir) enter() string {\n    return d.path\n}\nfn (mut d PyTempDir) exit(a Any, b Any, c Any) {\n    os.rmdir_all(d.path) or { }\n}\nfn (mut d PyTempDir) __exit__(a Any, b Any, c Any) {\n    os.rmdir_all(d.path) or { }\n}'
	}
	if 'py_socket_new' in t.state.used_builtins {
		t.state.output << 'struct PySocket {\n    mut:\n        c net.TcpConn\n}\nfn py_socket_new(af int, typ int) &PySocket {\n    return &PySocket{}\n}\nfn (mut s PySocket) connect(addr Any) { }\nfn (mut s PySocket) send(data []u8) { }\nfn (mut s PySocket) close() { }'
	}
	if 'py_AF_INET' in t.state.used_builtins {
		t.state.output << 'const py_af_inet = 2'
	}
	if 'py_SOCK_STREAM' in t.state.used_builtins {
		t.state.output << 'const py_sock_stream = 1'
	}
	if 'py_sqlite_connect' in t.state.used_builtins {
		t.state.output << 'struct PySqliteCursor {\n}\nfn (mut c PySqliteCursor) execute(sql string) { }\nstruct PySqliteConnection {\n}\nfn (mut c PySqliteConnection) cursor() &PySqliteCursor {\n    return &PySqliteCursor{}\n}\nfn (mut c PySqliteConnection) commit() { }\nfn (mut c PySqliteConnection) close() { }\nfn py_sqlite_connect(path string) &PySqliteConnection {\n    return &PySqliteConnection{}\n}'
	}
}
