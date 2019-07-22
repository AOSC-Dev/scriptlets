#!/bin/python3

import sys
import os
import subprocess


def read_file(src_path):
    with open(src_path, "r") as f:
        return f.readlines()


def write_file(dest_path, contents):
    with open(dest_path, "w") as f:
        f.writelines(contents)


def get_pkgs(filename):
    contents = read_file(filename)
    pkgs = []
    for line in contents:
        if 'os-' in line:
            pkg = line.split('/')[0]
            pkgs.append(pkg)

    return pkgs


def find_spec(pkgname):
    print("Bump %s ..." % pkgname)
    result = subprocess.run(
        ['find', '.', '-name', pkgname], stdout=subprocess.PIPE)
    filepaths = result.stdout.decode('utf-8').split('\n')
    for f in filepaths:
        specfile = os.path.join(f, 'spec')
        if os.path.isfile(specfile):
            return specfile
    return None


def bump_rel(spec_path):
    orig_spec = read_file(spec_path)
    contents = []
    has_rel = False
    for line in orig_spec:
        if 'REL=' in line:
            cur_rel = line.split('=')[-1].strip()
            new_rel = str(int(cur_rel) + 1)
            contents.append(line.replace(cur_rel, new_rel))
            has_rel = True
        elif 'REL=' not in line:
            contents.append(line)

    if not has_rel:
        contents.insert(1, "REL=1\n")
    write_file(spec_path, contents)


if __name__ == "__main__":
    pkgs = get_pkgs(sys.argv[1])
    for pkg in pkgs:
        bump_rel(find_spec(pkg))
