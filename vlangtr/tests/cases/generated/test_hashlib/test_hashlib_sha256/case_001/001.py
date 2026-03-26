import hashlib
h = hashlib.sha256(b"hello")
h.update(b"world")
d = h.hexdigest()
