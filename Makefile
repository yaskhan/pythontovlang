.PHONY: test mypy-stubs test-all

test:
	pytest

mypy-stubs:
	python py2v_transpiler/tests/scripts/generate_mypy_stubs_tests.py
	@echo "Checking generated mypy stubs..."
	@find py2v_transpiler/tests/output/mypy_stubs -mindepth 1 -type d | while read -r dir; do \
		echo "Checking $$dir"; \
		v -check "$$dir" || true; \
	done

test-all: test mypy-stubs
