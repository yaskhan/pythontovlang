import decimal

def calc():
    with decimal.localcontext() as ctx:
        ctx.prec = 50
        decimal.getcontext().prec = 50
        d = decimal.Decimal("3.14159")
