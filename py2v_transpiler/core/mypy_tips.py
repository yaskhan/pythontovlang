
import re

MYPY_TIPS = {
    "union-attr": "In V, you must explicitly check the type (e.g., using `if x is Type`) before accessing a union attribute.",
    "arg-type": "In V, function arguments are strictly typed. Ensure the passed value matches the expected type or use a sum type.",
    "return-value": "V requires the return value to strictly match the function signature.",
    "assignment": "V is statically typed; ensure the variable type matches the value being assigned. Re-assignments to different types are not allowed.",
    "index": "V array indices must be integers. Map keys must match the declared key type.",
    "attr-defined": "Ensure the struct field or method exists in the V definition. V does not allow dynamic attribute addition.",
    "operator": "V is strict about operand types. Ensure both sides of the operator have compatible types.",
    "call-arg": "V function calls must match the exact number of defined parameters. Optional arguments in Python are often handled via Optionals or default values in V.",
    "name-defined": "In V, all variables and functions must be declared before use or be visible in the current module scope.",
    "variance": "Variance violation detected. Python 3.13+ PEP 695 variance modifiers must be strictly followed in generic definitions.",
    "misc": {
        "TypeForm": "Experimental feature 'TypeForm' detected. Use --experimental flag if supported, or simplify the type usage for V compatibility."
    }
}

def get_mypy_tips(mypy_output: str) -> str:
    """
    Parses mypy output and returns a formatted string of V-specific tips
    based on the error codes found.
    """
    if not mypy_output:
        return ""

    found_codes = set(re.findall(r"\[([a-z-]+)\]", mypy_output))
    tips = []

    for code in sorted(found_codes):
        if code in MYPY_TIPS:
            tip = MYPY_TIPS[code]
            if isinstance(tip, dict):
                # Special handling for 'misc' or other multi-context codes
                for subkey, subtip in tip.items():
                    if subkey in mypy_output:
                        tips.append(f"- [{code}] {subtip}")
            else:
                tips.append(f"- [{code}] {tip}")

    if not tips:
        return ""

    return "\nV-specific tips for found Mypy errors:\n" + "\n".join(tips) + "\n"
