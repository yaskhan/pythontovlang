// version.v — Version information for mypy
// Translated from mypy/version.py to V 0.5.x
//
// Work in progress by Cline. Started: 2026-03-22 09:06
//
// Translation notes:
//   - __version__: base version string
//   - base_version: same as __version__
//   - Simplified version without git integration

module mypy

// ---------------------------------------------------------------------------
// Version constants
// ---------------------------------------------------------------------------

// Base version.
// - Release versions have the form "1.2.3".
// - Dev versions have the form "1.2.3+dev" (PLUS sign to conform to PEP 440).
// - Before 1.0 we had the form "0.NNN".
pub const version = '1.20.0+dev'

// base_version is the same as version
pub const base_version = version
