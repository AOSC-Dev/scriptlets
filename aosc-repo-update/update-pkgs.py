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


def dump_json(d, d_file):
    json.dump(d, open(d_file, 'w'))


def load_json(load_file):
    return json.load(open(load_file))


def get_json_from_file(local_file):
    with open(local_file, "r") as f:
        json_file = f.read()
        jsonsrc = json.loads(json_file)
        return jsonsrc


def get_json_from_url(repology_url):
    print(repology_url)
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


def get_pkg_tuple_aosc(jsonsrc):
    result = []
    for pkg in jsonsrc["packages"]:
        newest_ver = pkg["upstream_version"]
        pkg_name = pkg["name"]
        result.append((pkg_name, newest_ver))

    return result


def find_newest_pkgs(jsonfile=None, jsonurl=None, dumpfile=None):
    result = []
    dumpjson = {}

    if jsonfile is not None:
        jsonsrc = get_json_from_file(jsonfile[0])
        if "packages" in jsonsrc:
            return get_pkg_tuple_aosc(jsonsrc)
        else:
            return get_pkg_tuple(jsonsrc)
    elif jsonurl is not None:
        jsonsrc = get_json_from_url(jsonurl[0])
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
        ['find', '.', '-name', pkgname], stdout=subprocess.PIPE)
    filepaths = result.stdout.decode('utf-8').split('\n')
    for f in filepaths:
        specfile = os.path.join(f, 'spec')
        if os.path.isfile(specfile):
            return specfile
    return None


def find_cur_ver(spec_path, new_ver, only_patch=False):
    orig_spec = read_file(spec_path)
    contents = []
    cur_ver = ''
    for line in orig_spec:
        if 'VER=' in line:
            cur_ver = line.split('=')[-1].strip()
            contents.append(line.replace(cur_ver, new_ver))
        elif 'REL=' not in line:
            contents.append(line)

    cur_ver_list = cur_ver.split('.')
    new_ver_list = new_ver.split('.')
    if not only_patch:
        write_file(spec_path, contents)
        return cur_ver
    else:
        if len(cur_ver_list) == len(new_ver_list) and len(cur_ver_list) > 2 and cur_ver_list[:-1] == new_ver_list[:-1]:
            write_file(spec_path, contents)
            return cur_ver
        else:
            return None



def classify(newest_pkgs, quite=None):
    classify_dict = {}
    for pkg in newest_pkgs:
        pkg_path = find_spec(pkg[0])
        if pkg_path is None:
            if not quite:
                print("WARNING pkg: %s is invalid" % pkg[0])
        else:
            category = pkg_path.split('/')[1]
            if category in classify_dict:
                classify_dict[category].append((pkg[0], pkg[1]))
            else:
                classify_dict[category] = []
    # for k in classify_dict:
    #     print(k, len(classify_dict[k]))
    #     for i in classify_dict[k]:
    #         print(i, end='')
    #     print()
    return classify_dict


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-j', '--json', nargs=1, metavar='JSONFILE', help='Parse JSON file.')
    parser.add_argument(
        '-d', '--dump', nargs=1, metavar='JSONFILE', help='Dump JSON files.')
    parser.add_argument(
        '-l', '--load', nargs=1, metavar='CACHEFILE', help='Load Cache file.')
    parser.add_argument(
        '-s', '--save', nargs=1, metavar='CACHEFILE', help='Save Cache files.')
    parser.add_argument('-u', '--url', nargs=1, metavar='URL', help='URL.')
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
    parser.add_argument(
        '-p',
        '--patch',
        action='store_true',
        help='Replace REPO with patc\'s version.')
    parser.add_argument(
        '-q', '--quite', action='store_true', help='Ignore WARNING')

    args = parser.parse_args()

    print("Found outdated pkgs...")

    if args.load is not None:
        with open(args.load[0], "r") as f:
            cache_file = f.read()
            cache_src = json.loads(cache_file)
            if args.contain is not None:
                if args.contain[0] in cache_src:
                    newest_pkgs = cache_src[args.contain[0]]
                else:
                    print("%s already newest!" % args.contain[0])
                    sys.exit(0)
            else:
                newest_pkgs = []
                for k in cache_src.keys():
                    newest_pkgs.extend(cache_src[k])
    else:
        newest_pkgs = find_newest_pkgs(
            jsonfile=args.json, jsonurl=args.url, dumpfile=args.dump)

    print(len(newest_pkgs))

    if args.save is not None:
        dump_json(classify(newest_pkgs), args.save[0])

    if not args.replace:
        sys.exit(0)
    for pkg in newest_pkgs:
        pkg_path = find_spec(pkg[0])
        if pkg_path is None:
            if not args.quite:
                print("WARNING pkg: %s is invalid" % pkg[0])
        elif args.contain is not None:
            if args.contain[0] in pkg_path:
                new_ver = find_cur_ver(pkg_path, pkg[1], args.patch)
                if new_ver:
                    print(pkg[0], pkg_path, new_ver, '->', pkg[1])
        else:
            new_ver = find_cur_ver(pkg_path, pkg[1], args.patch)
            if new_ver:
                print(pkg[0], pkg_path, new_ver, '->', pkg[1])
