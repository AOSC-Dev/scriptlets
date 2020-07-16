#!/usr/bin/env python3
import requests
import os
import sys
import re
import html5lib
import logging
import semver
import subprocess

from typing import List, Dict

# $1: package name $2: version string
matching_patt = r'(.*?)-(\d.*?).zh_CN'
po_dl_url = 'https://translationproject.org/PO-files/{lang}/{fn}'
po_name = '{pkg}-{ver}.{lang}.po'
domain_url = 'https://translationproject.org/domain/index.html'


def collect_local_info(dirname: str):
    files = []
    for f in os.listdir(dirname):
        if not os.path.isfile(os.path.join(dirname, f)):
            continue
        if not f.endswith('.po'):
            continue
        matched = re.search(matching_patt, f)
        if not matched:
            continue
        domain = matched.groups()
        if len(domain) != 2:
            continue
        files.append(tuple(domain))
    return files


def collect_remote_info() -> Dict[str, str]:
    parser = html5lib.HTMLParser(tree=html5lib.getTreeBuilder("dom"))
    domain_data = requests.get(domain_url)
    parsed = parser.parse(domain_data.text)
    nodes = parsed.getElementsByTagName('tbody')[0]
    nodes = nodes.childNodes
    head = True
    remote_data = {}
    for node in nodes:
        if node.nodeType == 3:
            continue
        if head:
            head = False
            continue
        # node <tr> -> <td> -> <a> -> text node
        pkg_name = node.childNodes[1].childNodes[0].childNodes[0].nodeValue
        pkg_ver = node.childNodes[3].childNodes[0].childNodes[0].nodeValue
        remote_data[pkg_name] = pkg_ver
    return remote_data


def download_po(pkg, ver, lang, folder='.'):
    po_file = po_name.format(pkg=pkg, ver=ver, lang=lang)
    po_url = po_dl_url.format(lang=lang, fn=po_file)
    logging.warning('Downloading %s...' % po_file)
    resp = requests.get(po_url)
    if resp.status_code not in range(200, 300):
        logging.error('Download error: %s' % resp.status_code)
        return
    with open(os.path.join(folder, po_file), 'wt') as f:
        f.write(resp.text)


def main():
    if len(sys.argv) < 2:
        print('%s <dir to translations>' % sys.argv[0])
        sys.exit(1)
    logging.warning('Scanning files...')
    local = collect_local_info(sys.argv[1])
    logging.warning('Fetching remote data...')
    remote = collect_remote_info()
    for f in local:
        remote_ver = remote.get(f[0])
        if not remote_ver:
            logging.error('Local file %s not found in remote data' % f[0])
            continue
        if f[1] == remote_ver:
            continue
        try:
            if semver.compare(f[1], remote_ver) >= 0:
                logging.info('Local file %s is up to date' % f[0])
                continue
        except ValueError:
            pass
        download_po(f[0], remote_ver, 'zh_CN', sys.argv[1])
        po_file = po_name.format(pkg=f[0], ver=f[1], lang='zh_CN')
        po_file = os.path.join(sys.argv[1], po_file)
        pot_file = po_name.format(pkg=f[0], ver=remote_ver, lang='zh_CN')
        pot_file = os.path.join(sys.argv[1], pot_file)
        if not subprocess.call(['msgmerge', po_file, pot_file, '-o', pot_file]):
            os.remove(po_file)


if __name__ == '__main__':
    main()
