def outer():
    try:
        def nested():
            pass
        print("try")
    except:
        print("except")
    else:
        print("else")
