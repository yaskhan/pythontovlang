module base

// TranslatorBase is a thin holder for shared translator state.
pub struct TranslatorBase {
pub mut:
	state TranslatorState
}

pub fn new_translator_base() TranslatorBase {
	return TranslatorBase{
		state: new_translator_state()
	}
}
