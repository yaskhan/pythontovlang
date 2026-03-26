def test_inner():
    flag = False
    try:
        try:
            try:
                raise RuntimeError("invalid country NZ")
            except Exception:
                pass
        except Exception:
            pass
        raise Exception("")
    except Exception:
        flag = True
