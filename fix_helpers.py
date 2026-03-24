import sys

with open('py2v_transpiler/core/translator/module.py', 'r') as f:
    content = f.read()

# Fix py_format
content = content.replace(
    '        formatted = strconv.format_f64(val, `f`, prec, 64)',
    '        formatted = strconv.format_f64(val, typ.to_lower(), prec, 64)\n        if typ.is_upper() { formatted = formatted.to_upper() }'
)

# Fix py_string_format float part
float_old = """                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        prec := if precision >= 0 { precision } else { 6 }
                        if arg is f64 {
                            s_val = strconv.format_f64(arg, `f`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else if arg is int {
                            s_val = strconv.format_f64(f64(arg), `f`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else if arg is i64 {
                            s_val = strconv.format_f64(f64(arg), `f`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else {
                            val_f := '${arg}'.f64()
                            s_val = strconv.format_f64(val_f, `f`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        }"""

float_new = """                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        prec := if precision >= 0 { precision } else { 6 }
                        mut f_val := 0.0
                        if arg is f64 { f_val = arg }
                        else if arg is int { f_val = f64(arg) }
                        else if arg is i64 { f_val = f64(arg) }
                        else { f_val = '${arg}'.f64() }
                        s_val = strconv.format_f64(f_val, `f`, prec, 64)
                        if spec == `F` { s_val = s_val.to_upper() }"""

content = content.replace(float_old, float_new)

# Fix py_string_format exp part
exp_old = """                    } else if spec == `e` || spec == `E` {
                        prec := if precision >= 0 { precision } else { 6 }
                        if arg is f64 {
                            s_val = strconv.format_f64(arg, `e`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else if arg is int {
                            s_val = strconv.format_f64(f64(arg), `e`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else if arg is i64 {
                            s_val = strconv.format_f64(f64(arg), `e`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        } else {
                            val_f := '${arg}'.f64()
                            s_val = strconv.format_f64(val_f, `e`, prec, 64).to_upper() if spec == `F` else strconv.format_f64(arg, `f`, prec, 64))
                        }"""

exp_new = """                    } else if spec == `e` || spec == `E` {
                        prec := if precision >= 0 { precision } else { 6 }
                        mut f_val := 0.0
                        if arg is f64 { f_val = arg }
                        else if arg is int { f_val = f64(arg) }
                        else if arg is i64 { f_val = f64(arg) }
                        else { f_val = '${arg}'.f64() }
                        s_val = strconv.format_f64(f_val, `e`, prec, 64)
                        if spec == `E` { s_val = s_val.to_upper() }"""

content = content.replace(exp_old, exp_new)

with open('py2v_transpiler/core/translator/module.py', 'w') as f:
    f.write(content)
