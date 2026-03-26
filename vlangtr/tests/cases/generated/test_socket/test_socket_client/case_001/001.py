import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('localhost', 8080))
s.send(b'hello')
data = s.recv(1024)
s.close()
