@@in# "import os"
@@in# "f := os.open('data.json')"
@@in# "defer { f.close() }"
@@in# "data := py_file_read_all(mut f)"
