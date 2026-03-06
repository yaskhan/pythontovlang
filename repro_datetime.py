import datetime

def test_datetime():
    now = datetime.datetime.now()
    today = datetime.date.today()
    dt = datetime.datetime(2023, 10, 27, 12, 0, 0)
    d = datetime.date(2023, 10, 27)
    print(now, today, dt, d)
