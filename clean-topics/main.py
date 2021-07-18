import requests
import sys
import os
import shutil
from pathlib import PosixPath

GITHUB_QUERY_FRAG = """_%s: pullRequests(first: 1, states: %s, baseRefName: "stable", headRefName: "%s", orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        number
        headRefName
      }
    }
"""
GITHUB_QUERY = """{
  repository(name: "aosc-os-abbs", owner: "AOSC-dev") {
    %s
  }
}"""


def main():
    root_path = PosixPath(sys.argv[1])
    if not root_path.is_dir():
        raise Exception(f'{root_path} is not a directory')
    topics = os.listdir(root_path)
    fragments = []
    index = 0
    for topic in topics:
        if topic == 'stable':
            continue
        if not root_path.joinpath(topic).is_dir():
            continue
        index += 1
        fragments.append(GITHUB_QUERY_FRAG % (index, 'MERGED', topic))
        index += 1
        fragments.append(GITHUB_QUERY_FRAG % (index, 'CLOSED', topic))
    query = GITHUB_QUERY % ('\n'.join(fragments))
    resp = requests.post('https://api.github.com/graphql', json={'query': query}, headers={
        'Authorization': 'bearer %s' % os.environ['GITHUB_TOKEN']})
    resp.raise_for_status()
    github_pr = resp.json()['data']['repository']
    closed = []
    for pr in github_pr.values():
        pr = pr['nodes']
        if not pr:
            continue
        pr = pr[0]
        print(f'#{pr["number"]}: closed {pr["headRefName"]}')
        closed.append(pr['headRefName'])
    for pr in closed:
        shutil.rmtree(root_path.joinpath(pr))
        print('Deleted: {}'.format(pr))


if __name__ == "__main__":
    main()
