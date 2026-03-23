// state.v — Global mutable state for mypy
// Translated from mypy/state.py to V 0.5.x
//
// I, Cline, am working on this file. Started: 2026-03-22 08:28
//
// Translation notes:
//   - StrictOptionalState: wraps strict_optional flag
//   - state: global instance of StrictOptionalState
//   - find_occurrences: global variable for occurrence tracking

module mypy

// ---------------------------------------------------------------------------
// StrictOptionalState
// ---------------------------------------------------------------------------

// StrictOptionalState wraps strict_optional flag since it's faster than using
// a module-level attribute.
pub struct StrictOptionalState {
pub mut:
	// Value varies by file being processed
	strict_optional bool
}

// new_strict_optional_state creates a new StrictOptionalState
pub fn new_strict_optional_state(strict_optional bool) StrictOptionalState {
	return StrictOptionalState{
		strict_optional: strict_optional
	}
}

// strict_optional_set enters a context with a specific strict_optional value
pub fn (mut s StrictOptionalState) strict_optional_set(value bool) StrictOptionalStateContext {
	return StrictOptionalStateContext{
		state: s
		saved: s.strict_optional
		value: value
	}
}

// ---------------------------------------------------------------------------
// StrictOptionalStateContext
// ---------------------------------------------------------------------------

// StrictOptionalStateContext manages the strict_optional context
pub struct StrictOptionalStateContext {
mut:
	state StrictOptionalState
	saved bool
	value bool
}

// enter enters the context
pub fn (mut ctx StrictOptionalStateContext) enter() {
	ctx.state.strict_optional = ctx.value
}

// leave leaves the context
pub fn (mut ctx StrictOptionalStateContext) leave() {
	ctx.state.strict_optional = ctx.saved
}

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

// state is the global instance of StrictOptionalState
__global state = new_strict_optional_state(true)

// find_occurrences is a global variable for occurrence tracking
__global find_occurrences ?(string, string)
