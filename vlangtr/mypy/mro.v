// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 15:30
// MRO (Method Resolution Order) calculation for mypy (mro.py)

module mypy

// MroError — raised if a consistent mro cannot be determined for a class.
pub struct MroError {
	msg string
}

pub fn (e MroError) error() string {
	return e.msg
}

// calculate_mro calculates and sets mro (method resolution order).
// Raises MroError if cannot determine mro.
pub fn calculate_mro(info &TypeInfo, obj_type ?&fn () Instance) ! {
	mro := linearize_hierarchy(info, obj_type)!
	assert mro.len > 0, 'Could not produce a MRO at all for ${info.defn.name}'
	info.mro = mro
	// The property of falling back to Any is inherited.
	info.fallback_to_any = info.mro.any(it.fallback_to_any)
	type_state.reset_all_subtype_caches_for(info)
}

// linearize_hierarchy linearizes the hierarchy for MRO calculation.
pub fn linearize_hierarchy(info &TypeInfo, obj_type ?&fn () Instance) ![]TypeInfo {
	// TODO describe
	if info.mro.len > 0 {
		return info.mro
	}

	bases := info.direct_base_classes()

	if bases.len == 0 && info.fullname != 'builtins.object' && obj_type != none {
		// Probably an error, add a dummy `object` base class,
		// otherwise MRO calculation may spuriously fail.
		if obj_type != none {
			instance := obj_type()
			bases = [instance.type]
		}
	}

	mut lin_bases := [][]TypeInfo{}
	for base in bases {
		assert base != none, 'Cannot linearize bases for ${info.fullname} ${bases}'
		lin_bases << linearize_hierarchy(base, obj_type)!
	}
	lin_bases << bases

	return [info] + merge(lin_bases)
}

// merge merges multiple sequences into a single linearized order using C3 linearization.
pub fn merge(seqs [][]TypeInfo) []TypeInfo {
	mut work_seqs := seqs.clone()
	mut result := []TypeInfo{}

	for {
		// Remove empty sequences
		work_seqs = work_seqs.filter(it.len > 0)

		if work_seqs.len == 0 {
			return result
		}

		mut head := ?TypeInfo(none)
		mut found := false

		// Find a valid head element
		for seq in work_seqs {
			if seq.len == 0 {
				continue
			}

			candidate := seq[0]

			// Check if candidate appears in any tail
			mut appears_in_tail := false
			for s in work_seqs {
				if s.len > 1 && candidate in s[1..] {
					appears_in_tail = true
					break
				}
			}

			if !appears_in_tail {
				head = candidate
				found = true
				break
			}
		}

		if !found {
			// Cannot find a valid head — MRO conflict
			panic('MroError: cannot find consistent MRO')
		}

		result << head or { panic('head is none') }

		// Remove head from all sequences
		for s in work_seqs {
			if s.len > 0 {
				h := head or { continue }
				if s[0] == h {
					s.delete(0)
				}
			}
		}
	}
}
