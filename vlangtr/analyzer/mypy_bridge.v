module analyzer

pub struct MypyResult {
pub mut:
	stdout string
	stderr string
	exit_code int
}

pub struct TypeInferenceMypyMixin {
	TypeInferenceBase
}

pub fn new_type_inference_mypy_mixin() TypeInferenceMypyMixin {
	return TypeInferenceMypyMixin{
		TypeInferenceBase: new_type_inference_base()
	}
}

pub fn new_mypy_result() MypyResult {
	return MypyResult{
		stdout: ""
		stderr: ""
		exit_code: 1
	}
}

pub fn is_mypy_available() bool {
	return false
}
