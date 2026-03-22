// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 21:00
// Version information for mypy (version.py)

module mypy

// Base version.
// - Release versions have the form "1.2.3".
// - Dev versions have the form "1.2.3+dev" (PLUS sign to conform to PEP 440).
// - Before 1.0 we had the form "0.NNN".
pub const version = '1.20.0+dev'
pub const base_version = version

// VersionInfo represents version components.
pub struct VersionInfo {
pub mut:
	major int
	minor int
	patch int
	dev   bool
}

// parse_version parses a version string into VersionInfo.
pub fn parse_version(v string) ?VersionInfo {
	mut major := 0
	mut minor := 0
	mut patch := 0
	mut dev := false

	parts := v.split('+')
	if parts.len > 1 {
		dev = parts[1] == 'dev'
	}

	num_parts := parts[0].split('.')
	if num_parts.len >= 1 {
		major = num_parts[0].int() or { return none }
	}
	if num_parts.len >= 2 {
		minor = num_parts[1].int() or { return none }
	}
	if num_parts.len >= 3 {
		patch = num_parts[2].int() or { return none }
	}

	return VersionInfo{
		major: major
		minor: minor
		patch: patch
		dev:   dev
	}
}

// version_string returns the version as a string.
pub fn (v VersionInfo) version_string() string {
	base := '${v.major}.${v.minor}.${v.patch}'
	if v.dev {
		return base + '+dev'
	}
	return base
}

// compare_versions compares two version strings.
// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
pub fn compare_versions(v1 string, v2 string) int {
	vi1 := parse_version(v1) or { return 0 }
	vi2 := parse_version(v2) or { return 0 }

	if vi1.major != vi2.major {
		return if vi1.major < vi2.major { -1 } else { 1 }
	}
	if vi1.minor != vi2.minor {
		return if vi1.minor < vi2.minor { -1 } else { 1 }
	}
	if vi1.patch != vi2.patch {
		return if vi1.patch < vi2.patch { -1 } else { 1 }
	}
	// Dev versions are considered older than release versions
	if vi1.dev != vi2.dev {
		return if vi1.dev { -1 } else { 1 }
	}
	return 0
}

// is_dev_version checks if the current version is a dev version.
pub fn is_dev_version() bool {
	return version.ends_with('+dev')
}
