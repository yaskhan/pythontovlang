// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 10:48
module mypy

// Основной алгоритм проверки вхождения одного типа в другой (Подтип-Супертип).
// Liskov Substitution Principle: Если S подтип T, то функция принимающая T может безопасно принимать S.

pub struct SubtypeContext {
pub mut:
	ignore_type_params bool
	ignore_pos_args    bool
	ignore_declared_variance bool
	ignore_promotions  bool
	is_coercion        bool // Для Any/TypeVar fallback heuristics
}

pub fn is_same_type(left MypyTypeNode, right MypyTypeNode) bool {
	// 
	p_left := get_proper_type(left)
	p_right := get_proper_type(right)
	
	if p_left is Instance && p_right is Instance {
		il := p_left as Instance
		ir := p_right as Instance
		return il.type_name == ir.type_name && il.args.len == ir.args.len
	}
	if p_left is AnyType && p_right is AnyType {
		return true
	}
	// TODO: implement full structural equality
	return false
}

// is_subtype - Проверяет, является ли 'left' подтипом для 'right'.
pub fn is_subtype(left MypyTypeNode, right MypyTypeNode, ctx SubtypeContext) bool {
	p_left := get_proper_type(left)
	p_right := get_proper_type(right)
	
	if is_same_type(p_left, p_right) {
		return true // Любой тип является своим подтипом
	}
	
	// Если правый - Any, то всё что угодно можно подставить (с учетом флагов).
	if p_right is AnyType {
		return true
	}
	
	// Если мы ожидаем Any или left = Any, обычно это true, но Any не является строгим подтипом.
	// Для практических целей (как в mypy):
	if p_left is AnyType {
		return true 
	}
	
	mut visitor := SubtypeVisitor{
		right: p_right
		ctx:   ctx
	}
	
	return accept_subtype(p_left, mut visitor)
}

pub struct SubtypeVisitor {
pub mut:
	right MypyTypeNode
	ctx   SubtypeContext
}

fn accept_subtype(left MypyTypeNode, mut v SubtypeVisitor) bool {
	// Двойная диспетчеризация (pattern match)
	match left {
		Instance { return v.visit_instance(left) }
		AnyType { return true }
		NoneType { return v.visit_none_type(left) }
		TupleType { return v.visit_tuple_type(left) }
		UnionType { return v.visit_union_type(left) }
		CallableType { return v.visit_callable_type(left) }
		UninhabitedType { return true } // Uninhabited - нижний тип, является подтипом всего
		else {
			// fallback
			return false
		}
	}
}

pub fn (mut v SubtypeVisitor) visit_instance(left &Instance) bool {
	right := v.right
	if right is Instance {
		r_inst := right as Instance
		// 1. Проверяем "номинальное" наследование (class hierarchy)
		if left.typ == none || r_inst.typ == none { return false }
		
		val := left.typ or { return false }
		r_val := r_inst.typ or { return false }
		
		if val.fullname == 'builtins.object' && r_val.fullname != 'builtins.object' {
			return false
		}
		
		if r_val.fullname == 'builtins.object' {
			return true // Всё наследуется от object (на уровне Instance)
		}
		
		// 2. Ищет r_val в MRO (Method Resolution Order) у left
		mut found := false
		for base in val.mro {
			if base.fullname == r_val.fullname {
				found = true
				break
			}
		}
		
		if !found {
			// Специальные правила для Promotions (int -> float -> complex)
			// и Tuple/NamedTuple если нужно.
			return false
		}
		
		// 3. Если ignore_type_params == true, то List[int] is subtype of List. Успех.
		if v.ctx.ignore_type_params {
			return true
		}
		
		// 4. Проверка аргументов типов (Type arguments). MapInstanceToSupertype
		// ... мы вызываем map_instance_to_supertype из maptype.v
		// Для каждого аргумента из right мы проверяем вариантность.
		return true
	} else if right is AnyType {
		return true
	} else if right is UnionType {
		// Instance is subtype of Union if it is subtype of AT LEAST ONE of its members
		mut is_match := false
		for item in (right as UnionType).items {
			if is_subtype(MypyTypeNode(left), item, v.ctx) {
				is_match = true
				break
			}
		}
		return is_match
	}
	
	return false
}

pub fn (mut v SubtypeVisitor) visit_none_type(left &NoneType) bool {
	// В зависимости от флага strict_optional, None является подтипом object и всего остального (или нет).
	// Если strict_optional on: None подтип только None и Optional[T] (Union[T, None]).
	right := v.right
	if right is NoneType {
		return true
	} else if right is Instance {
		if (right as Instance).typ?.fullname == 'builtins.object' {
			return true // None in python 3 is object implicitly
		}
		// Обычно NoneType is NOT subtype of Instance(Int) without Union, unless strict_optional=false
	} else if right is UnionType {
		for item in (right as UnionType).items {
			if is_subtype(MypyTypeNode(left), item, v.ctx) {
				return true
			}
		}
	}
	return false
}

pub fn (mut v SubtypeVisitor) visit_union_type(left &UnionType) bool {
	// Union[A, B] является подтипом T ТОЛЬКО ЕСЛИ A подтип T И B подтип T.
	for item in left.items {
		if !is_subtype(item, v.right, v.ctx) {
			return false
		}
	}
	return true
}

pub fn (mut v SubtypeVisitor) visit_tuple_type(left &TupleType) bool {
	right := v.right
	if right is TupleType {
		r_tuple := right as TupleType
		if left.items.len != r_tuple.items.len {
			return false
		}
		for i, l_item in left.items {
			r_item := r_tuple.items[i]
			if !is_subtype(l_item, r_item, v.ctx) {
				return false
			}
		}
		return true
	} else if right is Instance {
		// Tuple[X, Y] is subtype of Sequence[X] or object
		r_inst := right as Instance
		if r_inst.typ != none { // safe navigation fallback
			if r_inst.typ?.fullname == 'builtins.object' || r_inst.typ?.fullname == 'typing.Sequence' {
				return true
			}
		}
	} else if right is UnionType {
		for item in (right as UnionType).items {
			if is_subtype(MypyTypeNode(left), item, v.ctx) {
				return true
			}
		}
	}
	return false
}

pub fn (mut v SubtypeVisitor) visit_callable_type(left &CallableType) bool {
	right := v.right
	if right is CallableType {
		r_call := right as CallableType
		// Functions are CONTRAVARIANT in their arguments and COVARIANT in their return type.
		// Meaning A -> B is subtype of C -> D if:
		// C is subtype of A (ты можешь дать ему более широкие аргументы)
		// B is subtype of D (он возвращает более узкий результат)
		
		if !is_subtype(left.ret_type, r_call.ret_type, v.ctx) {
			return false
		}
		
		// Для аргументов (упрощено):
		if left.arg_types.len != r_call.arg_types.len {
			return false // Реально еще проверяются *args, **kwargs
		}
		
		for i in 0 .. left.arg_types.len {
			l_arg := left.arg_types[i] or { continue }
			r_arg := r_call.arg_types[i] or { continue }
			// Contravariance!
			if !is_subtype(r_arg, l_arg, v.ctx) {
				return false
			}
		}
		return true
	} else if right is Instance {
		if (right as Instance).typ?.fullname == 'builtins.object' { return true }
		if (right as Instance).typ?.fullname == 'typing.Callable' { return true }
	}
	return false
}
