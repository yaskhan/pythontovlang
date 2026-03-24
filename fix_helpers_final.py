import sys

with open('py2v_transpiler/core/translator/module.py', 'r') as f:
    content = f.read()

# Fix py_format if still wrong
content = content.replace(
    '        if typ == `g` || typ == `G` { return val.str() }',
    '        if typ == `g` || typ == `G` { return val.str() }'
)

# Fix py_string_format float part (ensuring no trailing ))
float_old = """                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        prec := if precision >= 0 { precision } else { 6 }
                        mut f_val := 0.0
                        if arg is f64 { f_val = arg }
                        else if arg is int { f_val = f64(arg) }
                        else if arg is i64 { f_val = f64(arg) }
                        else { f_val = '${arg}'.f64() }
                        s_val = strconv.format_f64(f_val, `f`, prec, 64)
                        if spec == `F` { s_val = s_val.to_upper() }"""

# Wait, check for the extra parenthesis in current file
if 'strconv.format_f64(arg, `f`, prec, 64))' in content:
     print("Found extra parenthesis, fixing...")
     content = content.replace('strconv.format_f64(arg, `f`, prec, 64))', 'strconv.format_f64(arg, `f`, prec, 64)')
if 'strconv.format_f64(f64(arg), `f`, prec, 64))' in content:
     content = content.replace('strconv.format_f64(f64(arg), `f`, prec, 64))', 'strconv.format_f64(f64(arg), `f`, prec, 64)')
if 'strconv.format_f64(val_f, `f`, prec, 64))' in content:
     content = content.replace('strconv.format_f64(val_f, `f`, prec, 64))', 'strconv.format_f64(val_f, `f`, prec, 64)')
if 'strconv.format_f64(arg, `e`, prec, 64))' in content:
     content = content.replace('strconv.format_f64(arg, `e`, prec, 64))', 'strconv.format_f64(arg, `e`, prec, 64)')

with open('py2v_transpiler/core/translator/module.py', 'w') as f:
    f.write(content)
