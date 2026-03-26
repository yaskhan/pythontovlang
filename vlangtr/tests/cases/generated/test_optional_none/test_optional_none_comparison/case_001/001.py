from typing import Optional

class Packet:
    def __init__(self, d: int):
        self.datum = d

class Task:
    def __init__(self, p: Optional[Packet] = None):
        self.work_in = p

def run():
    h = Task()
    work = h.work_in
    if work is None:
        return
    print(work.datum)
