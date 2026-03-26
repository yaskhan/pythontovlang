import http.client
conn = http.client.HTTPConnection("example.com")
conn.request("GET", "/")
resp = conn.getresponse()
data = resp.read()
