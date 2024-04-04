#!/usr/bin/env python3
# bump REL of packages in batch
# usage: run the following command in abbs tree
# python3 batch_bump_rel.py "openldap SONAME change" ../packages.txt

import re
import sys
import os
import subprocess
import argparse


def get_pkgs(filename):
    pkgs = []
    with open(filename, "r") as f:
        for line in f:
            for part in line.replace(',', ' ').split(' '):
                part = part.strip()
                if len(part) > 0:
                    pkgs.append(part)

    return pkgs


def find_spec(pkgname):
    print(f"Bump {pkgname} ...")
    result = subprocess.run(
        ['find', '.', '-name', pkgname], stdout=subprocess.PIPE)
    filepaths = result.stdout.decode('utf-8').split('\n')
    for f in filepaths:
        specfile = os.path.join(f, 'spec')
        if os.path.isfile(specfile):
            return specfile
    return None


def bump_rel(reason, name, spec_path):
    contents = []
    has_rel = False
    with open(spec_path, "r") as f:
        for line in f:
            if 'REL=' in line:
                cur_rel = line.split('=')[-1].strip()
                # https://stackoverflow.com/a/17888240/2148614
                int_rel = int(re.compile("(\d+)").match(cur_rel).group(1))
                new_rel = str(int_rel + 1)
                contents.append(line.replace(cur_rel, new_rel))
                has_rel = True
            elif 'REL=' not in line:
                contents.append(line)

    if not has_rel:
        contents.insert(1, "REL=1\n")
    with open(spec_path, "w") as f:
        f.writelines(contents)

    os.system("git add .")
    os.system(f"git commit -m \"{name}: bump REL due to {reason}\"")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                    prog='batch_bump_rel',
                    description='Bump REL of multiple packages in batch')
    parser.add_argument('reason', help='reason to bump REL')
    parser.add_argument('packages_file', help='a file containing the list of packages to bump')
    args = parser.parse_args()
    pkgs = get_pkgs(args.packages_file)
    for pkg in pkgs:
        spec = find_spec(pkg)
        if spec is None:
            print(f'Package {pkg} not found, skipped')
        else:
            bump_rel(args.reason, pkg, spec)

