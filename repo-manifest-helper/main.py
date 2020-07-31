import yaml
import logging
import requests
import os
import threading
import sys

from typing import Optional


def load_config(config: str) -> dict:
    with open(config, 'rt') as f:
        return yaml.safe_load(f)


def test_mirror(mirror: dict, results: list):
    logging.info('Testing mirror %s...' % mirror['name'])
    try:
        requests.get(os.path.join(
            mirror['url'], 'aosc-os'), timeout=10).raise_for_status()
        results.append(mirror)
    except Exception:
        return None


def test_mirrors(config: dict) -> list:
    valid_mirrors = []
    for i in config['mirrors']:
        test_mirror(i, valid_mirrors)
    return valid_mirrors


def guess_mirror_slug(mirror: dict) -> Optional[str]:
    def find_char(i):
        name_lower = name.lower()
        for j in names[i]:
            if name_lower.find(j.lower()) < 0:
                return False
        return True
    name: str = mirror['name']
    hostname = mirror['url'].split('://', 1)[1]
    hostname = hostname.split('/', 1)[0]
    names = hostname.split('.')
    slug = None
    for i in range(1, len(names) - 1):
        if find_char(i):
            slug = names[i]
            break
    return slug


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    candidates = test_mirrors(load_config(sys.argv[1]))
    for i in candidates:
        slug = guess_mirror_slug(i)
        if not slug:
            logging.warning("Unable to guess the slug for %s" % i['name'])
        print("[[mirrors]]\nname = \"%s\"\nname-tr = \"%s\"\nurl = \"%s\"\nloc = \"%s\"\nloc-tr = \"%s\"\n\n" % (
            i['name'], slug + '-name' if slug else '', i['url'], i['region'], slug +
            '-loc' if slug else ''
        ))
