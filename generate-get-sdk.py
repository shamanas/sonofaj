#!/usr/bin/env python
import os

IGNORE = [
    'structs/RangeList',
]

if not 'OOC_SDK' in os.environ:
    raise Exception('You have to set $OOC_SDK')

sdk = os.environ['OOC_SDK']

def visit(root):
    root_len = len(root)
    for dirname, dirnames, fnames in os.walk(root):
        if dirname.startswith('.'):
            continue
        # all dirs are actually subdirs of `root`
        package_path = dirname[root_len:].replace(os.pathsep, '/').strip('/')
        for fname in fnames:
            if fname.endswith('.ooc'):
                modulename = package_path + '/' + fname[:-4]
                if modulename not in IGNORE:
                    yield modulename

with open('get-sdk.ooc', 'w') as f:
    for module in visit(sdk):
        f.write('import %s\n' % module)