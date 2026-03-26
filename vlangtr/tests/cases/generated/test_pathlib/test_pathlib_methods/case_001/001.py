from pathlib import Path
p = Path("foo")
if p.exists():
    pass
if p.is_file():
    pass
if p.is_dir():
    pass
