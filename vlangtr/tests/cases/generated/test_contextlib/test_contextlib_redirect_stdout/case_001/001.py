import contextlib
import io
f = io.StringIO()
with contextlib.redirect_stdout(f):
    print('foobar')
