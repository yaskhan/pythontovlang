// I, Qwen Code, am working on this file. Started: 2026-03-22 20:00
// Information about Python operators (operators.py)

module mypy

// Map from binary operator id to related method name (in Python 3).
pub const op_methods = {
	'+':      '__add__'
	'-':      '__sub__'
	'*':      '__mul__'
	'/':      '__truediv__'
	'%':      '__mod__'
	'divmod': '__divmod__'
	'//':     '__floordiv__'
	'**':     '__pow__'
	'@':      '__matmul__'
	'&':      '__and__'
	'|':      '__or__'
	'^':      '__xor__'
	'<<':     '__lshift__'
	'>>':     '__rshift__'
	'==':     '__eq__'
	'!=':     '__ne__'
	'<':      '__lt__'
	'>=':     '__ge__'
	'>':      '__gt__'
	'<=':     '__le__'
	'in':     '__contains__'
}

// Reverse map: method name to operator symbol
pub const op_methods_to_symbols = {
	'__add__':      '+'
	'__sub__':      '-'
	'__mul__':      '*'
	'__truediv__':  '/'
	'__mod__':      '%'
	'__divmod__':   'divmod'
	'__floordiv__': '//'
	'__pow__':      '**'
	'__matmul__':   '@'
	'__and__':      '&'
	'__or__':       '|'
	'__xor__':      '^'
	'__lshift__':   '<<'
	'__rshift__':   '>>'
	'__eq__':       '=='
	'__ne__':       '!='
	'__lt__':       '<'
	'__ge__':       '>='
	'__gt__':       '>'
	'__le__':       '<='
	'__contains__': 'in'
}

// Operators that fall back to __cmp__
pub const ops_falling_back_to_cmp = ['__ne__', '__eq__', '__lt__', '__le__', '__gt__', '__ge__']

// Operators with inplace methods
pub const ops_with_inplace_method = ['+', '-', '*', '/', '%', '//', '**', '@', '&', '|', '^', '<<',
	'>>']

// Inplace operator methods
pub const inplace_operator_methods = {
	'+':  '__iadd__'
	'-':  '__isub__'
	'*':  '__imul__'
	'/':  '__itruediv__'
	'%':  '__imod__'
	'//': '__ifloordiv__'
	'**': '__ipow__'
	'@':  '__imatmul__'
	'&':  '__iand__'
	'|':  '__ior__'
	'^':  '__ixor__'
	'<<': '__ilshift__'
	'>>': '__irshift__'
}

// Reverse operator methods
pub const reverse_op_methods = {
	'__add__':      '__radd__'
	'__sub__':      '__rsub__'
	'__mul__':      '__rmul__'
	'__truediv__':  '__rtruediv__'
	'__mod__':      '__rmod__'
	'__divmod__':   '__rdivmod__'
	'__floordiv__': '__rfloordiv__'
	'__pow__':      '__rpow__'
	'__matmul__':   '__rmatmul__'
	'__and__':      '__rand__'
	'__or__':       '__ror__'
	'__xor__':      '__rxor__'
	'__lshift__':   '__rlshift__'
	'__rshift__':   '__rrshift__'
	'__eq__':       '__eq__'
	'__ne__':       '__ne__'
	'__lt__':       '__gt__'
	'__ge__':       '__le__'
	'__gt__':       '__lt__'
	'__le__':       '__ge__'
}

// Reverse op method names set
pub const reverse_op_method_names = ['__radd__', '__rsub__', '__rmul__', '__rtruediv__', '__rmod__',
	'__rdivmod__', '__rfloordiv__', '__rpow__', '__rmatmul__', '__rand__', '__ror__', '__rxor__',
	'__rlshift__', '__rrshift__', '__eq__', '__ne__', '__gt__', '__le__', '__lt__', '__ge__']

// Op methods that shortcut (skip __r*__ when both operands are same type)
pub const op_methods_that_shortcut = ['__add__', '__sub__', '__mul__', '__truediv__', '__mod__',
	'__divmod__', '__floordiv__', '__pow__', '__matmul__', '__and__', '__or__', '__xor__',
	'__lshift__', '__rshift__']

// Normal from reverse op
pub const normal_from_reverse_op = {
	'__radd__':      '__add__'
	'__rsub__':      '__sub__'
	'__rmul__':      '__mul__'
	'__rtruediv__':  '__truediv__'
	'__rmod__':      '__mod__'
	'__rdivmod__':   '__divmod__'
	'__rfloordiv__': '__floordiv__'
	'__rpow__':      '__pow__'
	'__rmatmul__':   '__matmul__'
	'__rand__':      '__and__'
	'__ror__':       '__or__'
	'__rxor__':      '__xor__'
	'__rlshift__':   '__lshift__'
	'__rrshift__':   '__rshift__'
	'__gt__':        '__lt__'
	'__le__':        '__ge__'
	'__lt__':        '__gt__'
	'__ge__':        '__le__'
}

// Reverse op method set
pub const reverse_op_method_set = ['__radd__', '__rsub__', '__rmul__', '__rtruediv__', '__rmod__',
	'__rdivmod__', '__rfloordiv__', '__rpow__', '__rmatmul__', '__rand__', '__ror__', '__rxor__',
	'__rlshift__', '__rrshift__', '__eq__', '__ne__', '__gt__', '__le__', '__lt__', '__ge__']

// Unary operator methods
pub const unary_op_methods = {
	'-': '__neg__'
	'+': '__pos__'
	'~': '__invert__'
}

// Integer comparison methods (simplified for V)
pub const int_op_to_method = {
	'==':     '__eq__'
	'is':     '__eq__'
	'<':      '__lt__'
	'<=':     '__le__'
	'!=':     '__ne__'
	'is not': '__ne__'
	'>':      '__gt__'
	'>=':     '__ge__'
}

// Flip comparison operators
pub const flip_ops = {
	'<':  '>'
	'<=': '>='
	'>':  '<'
	'>=': '<='
}

// Negate comparison operators
pub const neg_ops = {
	'==':     '!='
	'!=':     '=='
	'is':     'is not'
	'is not': 'is'
	'<':      '>='
	'<=':     '>'
	'>':      '<='
	'>=':     '<'
}

// Comparison operators
pub const comparison_ops = ['==', '!=', '<', '<=', '>', '>=', 'is', 'is not', 'in', 'not in']

// Get the method name for an operator
pub fn op_to_method(op string) string {
	return op_methods[op] or { '' }
}

// Get the reverse operator method
pub fn reverse_op_method(op_method string) string {
	return reverse_op_methods[op_method] or { op_method }
}

// Check if an operator has an inplace method
pub fn has_inplace_method(op string) bool {
	return op in ops_with_inplace_method
}

// Get the inplace method for an operator
pub fn inplace_method(op string) string {
	return inplace_operator_methods[op] or { '' }
}

// Check if an operator is a comparison operator
pub fn is_comparison_op(op string) bool {
	return op in comparison_ops
}

// Check if an operator method shortcuts (skips reverse)
pub fn op_method_shortcuts(op_method string) bool {
	return op_method in op_methods_that_shortcut
}
