import struct
buf = b'\x01\x00\x00\x00'
val = struct.unpack('<I', buf)
