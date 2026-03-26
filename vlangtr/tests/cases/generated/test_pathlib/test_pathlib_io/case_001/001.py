from pathlib import Path
p = Path("foo.txt")
text = p.read_text()
p.write_text("hello")
