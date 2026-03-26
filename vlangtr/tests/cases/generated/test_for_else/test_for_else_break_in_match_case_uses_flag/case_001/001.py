for i in range(10):
    match i:
        case 5:
            break
        case _:
            pass
else:
    print('match done')
