import sqlite3
conn = sqlite3.connect('test.db')
c = conn.cursor()
c.execute('CREATE TABLE stocks (date text, trans text, symbol text, qty real, price real)')
conn.commit()
conn.close()
