import threading
def worker():
    pass
t = threading.Thread(target=worker)
t.start()
t.join()
