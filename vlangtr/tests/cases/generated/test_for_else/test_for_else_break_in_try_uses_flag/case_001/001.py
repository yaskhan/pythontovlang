for i in range(10):
    try:
        if i == 5:
            break
    except Exception:
        pass
else:
    print('done')
