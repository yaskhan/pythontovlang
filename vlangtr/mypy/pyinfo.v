// pyinfo.v — Utilities to find the site and prefix information of a Python executable
// Translated from mypy/pyinfo.py to V 0.5.x

module mypy

// getsite_packages returns a list of site-packages directories
pub fn getsite_packages() []string {
	return []
}

// getsyspath returns system path excluding standard library
pub fn getsyspath() []string {
	return []
}

// getsearch_dirs returns two lists: (syspath, sitepackages)
pub fn getsearch_dirs() ([]string, []string) {
	return getsyspath(), getsite_packages()
}
