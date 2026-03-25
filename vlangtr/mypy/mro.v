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
// Returns a list of TypeInfo pointers representing the MRO.
pub fn linearize_hierarchy(info &TypeInfo) ![]&TypeInfo {
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

	mut lin_bases := [][]&TypeInfo{}
	for base in base_infos {
		lin_bases << linearize_hierarchy(base)!
	}

	// Add the list of direct base class pointers
	lin_bases << base_infos

	mut res := [&TypeInfo(info)]
	res << merge_mro(lin_bases)
	return res
}

// merge_mro merges multiple sequences into a single linearized order using C3 linearization.
pub fn merge_mro(seqs [][]&TypeInfo) []&TypeInfo {
	mut work_seqs := seqs.clone()
	mut result := []&TypeInfo{}

	for {
		// Remove empty sequences
		mut active_seqs := [][]&TypeInfo{}
		for s in work_seqs {
			if s.len > 0 {
				active_seqs << s
			}
		}
		
		if active_seqs.len == 0 {
			break
		}
		
		work_seqs = active_seqs.clone()

		mut head := voidptr(0)
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
				if s.len > 1 {
					for item in s[1..] {
						if item.fullname == candidate.fullname {
							appears_in_tail = true
							break
						}
					}
				}
				if appears_in_tail {
					break
				}
			}

			if !appears_in_tail {
				head = voidptr(candidate)
				found = true
				break
			}
		}

		if !found {
			// Cannot find a valid head — MRO conflict
			panic('MroError: cannot find consistent MRO')
		}

		h := unsafe { &TypeInfo(head) }
		result << h

		// Remove head from all sequences
		for i in 0 .. work_seqs.len {
			if work_seqs[i].len > 0 {
				if work_seqs[i][0].fullname == h.fullname {
					work_seqs[i].delete(0)
				}
			}
		}
	}
	return result
}
