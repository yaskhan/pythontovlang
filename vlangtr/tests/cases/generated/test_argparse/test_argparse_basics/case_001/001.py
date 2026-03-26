import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--foo')
args = parser.parse_args()
print(args.foo)
