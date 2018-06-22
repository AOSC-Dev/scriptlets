#!/bin/python3
"""
TODO: Add ignored list
"""

import argparse
import urllib.request
import subprocess
import sys
import os
import json


def read_file(src_path):
    with open(src_path, "r") as f:
        return f.readlines()


def write_file(dest_path, contents):
    with open(dest_path, "w") as f:
        f.writelines(contents)


def get_json_from_file(local_file):
    with open(local_file, "r") as f:
        json_file = f.read()
        jsonsrc = json.loads(json_file)
        return jsonsrc


def get_json_from_url(repology_url):
    with urllib.request.urlopen(repology_url) as url:
        jsonsrc = json.loads(url.read().decode())
    return jsonsrc


def get_pkg_tuple(jsonsrc):
    result = []
    for pkg in jsonsrc:
        newest_ver = ''
        pkg_name = ''
        for repo in jsonsrc[pkg]:
            if 'aosc' in repo['repo']:
                pkg_name = repo['name']
            if 'newest' in repo['status']:
                newest_ver = repo['version']
        result.append((pkg_name, newest_ver))
    return result


def find_newest_pkgs(jsonfile=None, jsonurl=None, dumpfile=None):
    result = []
    dumpjson = {}

    if jsonfile is not None:
        jsonsrc = get_json_from_file(jsonfile[0])
        return get_pkg_tuple(jsonsrc)
    elif jsonurl is not None:
        jsonsrc = get_json_from_url(base_url + filter_url)
    else:
        base_url = "https://repology.org/api/v1/metapackages/"
        filter_url = "?inrepo=aosc&outdated=True"
        jsonsrc = get_json_from_url(base_url + filter_url)

    while True:
        dumpjson = {**dumpjson, **jsonsrc}
        result.extend(get_pkg_tuple(jsonsrc))
        if len(jsonsrc) == 1:
            if dumpfile:
                with open(dumpfile[0], "w") as f:
                    f.write(json.dumps(dumpjson))
            return result
        else:
            last_pkg = sorted(jsonsrc.keys())[-1]
            jsonsrc = get_json_from_url(base_url + last_pkg + filter_url)


def find_spec(pkgname):
    result = subprocess.run(
        ['find', '.', '-name', pkgname + '*'], stdout=subprocess.PIPE)
    filepaths = result.stdout.decode('utf-8').split('\n')
    for f in filepaths:
        specfile = os.path.join(f, 'spec')
        if os.path.isfile(specfile):
            return specfile
    return None


def find_cur_ver(spec_path, new_ver):
    orig_spec = read_file(spec_path)
    contents = []
    cur_ver = ''
    for line in orig_spec:
        if 'VER=' in line:
            cur_ver = line.split('=')[-1].strip()
            contents.append(line.replace(cur_ver, new_ver))
        elif 'REL=' not in line:
            contents.append(line)

    write_file(spec_path, contents)
    return cur_ver


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-j', '--json', nargs=1, metavar='JSONFILE', help='Parse JSON file.')
    parser.add_argument(
        '-d', '--dump', nargs=1, metavar='JSONFILE', help='Dump JSON files.')
    parser.add_argument(
        '-c',
        '--contain',
        nargs=1,
        metavar='directory',
        help='replace specs in this directory.')
    parser.add_argument(
        '-r',
        '--replace',
        action='store_true',
        help='Replace REPO with new version.')

    args = parser.parse_args()

    print("Found outdated pkgs...")
    newest_pkgs = find_newest_pkgs(
        jsonfile=args.json, jsonurl=None, dumpfile=args.dump)
    print(len(newest_pkgs))

    if not args.replace:
        sys.exit(0)
    for pkg in newest_pkgs:
        pkg_path = find_spec(pkg[0])
        if pkg_path is None:
            print("WARNING pkg: %s is invalid" % pkg[0])
        elif args.contain[0] in pkg_path:
            print(pkg[0], pkg_path, find_cur_ver(pkg_path, pkg[1]), '->',
                  pkg[1])
