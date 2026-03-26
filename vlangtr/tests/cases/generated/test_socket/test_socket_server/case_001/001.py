import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('localhost', 8080))
s.listen(5)
conn, addr = s.accept()
data = conn.recv(1024)
conn.send(data)
conn.close()
