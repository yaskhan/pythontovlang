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
pub fn calculate_mro(mut info TypeInfo) ! {
	mro := linearize_hierarchy(&info)!
	assert mro.len > 0, 'Could not produce a MRO at all for ${info.name}'
	info.mro = mro
}

// linearize_hierarchy linearizes the hierarchy for MRO calculation.
// Returns a list of fullname strings representing the MRO.
pub fn linearize_hierarchy(info &TypeInfo) ![]string {
	// If already computed, return cached
	if info.mro.len > 0 {
		return info.mro
	}

	// Collect direct base classes from the bases field ([]Instance)
	mut base_infos := []&TypeInfo{}
	for b in info.bases {
		if bi := b.typ {
			base_infos << bi
		}
	}

	mut lin_bases := [][]string{}
	for base in base_infos {
		lin_bases << linearize_hierarchy(base)!
	}

	// Add the list of direct base class names
	mut base_names := []string{}
	for base in base_infos {
		base_names << base.fullname
	}
	lin_bases << base_names

	return [info.fullname] + merge(lin_bases)
}

// merge merges multiple sequences into a single linearized order using C3 linearization.
pub fn merge(seqs [][]string) []string {
	mut work_seqs := seqs.clone()
	mut result := []string{}

	for {
		// Remove empty sequences
		work_seqs = work_seqs.filter(it.len > 0)

		if work_seqs.len == 0 {
			return result
		}

		mut head := ?string(none)
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
		for mut s in work_seqs {
			if s.len > 0 {
				h := head or { continue }
				if s[0] == h {
					s.delete(0)
				}
			}
		}
	}
}
