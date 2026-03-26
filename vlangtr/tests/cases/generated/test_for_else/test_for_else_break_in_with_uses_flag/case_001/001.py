import contextlib
for i in range(10):
    with contextlib.suppress(Exception):
        if i == 5:
            break
else:
    print('done')
