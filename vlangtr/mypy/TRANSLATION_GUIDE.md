# Python в†’ V 0.5.x Translation Guide
## Р”Р»СЏ РїСЂРѕРµРєС‚Р° mypy в†’ V transpiler

---

## 1. Р§С‚Рѕ СѓР¶Рµ С‚СЂР°РЅСЃР»РёСЂРѕРІР°РЅРѕ

| Python РјРѕРґСѓР»СЊ | V С„Р°Р№Р» | РЎС‚Р°С‚СѓСЃ |
|---|---|---|
| `visitor.py` | `mypy/visitor.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ |
| `patterns.py` | `mypy/patterns.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ |
| `nodes.py` | `mypy/nodes.v` | вњ… РЇРґСЂРѕ (Р±РµР· cache/serialize) |
| `types.py` | `mypy/types.v` | вњ… Р’СЃРµ С‚РёРїС‹ + TypeTranslator + BoolTypeQuery |
| `type_visitor.py` | `mypy/type_visitor.v` | ✅ Отдельно вынесен bridge-модуль (TypeTranslator, TypeQuery, BoolTypeQuery) |
| `traverser.py` | `mypy/traverser.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ + dispatch helpers |
| `treetransform.py` | `mypy/treetransform.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TransformVisitor СЃ FuncMapInitializer) |
| `util.py` | `mypy/util.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (РєСЂРѕРјРµ JUNIT/orjson) |
| `checker.py` | `mypy/checker.v` | рџ“ќ TypeChecker: РІСЃРµ Statements (classes, funcs, ifs, loops, imports, assignments) |
| `checkexpr.py` | `mypy/checkexpr.v` | рџ“ќ Р—Р°РІРµСЂС€РµРЅС‹ РІРёР·РёС‚РѕСЂС‹: РІСЃРµ Р±Р°Р·РѕРІС‹Рµ Expressions (РІ С‚.С‡. Slice, Lambda, Yield) |
| `argmap.py` | `mypy/argmap.v` | рџ“ќ Р Р°Р·СЂРµС€РµРЅРёРµ Р°СЂРіСѓРјРµРЅС‚РѕРІ РІС‹Р·РѕРІР° С„СѓРЅРєС†РёРё |
| `checkmember.py`| `mypy/checkmember.v` | рџ“ќ РќР°С‡Р°Р»Рѕ: `analyze_instance_member_access` (РјРµС‚РѕРґС‹ Рё РїРµСЂРµРјРµРЅРЅС‹Рµ) |
| `binder.py` | `mypy/binder.v` | вњ… Narrowing С‚РёРїРѕРІ Рё СѓРїСЂР°РІР»РµРЅРёРµ С„СЂРµР№РјР°РјРё |
| `errors.py` | `mypy/errors.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (ErrorInfo, ErrorWatcher, Errors, CompileError) |
| `options.py` | `mypy/options.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (Options, BuildType, РІСЃРµ С„Р»Р°РіРё) |
| `errorcodes.py` | `mypy/errorcodes.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (ErrorCode Рё РІСЃРµ РєРѕРЅСЃС‚Р°РЅС‚С‹) |
| `message_registry.py` | `mypy/message_registry.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (ErrorMessage Рё РєРѕРЅСЃС‚Р°РЅС‚С‹) |
| `semanal_shared.py` | `mypy/semanal_shared.v` | вњ… РРЅС‚РµСЂС„РµР№СЃС‹ Рё РѕР±С‰РёРµ С„СѓРЅРєС†РёРё Р°РЅР°Р»РёР·Р°С‚РѕСЂР° |
| `semanal_classprop.py` | `mypy/semanal_classprop.v` | вњ… Р’С‹С‡РёСЃР»РµРЅРёРµ СЃРІРѕР№СЃС‚РІ РєР»Р°СЃСЃРѕРІ (Р°Р±СЃС‚СЂР°РєС‚РЅРѕСЃС‚СЊ, ClassVar) |
| `typetraverser.py` | `mypy/typetraverser.v` | вњ… РџРѕР»РЅС‹Р№ РѕР±С…РѕРґС‡РёРє С‚РёРїРѕРІ |
| `mixedtraverser.py` | `mypy/mixedtraverser.v` | вњ… РћР±С…РѕРґС‡РёРє СѓР·Р»РѕРІ Рё С‚РёРїРѕРІ (С‡РµСЂРµР· РІСЃС‚СЂР°РёРІР°РЅРёРµ) |
| `semanal_typeargs.py` | `mypy/semanal_typeargs.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (РїСЂРѕРІРµСЂРєР° Р°СЂРіСѓРјРµРЅС‚РѕРІ С‚РёРїРѕРІ) |
| `semanal_enum.py` | `mypy/semanal_enum.v` | вњ… РўСЂР°РЅСЃР»СЏС†РёСЏ РІС‹Р·РѕРІРѕРІ Enum |
| `semanal_typeddict.py` | `mypy/semanal_typeddict.v` | рџ“ќ Р§Р°СЃС‚РёС‡РЅРѕ (Р°РЅР°Р»РёР· ClassDef РґР»СЏ TypedDict) |
| `semanal_namedtuple.py` | `mypy/semanal_namedtuple.v` | рџ“ќ Р§Р°СЃС‚РёС‡РЅРѕ (Р°РЅР°Р»РёР· ClassDef РґР»СЏ NamedTuple) |
| `semanal_newtype.py` | `mypy/semanal_newtype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (Р°РЅР°Р»РёР· NewType) |
| `semanal_main.py` | `mypy/semanal_main.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (Р°РЅР°Р»РёР· SCC РґР»СЏ СЃРµРјР°РЅС‚РёС‡РµСЃРєРѕРіРѕ Р°РЅР°Р»РёР·Р°) |
| `mro.py` | `mypy/mro.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (C3 linearization РґР»СЏ MRO) |
| `literals.py` | `mypy/literals.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (literal_hash, _Hasher visitor) |
| `typevars.py` | `mypy/typevars.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (fill_typevars, fill_typevars_with_any, has_no_typevars) |
| `tvar_scope.py` | `mypy/tvar_scope.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TypeVarLikeScope, TypeVarLikeDefaultFixer) |
| `erasetype.py` | `mypy/erasetype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (erase_type, erase_typevars, TypeVarEraser, LastKnownValueEraser) |
| `typestate.py` | `mypy/typestate.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TypeState, subtype caches, protocol dependencies) |
| `state.py` | `mypy/state.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (StrictOptionalState, global state, with_strict_optional) |
| `defaults.py` | `mypy/defaults.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (РєРѕРЅСЃС‚Р°РЅС‚С‹: РІРµСЂСЃРёРё Python, cache, config, reporter names) |
| `operators.py` | `mypy/operators.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (op_methods, reverse_op_methods, inplace_operator_methods, СѓС‚РёР»РёС‚С‹) |
| `split_namespace.py` | `mypy/split_namespace.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (SplitNamespace РґР»СЏ argparse СЃ РїСЂРµС„РёРєСЃР°РјРё) |
| `version.py` | `mypy/version.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (__version__, VersionInfo, parse_version, compare_versions) |
| `pyinfo.py` | `mypy/pyinfo.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (getsitepackages, getsyspath, getsearchdirs, СѓС‚РёР»РёС‚С‹) |
| `stubinfo.py` | `mypy/stubinfo.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (stub_distribution_name, is_module_from_legacy_bundled_package) |
| `sharedparse.py` | `mypy/sharedparse.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (magic_methods, special_function_elide_names, argument_elide_name) |
| `build.py` | `mypy/build.v` | рџ“ќ РџРѕР»СѓРіРѕС‚РѕРІРѕ: State, BuildManager, SCC, BuildResult, topological sort |
| `bogus_type.py` | `mypy/bogus_type.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (РєРѕРЅСЃС‚Р°РЅС‚Р° `mypyc`, alias helpers `bogus`/`bogus_erased`) |
| `__init__.py` | `mypy/__init__.v` | ? пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ (пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ-пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅ пїЅ Python) |
| `__main__.py` | `mypy/__main__.v` | рџ“ќ РљР°СЂРєР°СЃ РїРµСЂРµРЅРµСЃС‘РЅ (entry wrapper: `console_entry`, `run_dunder_main`) |
| `checker_state.py` | `mypy/checker_state.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TypeCheckerState + РІСЂРµРјРµРЅРЅР°СЏ СѓСЃС‚Р°РЅРѕРІРєР° РєРѕРЅС‚РµРєСЃС‚Р°) |
| `error_formatter.py` | `mypy/error_formatter.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (ErrorFormatter + JSONFormatter + `output_choices`) |
| `api.py` | `mypy/api.v` | рџ“ќ РљР°СЂРєР°СЃ API (`_run`, `run`) РґРѕ РїРµСЂРµРЅРѕСЃР° `main.py` |
| `fscache.py` | `mypy/fscache.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (РєСЌС€ stat/listdir/read/hash, fake `__init__.py`, case-sensitive checks, samefile) |
| `fswatcher.py` | `mypy/fswatcher.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (FileSystemWatcher, FileData, РёР·РјРµРЅРµРЅРёСЏ С„Р°Р№Р»РѕРІ РїРѕ stat/hash) |
| `semanal_infer.py` | `mypy/semanal_infer.v` | рџ“ќ РџРµСЂРµРЅРµСЃРµРЅС‹ РєР»СЋС‡РµРІС‹Рµ СЌРІСЂРёСЃС‚РёРєРё РґР»СЏ РґРµРєРѕСЂР°С‚РѕСЂРѕРІ (`infer_decorator_signature_if_simple`) |
| `parse.py` | `mypy/parse.v` | рџ“ќ РљР°СЂРєР°СЃ РїР°СЂСЃРёРЅРіР° Рё `load_from_raw` (native/fast parser hooks) |
| `nativeparse.py` | `mypy/nativeparse.v` | ✅ Десериализация бинарного AST, интеграция с V-парсером |
| `ast/serialize.v` | `ast/serialize.v` | ✅ V-native сериализатор AST (замена mypyc) |
| `infer.py` | `mypy/infer.v` | рџ“ќ Р—Р°РіР»СѓС€РєРё: `infer_type_arguments`, `infer_function_type_arguments`, `Constraint` |
| `solve.py` | `mypy/solve.v` | рџ“ќ Р РµС€Р°С‚РµР»СЊ РѕРіСЂР°РЅРёС‡РµРЅРёР№ (solve_one, join of lowers, meet of uppers) |
| `copytype.py` | `mypy/copytype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (copy_type, TypeShallowCopier С‡РµСЂРµР· match) |
| `maptype.py` | `mypy/maptype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (map_instance_to_supertype, map_instance_to_supertypes, class_derivation_paths) |
| `typevartuples.py` | `mypy/typevartuples.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (split_with_instance, erased_vars) |
| `graph_utils.py` | `mypy/graph_utils.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (strongly_connected_components, prepare_sccs, TopSort) |
| `refinfo.py` | `mypy/refinfo.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (RefInfoVisitor, type_fullname, get_undocumented_ref_info_json) |
| `scope.py` | `mypy/scope.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (Scope, SavedScope, module/class/function scopes) |
| `lookup.py` | `mypy/lookup.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (lookup_fully_qualified) |
| `state.py` | `mypy/state.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (StrictOptionalState, state, find_occurrences) |
| `defaults.py` | `mypy/defaults.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (Python3_VERSION, CACHE_DIR, CONFIG_NAMES, reporter_names, timeouts) |
| `stubinfo.py` | `mypy/stubinfo.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (stub_distribution_name, is_module_from_legacy_bundled_package) |
| `freetree.py` | `mypy/freetree.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TreeFreer, free_tree) |
| `pyinfo.py` | `mypy/pyinfo.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (getsite_packages, getsyspath, getsearch_dirs) |
| `version.py` | `mypy/version.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (__version__, base_version) |
| `meet.py` | `mypy/meet.v` | рџ“ќ Р‘Р°Р·РѕРІС‹Рµ `meet_types`, `is_overlapping_types` |
| `join.py` | `mypy/join.v` | рџ“ќ Р‘Р°Р·РѕРІС‹Рµ `join_types`, `join_type_list` |
| `subtypes.py` | `mypy/subtypes.v` | рџ“ќ РћСЃРЅРѕРІРЅР°СЏ Р»РѕРіРёРєР° `is_subtype` (Instance, Callable, Union) |
| `checkpattern.py` | `mypy/checkpattern.v` | рџ“ќ PatternChecker: `visit_match_stmt` |
| `expandtype.py` | `mypy/expandtype.v` | рџ“ќ РџРѕРґСЃС‚Р°РЅРѕРІРєР° `TypeVar` С‡РµСЂРµР· РєРѕРЅС‚РµРєСЃС‚ РёРЅСЃС‚Р°РЅСЃР° (`expand_type`) |
| `lookup.py` | `mypy/lookup.v` | рџ“ќ РџРѕРёСЃРє СЃРёРјРІРѕР»РѕРІ РІ РіР»РѕР±Р°Р»СЊРЅРѕР№ С‚Р°Р±Р»РёС†Рµ (lookup_fully_qualified) |
| `plugin.py` | `mypy/plugin.v` | рџ“ќ РЎРёСЃС‚РµРјР° РїР»Р°РіРёРЅРѕРІ (Contexts, Interfaces, ChainedPlugin) |
| `typeanal.py` | `mypy/typeanal.v` | рџ“ќ РЎРµРјР°РЅС‚РёС‡РµСЃРєРёР№ Р°РЅР°Р»РёР·Р°С‚РѕСЂ РґР»СЏ С‚РёРїРѕРІ (TypeAnalyser, UnboundType -> Instance) |
| `constraints.py` | `mypy/constraints.v` | рџ“ќ Р’С‹РІРѕРґ РѕРіСЂР°РЅРёС‡РµРЅРёР№ С‚РёРїРѕРІ: Constraint, infer_constraints, any_constraints, filter_imprecise_kinds |
| `constant_fold.py` | `mypy/constant_fold.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (constant_fold_expr, binary/unary ops, int/float/string) |
| `strconv.py` | `mypy/strconv.v` | рџ“ќ StrConv visitor: dump, visit_* РґР»СЏ СѓР·Р»РѕРІ AST, func_helper, pretty_name, IdMapper |
| `partially_defined.py` | `mypy/partially_defined.v` | рџ“ќ BranchState, BranchStatement, DefinedVariableTracker, Scope, Loop |
| `renaming.py` | `mypy/renaming.v` | рџ“ќ VariableRenameVisitor, BlockGuard/TryGuard/LoopGuard/ScopeGuard |
| `config_parser.py` | `mypy/config_parser.v` | рџ“ќ parse_version, try_split, expand_path, ini/toml_config_types, split_directive |
| `types_utils.py` | `mypy/types_utils.v` | рџ“ќ flatten_types, strip_type, is_union_with_any, remove_optional, store_argument_type |
| `semanal_pass1.py` | `mypy/semanal_pass1.v` | рџ“ќ SemanticAnalyzerPreAnalysis: visit_file, visit_if_stmt, visit_block, reachability |
| `semanal_infer.py` | `mypy/semanal_infer.v` | рџ“ќ infer_decorator_signature_if_simple, is_identity_signature, calculate_return_type |
| `checkstrformat.py` | `mypy/checkstrformat.v` | рџ“ќ StringFormatterChecker, ConversionSpecifier, parse_conversion_specifiers, conversion_type |
| `cache.py` | `mypy/cache.v` | рџ“ќ CacheMeta, ErrorInfo, FF serialization tags, read/write literals, lists, JSON |
| `exportjson.py` | `mypy/exportjson.v` | рџ“ќ convert_binary_cache_to_json, convert_mypy_file_to_json, convert_type (partial) |
| `typeanal.py` | `mypy/typeanal.v` | рџ“ќ TypeAnalyser, analyze_type_alias, visit_unbound_type, try_analyze_special_unbound_type |
| `subtypes.py` | `mypy/subtypes.v` | рџ“ќ SubtypeContext, is_subtype, is_instance_subtype, is_callable_subtype, check_type_parameter |
| `modulefinder.py` | `mypy/modulefinder.v` | рџ“ќ SearchPaths, FindModuleCache, BuildSource, ModuleNotFoundReason, compute_search_paths |
| `main.py` | `mypy/main.v` | рџ“ќ main, run_build, process_options, install_types, flush_errors |
| `fastparse.py` | `mypy/fastparse.v` | рџ“ќ ASTConverter, TypeConverter, parse, op_map, comp_op_map |
| `expandtype.py` | `mypy/expandtype.v` | рџ“ќ expand_type, expand_type_by_instance, ExpandTypeVisitor, freshen_function_type_vars |
| `join.py` | `mypy/join.v` | рџ“ќ InstanceJoiner, join_types, TypeJoinVisitor, join_type_list, trivial_join |
| `meet.py` | `mypy/meet.v` | рџ“ќ meet_types, TypeMeetVisitor, narrow_declared_type, is_overlapping_types, trivial_meet |
| `plugin.py` | `mypy/plugin.v` | рџ“ќ Plugin, ChainedPlugin, Contexts (FunctionContext, MethodContext, AttributeContext, ClassDefContext) |
| `solve.py` | `mypy/solve.v` | рџ“ќ solve_constraints, solve_one, transitive_closure, find_linear, Bounds, Graph |
| `applytype.py` | `mypy/applytype.v` | рџ“ќ apply_generic_arguments, get_target_type, apply_poly, PolyTranslator |
| `semanal.py` | `mypy/semanal.v` | рџ“ќ SemanticAnalyzer: visit_file, visit_func_def, visit_class_def, visit_import, analyze_class |
| `checker.py` | `mypy/checker.v` | рџ“ќ TypeChecker: visit_func_def, visit_class_def, visit_if_stmt, check_assignment, DeferredNode |
| `indirection.py` | `mypy/indirection.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TypeIndirectionVisitor РґР»СЏ Р°РЅР°Р»РёР·Р° Р·Р°РІРёСЃРёРјРѕСЃС‚РµР№ РјРѕРґСѓР»РµР№) |
| `stats.py` | `mypy/stats.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (StatisticsVisitor РґР»СЏ СЃР±РѕСЂР° СЃС‚Р°С‚РёСЃС‚РёРєРё Рѕ С‚РёРїР°С…) |
| `ipc.py` | `mypy/ipc.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (IPCBase, IPCClient, IPCServer, IPCMessage, WriteBuffer, ReadBuffer) |
| `reachability.py` | `mypy/reachability.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (infer_reachability_of_if_statement, infer_condition_value, mark_block_unreachable) |
| `evalexpr.py` | `mypy/evalexpr.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (NodeEvaluator, evaluate_expression РґР»СЏ РІС‹С‡РёСЃР»РµРЅРёСЏ РІС‹СЂР°Р¶РµРЅРёР№) |
| `moduleinspect.py` | `mypy/moduleinspect.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (ModuleProperties, ModuleInspect, get_package_properties, is_c_module) |
| `find_sources.py` | `mypy/find_sources.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (SourceFinder, create_source_list, crawl_up, find_sources_in_dir) |
| `metastore.py` | `mypy/metastore.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (MetadataStore РёРЅС‚РµСЂС„РµР№СЃ, FilesystemMetadataStore, SqliteMetadataStore) |
| `fixup.py` | `mypy/fixup.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (NodeFixer, TypeFixer, fixup_module, lookup_fully_qualified_typeinfo) |
| `checker_shared.py` | `mypy/checker_shared.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TypeRange, CheckerScope, TypeAndType, TypeAndStringList, fill_typevars) |
| `exprtotype.py` | `mypy/exprtotype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (expr_to_unanalyzed_type, _extract_argument_name, TypeTranslationError) |
| `applytype.py` | `mypy/applytype.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (apply_generic_arguments, get_target_type, apply_poly, PolyTranslator) |
| `fscache.py` | `mypy/fscache.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (FileSystemCache, stat_or_none, listdir, read, isfile_case, exists_case) |
| `treetransform.py` | `mypy/treetransform.v` | вњ… РџРѕР»РЅРѕСЃС‚СЊСЋ (TransformVisitor, duplicate_name, copy_ref, copy_argument, visit_* РґР»СЏ РІСЃРµС… СѓР·Р»РѕРІ AST) |
| `typeops.py` | `mypy/typeops.v` | ✅ Полностью (is_recursive_pair, tuple_fallback, get_self_type, make_simplified_union, is_*_type helpers) |

---



---

## 3. РљР»СЋС‡РµРІС‹Рµ РїСЂР°РІРёР»Р° С‚СЂР°РЅСЃР»СЏС†РёРё Python в†’ V 0.5.x

### 3.1 РРµСЂР°СЂС…РёСЏ РєР»Р°СЃСЃРѕРІ в†’ РёРЅС‚РµСЂС„РµР№СЃС‹ + sum-types

```python
# Python
class Node:
    pass
class Statement(Node):
    pass
class AssignmentStmt(Statement):
    lvalues: list[Expression]
    rvalue: Expression
```

```v
// V: Р±Р°Р·РѕРІС‹Рµ РєР»Р°СЃСЃС‹ в†’ РёРЅС‚РµСЂС„РµР№СЃС‹ РёР»Рё РІСЃС‚СЂР°РёРІР°РµРјС‹Рµ СЃС‚СЂСѓРєС‚СѓСЂС‹
pub interface Node {
    get_context() Context
    accept(v NodeVisitor) !string
}

// РљРѕРЅРєСЂРµС‚РЅС‹Рµ СѓР·Р»С‹ вЂ” РѕР±С‹С‡РЅС‹Рµ struct
pub struct AssignmentStmt {
pub mut:
    base    NodeBase
    lvalues []Expression
    rvalue  Expression
}

// "РџРѕР»РёРјРѕСЂС„РёР·Рј" С‡РµСЂРµР· sum-type
pub type Statement = AssignmentStmt | ForStmt | IfStmt | ...
```

### 3.2 РћРїС†РёРѕРЅР°Р»СЊРЅС‹Рµ РїРѕР»СЏ (X | None)

```python
# Python
end_line: int | None = None
expr: Expression | None
```

```v
// V: ?Type
pub mut:
    end_line ?int
    expr     ?Expression
```

Р Р°Р±РѕС‚Р° СЃ РѕРїС†РёРѕРЅР°Р»СЊРЅС‹РјРё РїРѕР»СЏРјРё:
```v
// V: if let Р°РЅР°Р»РѕРі
if e := o.expr {
    expr_accept(e, v)!
}

// РР»Рё С‡РµСЂРµР· or {}
val := o.expr or { return '' }
```

### 3.3 РњРµС‚РѕРґС‹ СЃ default-СЂРµР°Р»РёР·Р°С†РёРµР№ (@abstractmethod / pass)

```python
# Python
class NodeVisitor(Generic[T]):
    def visit_int_expr(self, o: IntExpr) -> T:
        raise NotImplementedError()
```

```v
// V: РёРЅС‚РµСЂС„РµР№СЃ вЂ” РІСЃРµ РјРµС‚РѕРґС‹ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹ РґР»СЏ СЂРµР°Р»РёР·Р°С†РёРё
pub interface NodeVisitor {
    visit_int_expr(o &IntExpr) !string
    // ...
}

// РљРѕРЅРєСЂРµС‚РЅС‹Р№ traverser вЂ” struct, СЂРµР°Р»РёР·СѓСЋС‰РёР№ РІСЃРµ РјРµС‚РѕРґС‹
pub struct NodeTraverser {}

pub fn (t &NodeTraverser) visit_int_expr(o &IntExpr) !string { return '' }
```

### 3.4 Generic[T] в†’ !string + РѕР±С‘СЂС‚РєР°

Python РёСЃРїРѕР»СЊР·СѓРµС‚ `Generic[T]` С‡С‚РѕР±С‹ visitor РІРѕР·РІСЂР°С‰Р°Р» СЂР°Р·РЅС‹Рµ С‚РёРїС‹.
Р’ V РёСЃРїРѕР»СЊР·СѓРµРј `!string` РєР°Рє СѓРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Р№ РІРѕР·РІСЂР°С‚. Р”Р»СЏ С‚РёРїРёР·РёСЂРѕРІР°РЅРЅС‹С… СЂРµР·СѓР»СЊС‚Р°С‚РѕРІ:

```v
// Visitor РІРѕР·РІСЂР°С‰Р°СЋС‰РёР№ СЂРµР°Р»СЊРЅС‹Рµ СЃС‚СЂСѓРєС‚СѓСЂС‹ вЂ” РѕР±РµСЂРЅРёС‚Рµ РІ СЃРІРѕР№ struct
pub struct TypeStrVisitor {
pub mut:
    result string
}

pub fn (mut v TypeStrVisitor) visit_int_expr(o &IntExpr) !string {
    v.result = o.value.str()
    return v.result
}
```

### 3.5 isinstance() в†’ match РЅР° sum-type

```python
# Python
if isinstance(target, int):
    self.line = target
elif isinstance(target, Context):
    self.line = target.line
```

```v
// V: match РЅР° sum-type РёР»Рё РёРЅС‚РµСЂС„РµР№СЃРЅС‹Р№ is
match target {
    int     { c.line = target }
    Context { c.line = target.line }
}

// РР»Рё РґР»СЏ РёРЅС‚РµСЂС„РµР№СЃР°:
if target is MyStruct {
    // target Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё РїСЂРёРІРµРґС‘РЅ Рє MyStruct
}
```

### 3.6 @property СЃ lazy init

```python
# Python
@property
def can_be_true(self) -> bool:
    if self._can_be_true == -1:
        self._can_be_true = self.can_be_true_default()
    return bool(self._can_be_true)
```

```v
// V: РѕР±С‹С‡РЅС‹Р№ mut РјРµС‚РѕРґ СЃ РєСЌС€РµРј
pub fn (mut t TypeBase) can_be_true() bool {
    if t._can_be_true == -1 {
        t._can_be_true = 1 // РёР»Рё РІС‹Р·РѕРІ Р»РѕРіРёРєРё
    }
    return t._can_be_true == 1
}
```

### 3.7 ClassVar / Final в†’ РєРѕРЅСЃС‚Р°РЅС‚С‹ РјРѕРґСѓР»СЏ

```python
# Python
class TypeOfAny:
    unannotated: Final = 1
    explicit: Final = 2
```

```v
// V: enum (РїСЂРµРґРїРѕС‡С‚РёС‚РµР»СЊРЅРѕ) РёР»Рё module-level const
pub enum TypeOfAny {
    unannotated
    explicit
    from_unimported_type
    // ...
}

// РР»Рё const РµСЃР»Рё РЅСѓР¶РЅС‹ РєРѕРЅРєСЂРµС‚РЅС‹Рµ int Р·РЅР°С‡РµРЅРёСЏ:
pub const type_of_any_unannotated = 1
pub const type_of_any_explicit    = 2
```

### 3.8 dict[str, Any] / map в†’ map СЃ РєРѕРЅРєСЂРµС‚РЅС‹Рј С‚РёРїРѕРј

```python
# Python
names: dict[str, SymbolTableNode]
items: dict[str, Type]
```

```v
// V: С‚РёРїРёР·РёСЂРѕРІР°РЅРЅС‹Рµ map
pub mut:
    names map[string]SymbolTableNode
    items map[string]MypyTypeNode

// РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ
names := map[string]SymbolTableNode{}
```

### 3.9 list comprehension в†’ map/filter РёР»Рё СЏРІРЅС‹Р№ С†РёРєР»

```python
# Python
result = [t.accept(self) for t in types]
filtered = [x for x in items if x is not None]
```

```v
// V: arrays module РёР»Рё СЏРІРЅС‹Р№ for
result := types.map(it.accept(v) or { panic('visitor error') })

// РЎ С„РёР»СЊС‚СЂРѕРј:
mut filtered := []MyType{}
for x in items {
    if x != none {
        filtered << x
    }
}

// Р‘РѕР»РµРµ РёРґРёРѕРјР°С‚РёС‡РЅРѕ С‡РµСЂРµР· arrays:
// import arrays вЂ” РµСЃР»Рё РЅСѓР¶РµРЅ filter
filtered := items.filter(it != MyType(none))
```

### 3.10 try/except в†’ or {} / !Type

```python
# Python
try:
    result = do_something()
except ValueError as e:
    handle(e)
```

```v
// V: СЂРµР·СѓР»СЊС‚РёСЂСѓСЋС‰РёР№ С‚РёРї !T
result := do_something() or {
    handle_error(err)
    return
}

// РР»Рё propagate:
result := do_something()!
```

### 3.11 РњРЅРѕР¶РµСЃС‚РІРµРЅРЅРѕРµ РЅР°СЃР»РµРґРѕРІР°РЅРёРµ

```python
# Python
class FuncDef(FuncItem, SymbolNode, Statement):
    pass
```

```v
// V: РЅРµС‚ РјРЅРѕР¶РµСЃС‚РІРµРЅРЅРѕРіРѕ РЅР°СЃР»РµРґРѕРІР°РЅРёСЏ.
// Р РµС€РµРЅРёРµ: embedded structs + РёРЅС‚РµСЂС„РµР№СЃС‹

pub struct FuncDef {
pub mut:
    base       NodeBase   // РІСЃС‚СЂР°РёРІР°РµРј РѕР±С‰СѓСЋ Р±Р°Р·Сѓ
    func_base  FuncBase   // РїРѕР»СЏ РёР· FuncItem/FuncBase
    name       string
    // ... РѕСЃС‚Р°Р»СЊРЅС‹Рµ РїРѕР»СЏ
}

// РџСЂРёРЅР°РґР»РµР¶РЅРѕСЃС‚СЊ Рє Statement Рё SymbolNode
// РІС‹СЂР°Р¶РµРЅР° С‡РµСЂРµР· РІРєР»СЋС‡РµРЅРёРµ FuncDef РІ sum-types Statement / SymbolNodeRef
```

### 3.12 Circular imports в†’ forward declarations С‡РµСЂРµР· РёРЅС‚РµСЂС„РµР№СЃ

```python
# Python (nodes.py Рё types.py РёРјРїРѕСЂС‚РёСЂСѓСЋС‚ РґСЂСѓРі РґСЂСѓРіР°)
if TYPE_CHECKING:
    import mypy.types
```

```v
// V: РѕРїСЂРµРґРµР»РёС‚Рµ РёРЅС‚РµСЂС„РµР№СЃ MypyType РІ nodes.v,
// СЂРµР°Р»РёР·СѓР№С‚Рµ РµРіРѕ РІ types.v С‡РµСЂРµР· MypyTypeNode.
// РљРѕРЅРєСЂРµС‚РЅС‹Р№ С‚РёРї РѕСЃС‚Р°С‘С‚СЃСЏ РЅРµРїСЂРѕР·СЂР°С‡РЅС‹Рј РґР»СЏ nodes.v.

pub interface MypyType {
    type_str() string
}
```

---

## 4. Dispatch helpers вЂ” РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Р№ РїР°С‚С‚РµСЂРЅ

РџРѕСЃРєРѕР»СЊРєСѓ V С‚СЂРµР±СѓРµС‚ СЏРІРЅРѕРіРѕ `match` РґР»СЏ sum-types,
РґР»СЏ РєР°Р¶РґРѕРіРѕ sum-type СЃРѕР·РґР°Р№С‚Рµ dispatch helper:

```v
// Р’ traverser.v РёР»Рё РѕС‚РґРµР»СЊРЅРѕРј dispatch.v
pub fn stmt_accept(s Statement, v NodeVisitor) !string {
    return match s {
        AssignmentStmt { v.visit_assignment_stmt(&s)! }
        ForStmt        { v.visit_for_stmt(&s)! }
        // ... РІСЃРµ РІР°СЂРёР°РЅС‚С‹
    }
}

pub fn expr_accept(e Expression, v NodeVisitor) !string {
    return match e {
        IntExpr  { v.visit_int_expr(&e)! }
        StrExpr  { v.visit_str_expr(&e)! }
        // ...
    }
}
```

---

## 5. РЎС‚СЂСѓРєС‚СѓСЂР° РјРѕРґСѓР»РµР№ V

```
mypy_v/
  mypy/
    visitor.v       в†ђ NodeVisitor, ExpressionVisitor, StatementVisitor, PatternVisitor
    nodes.v         в†ђ AST node structs, Statement/Expression sum-types, MypyFile
    patterns.v      в†ђ Pattern structs and PatternNode sum-type
    types.v         в†ђ Type structs, MypyTypeNode sum-type, TypeVisitor, BoolTypeQuery
    traverser.v     в†ђ NodeTraverser (default no-op), stmt_accept, expr_accept
    errors.v        в†ђ вњ… ErrorInfo, ErrorWatcher, Errors, CompileError
    options.v       в†ђ вњ… Options, BuildType, РІСЃРµ С„Р»Р°РіРё РєРѕРЅС„РёРіСѓСЂР°С†РёРё
    errorcodes.v    в†ђ вњ… ErrorCode Рё РІСЃРµ РєРѕРЅСЃС‚Р°РЅС‚С‹ РєРѕРґРѕРІ РѕС€РёР±РѕРє
    util.v          в†ђ (СЃР»РµРґСѓСЋС‰РёР№ С€Р°Рі)
    checker.v       в†ђ (РїРѕР·Р¶Рµ, СЂР°Р·Р±РёС‚СЊ РЅР° РЅРµСЃРєРѕР»СЊРєРѕ С„Р°Р№Р»РѕРІ)
    build.v         в†ђ (РїРѕР·Р¶Рµ)
```

---

## 6. РР·РІРµСЃС‚РЅС‹Рµ РѕРіСЂР°РЅРёС‡РµРЅРёСЏ V 0.5.x

| РџСЂРѕР±Р»РµРјР° | Р РµС€РµРЅРёРµ |
|---|---|
| РќРµС‚ generics РЅР° РёРЅС‚РµСЂС„РµР№СЃР°С… РєР°Рє РІ Python | РСЃРїРѕР»СЊР·СѓР№ `!string` + СЏРІРЅС‹Рµ РєРѕРЅРІРµСЂСЃРёРё |
| Sum-type РЅРµ РјРѕР¶РµС‚ СЃРѕРґРµСЂР¶Р°С‚СЊ СЂРµРєСѓСЂСЃРёРІРЅС‹Рµ СЃСЃС‹Р»РєРё РЅР° СЃРµР±СЏ | РСЃРїРѕР»СЊР·СѓР№ `?&T` РёР»Рё РІСЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹Р№ wrapper struct |
| РќРµС‚ `__hash__` в†’ РЅРµР»СЊР·СЏ РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ struct РєР°Рє РєР»СЋС‡ map | РСЃРїРѕР»СЊР·СѓР№ string-РєР»СЋС‡Рё (fullname, id.str()) |
| `mut` СЃС‚СЂРѕРіРѕ РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ | РќРµ РїРѕРјРµС‡Р°Р№ `mut` РїРѕР»СЏ РєРѕС‚РѕСЂС‹Рµ РЅРµ РјСѓС‚РёСЂСѓСЋС‚СЃСЏ |
| РќРµС‚ РєР»СЋС‡РµРІС‹С… Р°СЂРіСѓРјРµРЅС‚РѕРІ РІ С„СѓРЅРєС†РёСЏС… СЃ default | РСЃРїРѕР»СЊР·СѓР№ РёРјРµРЅРѕРІР°РЅРЅС‹Рµ struct init `Foo{ field: val }` |
| Python `set` в†’ V РЅРµС‚ РІСЃС‚СЂРѕРµРЅРЅРѕРіРѕ set | РСЃРїРѕР»СЊР·СѓР№ `map[K]bool` |

---

## 7. РџСЂРёРјРµСЂ РєРѕРЅРєСЂРµС‚РЅРѕР№ С‚СЂР°РЅСЃР»СЏС†РёРё: checker.py С„СЂР°РіРјРµРЅС‚

```python
# Python checker.py
class TypeChecker(NodeVisitor[None]):
    def visit_assignment_stmt(self, s: AssignmentStmt) -> None:
        self.check_assignment(s.lvalues, s.rvalue)
    
    def check_assignment(self, lvalues: list[Lvalue], rvalue: Expression) -> None:
        for lvalue in lvalues:
            self.check_lvalue(lvalue)
```

```v
// V checker.v
pub struct TypeChecker {
pub mut:
    errors  Errors
    options Options
    // ...
}

pub fn (mut tc TypeChecker) visit_assignment_stmt(s &AssignmentStmt) !string {
    tc.check_assignment(s.lvalues, s.rvalue)!
    return ''
}

pub fn (mut tc TypeChecker) check_assignment(lvalues []Expression, rvalue Expression) ! {
    for lv in lvalues {
        tc.check_lvalue(lv)!
    }
}
```
