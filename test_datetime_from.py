from datetime import datetime, date

def test_datetime_from():
    now = datetime.now()
    dt = datetime(2023, 10, 27, 12, 0, 0)
    d = date(2023, 10, 27)
    print(now, dt, d)
