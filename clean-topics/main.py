import requests
import sys
import os
import shutil
from pathlib import PosixPath


def collect_all_branches():
    page = 1
    branches = []
    while True:
        print(f'Reading page {page} ...')
        resp = requests.get(f'https://api.github.com/repos/AOSC-Dev/aosc-os-abbs/branches?per_page=100&page={page}', headers={
            'Authorization': f'bearer {os.environ["GITHUB_TOKEN"]}'})
        resp.raise_for_status()
        b = resp.json()
        branches.extend(b)
        if len(b) == 100:
            page += 1
            continue
        else:
            break
    return branches


def main():
    root_path = PosixPath(sys.argv[1])
    if not root_path.is_dir():
        raise Exception(f'{root_path} is not a directory')
    topics = os.listdir(root_path)
    print('Reading topics list ...')
    branches = collect_all_branches()
    print('Done reading topics list.')
    branches_lookup = set([i['name'] for i in branches])
    print(f'Found {len(branches_lookup)} branches.')
    closed = []
    for topic in topics:
        if topic == 'stable' or topic.startswith('.'):
            continue
        topic_path = root_path.joinpath(topic)
        if not topic_path.is_dir():
            continue
        if topic not in branches_lookup:
            if not topic_path.joinpath('DEPRECATED').is_file():
                with open(topic_path.joinpath('DEPRECATED'), 'wb') as f:
                    f.write(b'WARNING: This topic will be deleted.\n')
                print(f'Warning marker set: {topic}')
                continue
            closed.append(topic)
    for pr in closed:
        shutil.rmtree(root_path.joinpath(pr))
        print('Deleted: {}'.format(pr))


if __name__ == "__main__":
    main()
