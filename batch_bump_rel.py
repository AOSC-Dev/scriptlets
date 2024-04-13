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

def find_ver(pkg):
    out = subprocess.check_output(["apt", "show", pkg]).decode('utf-8')
    for line in out.split('\n'):
        if line.startswith('Version: '):
            return line.split(' ')[1]
    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                    prog='batch_bump_rel',
                    description='Bump REL of multiple packages in batch')
    parser.add_argument('reason', help='reason to bump REL')
    parser.add_argument('packages_file', help='a file containing the list of packages to bump')
    parser.add_argument('-b', '--pkg-break',
                    action='store_true')
    args = parser.parse_args()
    pkgs = get_pkgs(args.packages_file)
    pkgbreak = []
    for pkg in pkgs:
        if args.pkg_break:
            version = find_ver(pkg)
            if version is not None:
                pkgbreak.append(f'{pkg}<={version}')
        else:
            spec = find_spec(pkg)
            if spec is None:
                print(f'Package {pkg} not found!')
                os.exit(1)
            else:
                bump_rel(args.reason, pkg, spec)

    if args.pkg_break:
        # print PKGBREAK
        # handle newline automatically
        curline = "PKGBREAK=\""
        first = True
        for pkg in pkgbreak:
            if len(curline) + len(pkg) > 80:
                curline += " \\"
                print(curline)
                curline = "          "
                first = True
            if first:
                first = False
                curline += pkg
            else:
                curline += " "
                curline += pkg
        curline += "\""
        print(curline)

