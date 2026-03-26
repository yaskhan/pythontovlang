module analyzer

import ast

fn expr_name(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.Attribute {
			base := expr_name(node.value)
			if base.len > 0 {
				'${base}.${node.attr}'
			} else {
				node.attr
			}
		}
		ast.Subscript { expr_name(node.value) }
		else { '' }
	}
}

fn call_name(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.Attribute { node.attr }
		else { '' }
	}
}

fn add_unique(mut items []string, value string) {
	if value.len == 0 {
		return
	}
	if value !in items {
		items << value
	}
}

fn add_unique_int(mut items []int, value int) {
	if value !in items {
		items << value
	}
}

fn is_mutating_method(name string) bool {
	return name in ['append', 'extend', 'insert', 'pop', 'remove', 'clear', 'update',
		'setdefault', 'delete', 'add', 'discard']
}

fn collect_stmt_children(stmt ast.Statement) []ast.Statement {
	return match stmt {
		ast.If { mut children := []ast.Statement{}; children << stmt.body; children << stmt.orelse; children }
		ast.While { mut children := []ast.Statement{}; children << stmt.body; children << stmt.orelse; children }
		ast.For { mut children := []ast.Statement{}; children << stmt.body; children << stmt.orelse; children }
		ast.With { stmt.body.clone() }
		ast.Try { mut children := []ast.Statement{}; children << stmt.body; for handler in stmt.handlers { children << handler.body }; children << stmt.orelse; children << stmt.finalbody; children }
		ast.TryStar { mut children := []ast.Statement{}; children << stmt.body; for handler in stmt.handlers { children << handler.body }; children << stmt.orelse; children << stmt.finalbody; children }
		ast.Match { mut children := []ast.Statement{}; for case in stmt.cases { children << case.body }; children }
		ast.FunctionDef { stmt.body.clone() }
		ast.ClassDef { stmt.body.clone() }
		else { []ast.Statement{} }
	}
}

fn collect_expr_children(expr ast.Expression) []ast.Expression {
	return match expr {
		ast.List { expr.elements.clone() }
		ast.Tuple { expr.elements.clone() }
		ast.Set { expr.elements.clone() }
		ast.Dict {
			mut children := []ast.Expression{}
			for key in expr.keys {
				if key !is ast.NoneExpr {
					children << key
				}
			}
			children << expr.values
			children
		}
		ast.BinaryOp { [expr.left, expr.right] }
		ast.UnaryOp { [expr.operand] }
		ast.Compare {
			mut children := []ast.Expression{}
			children << expr.left
			children << expr.comparators
			children
		}
		ast.Call {
			mut children := []ast.Expression{}
			children << expr.func
			children << expr.args
			for kw in expr.keywords {
				children << kw.value
			}
			children
		}
		ast.Attribute { [expr.value] }
		ast.Subscript { [expr.value, expr.slice] }
		ast.Slice {
			mut children := []ast.Expression{}
			if lower := expr.lower {
				children << lower
			}
			if upper := expr.upper {
				children << upper
			}
			if step := expr.step {
				children << step
			}
			children
		}
		ast.Lambda {
			mut children := []ast.Expression{}
			children << expr.body
			for param in expr.args.posonlyargs {
				if annotation := param.annotation {
					children << annotation
				}
				if default_ := param.default_ {
					children << default_
				}
			}
			for param in expr.args.args {
				if annotation := param.annotation {
					children << annotation
				}
				if default_ := param.default_ {
					children << default_
				}
			}
			for param in expr.args.kwonlyargs {
				if annotation := param.annotation {
					children << annotation
				}
				if default_ := param.default_ {
					children << default_
				}
			}
			if vararg := expr.args.vararg {
				if annotation := vararg.annotation {
					children << annotation
				}
			}
			if kwarg := expr.args.kwarg {
				if annotation := kwarg.annotation {
					children << annotation
				}
			}
			children
		}
		ast.ListComp { [expr.elt] }
		ast.DictComp { [expr.key, expr.value] }
		ast.SetComp { [expr.elt] }
		ast.GeneratorExp { [expr.elt] }
		ast.IfExp { [expr.test, expr.body, expr.orelse] }
		ast.Await { [expr.value] }
		ast.Yield {
			mut children := []ast.Expression{}
			if value := expr.value {
				children << value
			}
			children
		}
		ast.YieldFrom { [expr.value] }
		ast.Starred { [expr.value] }
		ast.JoinedStr { expr.values.clone() }
		ast.FormattedValue {
			mut children := []ast.Expression{}
			children << expr.value
			if format_spec := expr.format_spec {
				children << format_spec
			}
			children
		}
		ast.NamedExpr { [expr.target, expr.value] }
		else { []ast.Expression{} }
	}
}

pub struct AliasInferer {
pub mut:
	alias_to_type map[string]string
}

pub fn new_alias_inferer() AliasInferer {
	return AliasInferer{
		alias_to_type: map[string]string{}
	}
}

fn (mut a AliasInferer) collect_aliases_stmt(stmt ast.Statement, mut aliases map[string]string, mut instantiations map[string]string, mut appends map[string][]string) {
	match stmt {
		ast.Assign {
			if stmt.targets.len == 1 {
				target := stmt.targets[0]
				if target is ast.Name {
					target_name := target.id
					if stmt.value is ast.Name {
						rhs_name := stmt.value.id
						if rhs_name in ['list', 'set', 'dict', 'List', 'Set', 'Dict'] {
							aliases[target_name] = rhs_name.to_lower()
						}
					}
					if stmt.value is ast.Call {
						call := stmt.value
						if call.func is ast.Name {
							func_name := call.func.id
							if func_name in aliases {
								instantiations[target_name] = func_name
							}
						}
						if call.func is ast.Attribute {
							attr := call.func
							if attr.attr == 'append' && attr.value is ast.Name && call.args.len == 1 {
								var_name := attr.value.id
								arg := call.args[0]
								if arg is ast.Call {
									inner_call := arg
									if inner_call.func is ast.Name {
										appended_type := inner_call.func.id
										mut current := appends[var_name] or { []string{} }
										add_unique(mut current, appended_type)
										appends[var_name] = current
									}
								}
							}
						}
					}
				}
			}
		}
		else {}
	}
	for child in collect_stmt_children(stmt) {
		a.collect_aliases_stmt(child, mut aliases, mut instantiations, mut appends)
	}
	if stmt is ast.Expr {
		a.collect_aliases_expr(stmt.value, mut aliases, mut instantiations, mut appends)
	} else if stmt is ast.Return {
		if value := stmt.value {
			a.collect_aliases_expr(value, mut aliases, mut instantiations, mut appends)
		}
	} else if stmt is ast.Assert {
		a.collect_aliases_expr(stmt.test, mut aliases, mut instantiations, mut appends)
		if msg := stmt.msg {
			a.collect_aliases_expr(msg, mut aliases, mut instantiations, mut appends)
		}
	} else if stmt is ast.Raise {
		if exc := stmt.exc {
			a.collect_aliases_expr(exc, mut aliases, mut instantiations, mut appends)
		}
		if cause := stmt.cause {
			a.collect_aliases_expr(cause, mut aliases, mut instantiations, mut appends)
		}
	} else if stmt is ast.Global || stmt is ast.Nonlocal || stmt is ast.Pass || stmt is ast.Break || stmt is ast.Continue {
	}
}

fn (mut a AliasInferer) collect_aliases_expr(expr ast.Expression, mut aliases map[string]string, mut instantiations map[string]string, mut appends map[string][]string) {
	match expr {
		ast.Call {
			if expr.func is ast.Attribute {
				attr := expr.func
				if attr.attr == 'append' && attr.value is ast.Name && expr.args.len == 1 {
					var_name := attr.value.id
					arg := expr.args[0]
					if arg is ast.Call {
						inner_call := arg
						if inner_call.func is ast.Name {
							appended_type := inner_call.func.id
							mut current := appends[var_name] or { []string{} }
							add_unique(mut current, appended_type)
							appends[var_name] = current
						}
					}
				}
			}
			for arg in expr.args {
				a.collect_aliases_expr(arg, mut aliases, mut instantiations, mut appends)
			}
			for kw in expr.keywords {
				a.collect_aliases_expr(kw.value, mut aliases, mut instantiations, mut appends)
			}
			a.collect_aliases_expr(expr.func, mut aliases, mut instantiations, mut appends)
		}
		ast.List {
			for elt in expr.elements {
				a.collect_aliases_expr(elt, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.Tuple {
			for elt in expr.elements {
				a.collect_aliases_expr(elt, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.Set {
			for elt in expr.elements {
				a.collect_aliases_expr(elt, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.Dict {
			for key in expr.keys {
				if key !is ast.NoneExpr {
					a.collect_aliases_expr(key, mut aliases, mut instantiations, mut appends)
				}
			}
			for value in expr.values {
				a.collect_aliases_expr(value, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.BinaryOp {
			a.collect_aliases_expr(expr.left, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.right, mut aliases, mut instantiations, mut appends)
		}
		ast.UnaryOp { a.collect_aliases_expr(expr.operand, mut aliases, mut instantiations, mut appends) }
		ast.Compare {
			a.collect_aliases_expr(expr.left, mut aliases, mut instantiations, mut appends)
			for comp in expr.comparators {
				a.collect_aliases_expr(comp, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.Attribute { a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends) }
		ast.Subscript {
			a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.slice, mut aliases, mut instantiations, mut appends)
		}
		ast.Slice {
			if lower := expr.lower {
				a.collect_aliases_expr(lower, mut aliases, mut instantiations, mut appends)
			}
			if upper := expr.upper {
				a.collect_aliases_expr(upper, mut aliases, mut instantiations, mut appends)
			}
			if step := expr.step {
				a.collect_aliases_expr(step, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.Lambda {
			a.collect_aliases_expr(expr.body, mut aliases, mut instantiations, mut appends)
		}
		ast.ListComp {
			a.collect_aliases_expr(expr.elt, mut aliases, mut instantiations, mut appends)
		}
		ast.DictComp {
			a.collect_aliases_expr(expr.key, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends)
		}
		ast.SetComp {
			a.collect_aliases_expr(expr.elt, mut aliases, mut instantiations, mut appends)
		}
		ast.GeneratorExp {
			a.collect_aliases_expr(expr.elt, mut aliases, mut instantiations, mut appends)
		}
		ast.IfExp {
			a.collect_aliases_expr(expr.test, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.body, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.orelse, mut aliases, mut instantiations, mut appends)
		}
		ast.Await { a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends) }
		ast.Yield {
			if value := expr.value {
				a.collect_aliases_expr(value, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.YieldFrom { a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends) }
		ast.Starred { a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends) }
		ast.JoinedStr {
			for value in expr.values {
				a.collect_aliases_expr(value, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.FormattedValue {
			a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends)
			if format_spec := expr.format_spec {
				a.collect_aliases_expr(format_spec, mut aliases, mut instantiations, mut appends)
			}
		}
		ast.NamedExpr {
			a.collect_aliases_expr(expr.target, mut aliases, mut instantiations, mut appends)
			a.collect_aliases_expr(expr.value, mut aliases, mut instantiations, mut appends)
		}
		else {}
	}
}

pub fn (mut a AliasInferer) analyze(tree ast.Module) {
	mut aliases := map[string]string{}
	mut instantiations := map[string]string{}
	mut appends := map[string][]string{}
	for stmt in tree.body {
		a.collect_aliases_stmt(stmt, mut aliases, mut instantiations, mut appends)
	}

	mut alias_usages := map[string][]string{}
	for alias in aliases.keys() {
		alias_usages[alias] = []string{}
	}

	for var_name, func_name in instantiations {
		if func_name in aliases {
			mut used := alias_usages[func_name] or { []string{} }
			for t in appends[var_name] or { []string{} } {
				add_unique(mut used, t)
			}
			alias_usages[func_name] = used
		}
	}

	for alias, base_type in aliases {
		used_types := alias_usages[alias] or { []string{} }
		if used_types.len == 0 {
			if base_type == 'list' {
				a.alias_to_type[alias] = '[]Any'
			} else if base_type == 'set' {
				a.alias_to_type[alias] = 'datatypes.Set[string]'
			} else if base_type == 'dict' {
				a.alias_to_type[alias] = 'map[string]Any'
			} else {
				a.alias_to_type[alias] = 'Any'
			}
		} else if used_types.len == 1 {
			inner_type := used_types[0]
			if base_type == 'list' {
				a.alias_to_type[alias] = '[]${inner_type}'
			} else if base_type == 'set' {
				a.alias_to_type[alias] = 'datatypes.Set[${inner_type}]'
			} else {
				a.alias_to_type[alias] = 'map[int]${inner_type}'
			}
		} else {
			if base_type == 'list' {
				a.alias_to_type[alias] = '[]Any'
			} else if base_type == 'set' {
				a.alias_to_type[alias] = 'datatypes.Set[string]'
			} else {
				a.alias_to_type[alias] = 'map[int]Any'
			}
		}
	}
}

pub fn (a &AliasInferer) get_type(alias string) string {
	return a.alias_to_type[alias] or { '' }
}

pub struct MixinInferer {
pub mut:
	mixin_to_main   map[string][]string
	main_to_mixins   map[string][]string
	mixin_nodes     map[string]string
	class_hierarchy map[string][]string
	is_abc          map[string]bool
	static_methods  map[string][]string
	class_methods   map[string][]string
}

pub fn new_mixin_inferer() MixinInferer {
	return MixinInferer{
		mixin_to_main:   map[string][]string{}
		main_to_mixins:   map[string][]string{}
		mixin_nodes:     map[string]string{}
		class_hierarchy: map[string][]string{}
		is_abc:          map[string]bool{}
		static_methods:  map[string][]string{}
		class_methods:   map[string][]string{}
	}
}

fn (m &MixinInferer) get_all_ancestors(cls_name string) []string {
	mut result := []string{}
	mut visited := map[string]bool{}
	mut queue := m.class_hierarchy[cls_name] or { []string{} }
	mut i := 0
	for i < queue.len {
		curr := queue[i]
		i++
		if curr !in visited {
			visited[curr] = true
			result << curr
			queue << m.class_hierarchy[curr] or { []string{} }
		}
	}
	return result
}

fn expr_to_class_name(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.Attribute { node.attr }
		ast.Subscript { expr_to_class_name(node.value) }
		ast.Call { expr_to_class_name(node.func) }
		else { '' }
	}
}

fn (mut m MixinInferer) collect_class_info(stmt ast.Statement) {
	match stmt {
		ast.ClassDef {
			m.mixin_nodes[stmt.name] = stmt.name
			m.is_abc[stmt.name] = false
			m.static_methods[stmt.name] = []string{}
			m.class_methods[stmt.name] = []string{}

			mut bases := []string{}
			for base in stmt.bases {
				base_name := expr_to_class_name(base)
				if base_name.len > 0 {
					bases << base_name
				}
			}
			m.class_hierarchy[stmt.name] = bases

			for child in stmt.body {
				if child is ast.FunctionDef {
					mut decorator_names := []string{}
					for decorator in child.decorator_list {
						name := expr_to_class_name(decorator)
						if name.len > 0 {
							decorator_names << name
						}
					}
					if 'staticmethod' in decorator_names {
						mut current := m.static_methods[stmt.name] or { []string{} }
						add_unique(mut current, child.name)
						m.static_methods[stmt.name] = current
					}
					if 'classmethod' in decorator_names {
						mut current := m.class_methods[stmt.name] or { []string{} }
						add_unique(mut current, child.name)
						m.class_methods[stmt.name] = current
					}
				}
			}
			for child in stmt.body {
				m.collect_class_info(child)
			}
		}
		ast.If {
			for child in stmt.body {
				m.collect_class_info(child)
			}
			for child in stmt.orelse {
				m.collect_class_info(child)
			}
		}
		ast.For {
			for child in stmt.body {
				m.collect_class_info(child)
			}
			for child in stmt.orelse {
				m.collect_class_info(child)
			}
		}
		ast.While {
			for child in stmt.body {
				m.collect_class_info(child)
			}
			for child in stmt.orelse {
				m.collect_class_info(child)
			}
		}
		ast.With {
			for child in stmt.body {
				m.collect_class_info(child)
			}
		}
		ast.Try {
			for child in stmt.body {
				m.collect_class_info(child)
			}
			for handler in stmt.handlers {
				for child in handler.body {
					m.collect_class_info(child)
				}
			}
			for child in stmt.orelse {
				m.collect_class_info(child)
			}
			for child in stmt.finalbody {
				m.collect_class_info(child)
			}
		}
		ast.TryStar {
			for child in stmt.body {
				m.collect_class_info(child)
			}
			for handler in stmt.handlers {
				for child in handler.body {
					m.collect_class_info(child)
				}
			}
			for child in stmt.orelse {
				m.collect_class_info(child)
			}
			for child in stmt.finalbody {
				m.collect_class_info(child)
			}
		}
		ast.Match {
			for case in stmt.cases {
				for child in case.body {
					m.collect_class_info(child)
				}
			}
		}
		ast.FunctionDef {
			for child in stmt.body {
				m.collect_class_info(child)
			}
		}
		else {}
	}
}

pub fn (mut m MixinInferer) analyze(tree ast.Module) {
	for stmt in tree.body {
		m.collect_class_info(stmt)
	}

	mut explicit_abcs := map[string]bool{}
	mut mixin_templates := map[string]bool{}

	for cls_name in m.mixin_nodes.keys() {
		bases := m.class_hierarchy[cls_name] or { []string{} }
		mut has_abstract := false
		mut has_concrete := false
		for stmt in tree.body {
			if stmt is ast.ClassDef && stmt.name == cls_name {
				for child in stmt.body {
					if child is ast.FunctionDef {
						mut is_abstract_stmt := false
						for dec in child.decorator_list {
							if dec is ast.Name && (dec as ast.Name).id == 'abstractmethod' {
								has_abstract = true
								is_abstract_stmt = true
							}
							if dec is ast.Attribute && (dec as ast.Attribute).attr == 'abstractmethod' {
								has_abstract = true
								is_abstract_stmt = true
							}
						}
						if !is_abstract_stmt {
							has_concrete = true
						}
					}
				}
			}
		}
		if has_abstract || 'ABC' in bases {
			explicit_abcs[cls_name] = true
		}
		_ = has_concrete
		if cls_name.ends_with('Mixin') {
			mixin_templates[cls_name] = true
		}
	}

	mut changed := true
	for changed {
		changed = false
		for cls_name in m.class_hierarchy.keys() {
			if cls_name in explicit_abcs {
				continue
			}
			ancestors := m.get_all_ancestors(cls_name)
			mut inherited_abc := false
			for ancestor in ancestors {
				if ancestor in explicit_abcs {
					inherited_abc = true
					break
				}
			}
			if inherited_abc {
				mut is_inherited := false
				for _, b_list in m.class_hierarchy {
					if cls_name in b_list {
						is_inherited = true
						break
					}
				}
				mut node_has_concrete := false
				for stmt in tree.body {
					if stmt is ast.ClassDef && stmt.name == cls_name {
						for child in stmt.body {
							if child is ast.FunctionDef {
								node_has_concrete = true
								break
							}
						}
					}
				}
				if is_inherited || !node_has_concrete {
					explicit_abcs[cls_name] = true
					changed = true
				}
			}
		}
	}

	for cls_name in m.class_hierarchy.keys() {
		m.is_abc[cls_name] = cls_name in explicit_abcs
	}

	mut templates := map[string]bool{}
	for name in explicit_abcs.keys() {
		templates[name] = true
	}
	for name in mixin_templates.keys() {
		templates[name] = true
	}
	for cls_name in m.class_hierarchy.keys() {
		if m.is_abc[cls_name] or { false } {
			continue
		}
		ancestors := m.get_all_ancestors(cls_name)
		for ancestor in ancestors {
			if ancestor in templates {
				mut mixin_chain := []string{}
				mixin_chain << ancestor
				mixin_chain << m.get_all_ancestors(ancestor)
				for mixin_name in mixin_chain {
					mut mains := m.mixin_to_main[mixin_name] or { []string{} }
					add_unique(mut mains, cls_name)
					m.mixin_to_main[mixin_name] = mains

					mut mixins := m.main_to_mixins[cls_name] or { []string{} }
					add_unique(mut mixins, mixin_name)
					m.main_to_mixins[cls_name] = mixins
				}
			}
		}
	}
}

pub struct FunctionMutabilityScanner {
pub mut:
	func_param_mutability map[string][]int
	current_func          string
	current_params        []string
	mutated_params        map[string]bool
	reassigned_params     map[string]bool
	scope_stack           []string
	mutability_map        map[string]MutabilityInfo
}

pub fn new_function_mutability_scanner() FunctionMutabilityScanner {
	return FunctionMutabilityScanner{
		func_param_mutability: map[string][]int{}
		current_func:          ''
		current_params:        []string{}
		mutated_params:        map[string]bool{}
		reassigned_params:     map[string]bool{}
		scope_stack:           []string{}
		mutability_map:        map[string]MutabilityInfo{}
	}
}

fn (mut f FunctionMutabilityScanner) get_base_node(node ast.Expression) ast.Expression {
	return match node {
		ast.Attribute { f.get_base_node(node.value) }
		ast.Subscript { f.get_base_node(node.value) }
		ast.Starred { f.get_base_node(node.value) }
		else { node }
	}
}

fn (mut f FunctionMutabilityScanner) mark_mutated(node ast.Expression) {
	match node {
		ast.Name {
			if node.id in f.current_params {
				f.mutated_params[node.id] = true
			}
		}
		ast.Attribute {
			if node.value is ast.Name && node.value.id in f.current_params {
				f.mutated_params[node.value.id] = true
			} else {
				f.mark_mutated(node.value)
			}
		}
		ast.Subscript {
			f.mark_mutated(node.value)
		}
		ast.Starred {
			f.mark_mutated(node.value)
		}
		ast.Tuple {
			for elt in node.elements {
				f.mark_mutated(elt)
			}
		}
		ast.List {
			for elt in node.elements {
				f.mark_mutated(elt)
			}
		}
		else {}
	}
}

fn (mut f FunctionMutabilityScanner) mark_reassigned(node ast.Expression) {
	match node {
		ast.Name {
			if node.id in f.current_params {
				f.reassigned_params[node.id] = true
			}
		}
		ast.Tuple {
			for elt in node.elements {
				f.mark_reassigned(elt)
			}
		}
		ast.List {
			for elt in node.elements {
				f.mark_reassigned(elt)
			}
		}
		ast.Starred {
			f.mark_reassigned(node.value)
		}
		else {}
	}
}

fn (mut f FunctionMutabilityScanner) visit_expr(node ast.Expression) {
	match node {
		ast.Call {
			if node.func is ast.Attribute {
				attr := node.func
				if is_mutating_method(attr.attr) {
					f.mark_mutated(attr.value)
				}
			}
			for arg in node.args {
				f.visit_expr(arg)
			}
			for kw in node.keywords {
				f.visit_expr(kw.value)
			}
			f.visit_expr(node.func)
		}
		ast.Attribute { f.visit_expr(node.value) }
		ast.Subscript {
			f.visit_expr(node.value)
			f.visit_expr(node.slice)
		}
		ast.BinaryOp {
			f.visit_expr(node.left)
			f.visit_expr(node.right)
		}
		ast.UnaryOp { f.visit_expr(node.operand) }
		ast.Compare {
			f.visit_expr(node.left)
			for comp in node.comparators {
				f.visit_expr(comp)
			}
		}
		ast.List {
			for elt in node.elements {
				f.visit_expr(elt)
			}
		}
		ast.Tuple {
			for elt in node.elements {
				f.visit_expr(elt)
			}
		}
		ast.Set {
			for elt in node.elements {
				f.visit_expr(elt)
			}
		}
		ast.Dict {
			for key in node.keys {
				if key !is ast.NoneExpr {
					f.visit_expr(key)
				}
			}
			for value in node.values {
				f.visit_expr(value)
			}
		}
		ast.JoinedStr {
			for value in node.values {
				f.visit_expr(value)
			}
		}
		ast.FormattedValue {
			f.visit_expr(node.value)
			if format_spec := node.format_spec {
				f.visit_expr(format_spec)
			}
		}
		ast.IfExp {
			f.visit_expr(node.test)
			f.visit_expr(node.body)
			f.visit_expr(node.orelse)
		}
		ast.Lambda {
			f.visit_expr(node.body)
		}
		ast.ListComp {
			f.visit_expr(node.elt)
		}
		ast.DictComp {
			f.visit_expr(node.key)
			f.visit_expr(node.value)
		}
		ast.SetComp {
			f.visit_expr(node.elt)
		}
		ast.GeneratorExp {
			f.visit_expr(node.elt)
		}
		ast.Await { f.visit_expr(node.value) }
		ast.Yield {
			if value := node.value {
				f.visit_expr(value)
			}
		}
		ast.YieldFrom { f.visit_expr(node.value) }
		ast.Starred { f.visit_expr(node.value) }
		ast.NamedExpr {
			f.visit_expr(node.target)
			f.visit_expr(node.value)
		}
		else {}
	}
}

fn (mut f FunctionMutabilityScanner) visit_stmt(node ast.Statement) {
	match node {
		ast.ClassDef {
			f.scope_stack << node.name
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			if f.scope_stack.len > 0 {
				f.scope_stack = f.scope_stack[..f.scope_stack.len - 1]
			}
		}
		ast.FunctionDef {
			old_func := f.current_func
			old_params := f.current_params.clone()
			old_mutated := f.mutated_params.clone()
			old_reassigned := f.reassigned_params.clone()

			f.current_func = node.name
			mut params := []string{}
			for param in node.args.posonlyargs {
				params << param.arg
			}
			for param in node.args.args {
				params << param.arg
			}
			for param in node.args.kwonlyargs {
				params << param.arg
			}
			f.current_params = params
			f.mutated_params = map[string]bool{}
			f.reassigned_params = map[string]bool{}

			for stmt in node.body {
				f.visit_stmt(stmt)
			}

			prefix := f.scope_stack.join('.')
			func_qual_name := if prefix.len > 0 { '${prefix}.${node.name}' } else { node.name }
			mut mutated_indices := []int{}
			for i, p in f.current_params {
				if p in f.mutated_params || p in f.reassigned_params {
					add_unique_int(mut mutated_indices, i)
					key := '${func_qual_name}.${p}'
					mut info := f.mutability_map[key] or { MutabilityInfo{} }
					if p in f.mutated_params {
						info.is_mutated = true
					}
					if p in f.reassigned_params {
						info.is_reassigned = true
					}
					f.mutability_map[key] = info

					mut simple := f.mutability_map[p] or { MutabilityInfo{} }
					if p in f.mutated_params {
						simple.is_mutated = true
					}
					if p in f.reassigned_params {
						simple.is_reassigned = true
					}
					f.mutability_map[p] = simple
				}
			}
			f.func_param_mutability[node.name] = mutated_indices
			if prefix.len > 0 {
				f.func_param_mutability[func_qual_name] = mutated_indices.clone()
			}

			f.current_func = old_func
			f.current_params = old_params
			f.mutated_params = old_mutated.clone()
			f.reassigned_params = old_reassigned.clone()
		}
		ast.Assign {
			for target in node.targets {
				if target is ast.Subscript || target is ast.Attribute {
					f.mark_mutated(f.get_base_node(target))
				} else if target is ast.Name {
					f.mark_reassigned(target)
				}
			}
			f.visit_expr(node.value)
			for target in node.targets {
				f.visit_expr(target)
			}
		}
		ast.AugAssign {
			if node.target is ast.Subscript || node.target is ast.Attribute {
				f.mark_mutated(f.get_base_node(node.target))
			} else if node.target is ast.Name {
				f.mark_reassigned(node.target)
			}
			f.visit_expr(node.target)
			f.visit_expr(node.value)
		}
		ast.Delete {
			for target in node.targets {
				if target is ast.Subscript {
					f.mark_mutated(f.get_base_node(target.value))
				}
				f.visit_expr(target)
			}
		}
		ast.Expr {
			f.visit_expr(node.value)
		}
		ast.Return {
			if value := node.value {
				f.visit_expr(value)
			}
		}
		ast.If {
			f.visit_expr(node.test)
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			for stmt in node.orelse {
				f.visit_stmt(stmt)
			}
		}
		ast.For {
			f.visit_expr(node.target)
			f.visit_expr(node.iter)
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			for stmt in node.orelse {
				f.visit_stmt(stmt)
			}
		}
		ast.While {
			f.visit_expr(node.test)
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			for stmt in node.orelse {
				f.visit_stmt(stmt)
			}
		}
		ast.With {
			for item in node.items {
				f.visit_expr(item.context_expr)
				if optional_vars := item.optional_vars {
					f.visit_expr(optional_vars)
				}
			}
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
		}
		ast.Try {
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			for handler in node.handlers {
				if typ := handler.typ {
					f.visit_expr(typ)
				}
				for stmt in handler.body {
					f.visit_stmt(stmt)
				}
			}
			for stmt in node.orelse {
				f.visit_stmt(stmt)
			}
			for stmt in node.finalbody {
				f.visit_stmt(stmt)
			}
		}
		ast.TryStar {
			for stmt in node.body {
				f.visit_stmt(stmt)
			}
			for handler in node.handlers {
				if typ := handler.typ {
					f.visit_expr(typ)
				}
				for stmt in handler.body {
					f.visit_stmt(stmt)
				}
			}
			for stmt in node.orelse {
				f.visit_stmt(stmt)
			}
			for stmt in node.finalbody {
				f.visit_stmt(stmt)
			}
		}
		ast.Match {
			f.visit_expr(node.subject)
			for case in node.cases {
				f.visit_pattern(case.pattern)
				if guard := case.guard {
					f.visit_expr(guard)
				}
				for stmt in case.body {
					f.visit_stmt(stmt)
				}
			}
		}
		ast.Import {}
		ast.ImportFrom {}
		ast.Global {}
		ast.Nonlocal {}
		ast.Assert {
			f.visit_expr(node.test)
			if msg := node.msg {
				f.visit_expr(msg)
			}
		}
		ast.Raise {
			if exc := node.exc {
				f.visit_expr(exc)
			}
			if cause := node.cause {
				f.visit_expr(cause)
			}
		}
		ast.Pass {}
		ast.Break {}
		ast.Continue {}
		ast.AnnAssign {
			f.visit_expr(node.target)
			f.visit_expr(node.annotation)
			if value := node.value {
				f.visit_expr(value)
			}
		}
		ast.TypeAlias {
			f.visit_expr(node.value)
			for type_param in node.type_params {
				f.visit_type_param(type_param)
			}
		}
		else {}
	}
}

fn (mut f FunctionMutabilityScanner) visit_type_param(node ast.TypeParam) {
	if bound := node.bound {
		f.visit_expr(bound)
	}
	if default_ := node.default_ {
		f.visit_expr(default_)
	}
}

fn (mut f FunctionMutabilityScanner) visit_pattern(node ast.Pattern) {
	match node {
		ast.MatchValue { f.visit_expr(node.value) }
		ast.MatchSequence {
			for pattern in node.patterns {
				f.visit_pattern(pattern)
			}
		}
		ast.MatchMapping {
			for key in node.keys {
				f.visit_expr(key)
			}
			for pattern in node.patterns {
				f.visit_pattern(pattern)
			}
		}
		ast.MatchClass {
			f.visit_expr(node.cls)
			for pattern in node.patterns {
				f.visit_pattern(pattern)
			}
			for pattern in node.kwd_patterns {
				f.visit_pattern(pattern)
			}
		}
		ast.MatchAs {
			if pattern := node.pattern {
				f.visit_pattern(pattern)
			}
		}
		ast.MatchOr {
			for pattern in node.patterns {
				f.visit_pattern(pattern)
			}
		}
		else {}
	}
}

pub fn (mut f FunctionMutabilityScanner) analyze(tree ast.Module, mutability_map map[string]MutabilityInfo) map[string][]int {
	f.mutability_map = mutability_map.clone()
	for stmt in tree.body {
		f.visit_stmt(stmt)
	}
	return f.func_param_mutability
}

pub fn (f &FunctionMutabilityScanner) get_mutated_params(func_name string) []int {
	return f.func_param_mutability[func_name] or { []int{} }
}
