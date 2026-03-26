import hashlib
h = hashlib.md5()
h.update(b"hello")
d = h.hexdigest()
