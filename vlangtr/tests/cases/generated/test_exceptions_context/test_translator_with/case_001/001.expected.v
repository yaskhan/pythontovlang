@@in# "os.open(\"file.txt\")"
@@in# "defer { f.close() }"
@@in# "f := os.open"
@@in# "println('${py_file_read_all(mut f)}')"
