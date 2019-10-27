import requests
import datetime
import fnmatch
import re
import logging
from github import Github, Label

REPO_NAME = 'AOSC-Dev/aosc-os-abbs'
TARGET_LABEL = 'security'
AFTER_DATE = datetime.datetime(2019, 6, 1, 0, 0, 0)
CVE_PATTERN = r'(?:\*\*)?CVE IDs:(?:\*\*)?\s*((?:(?!\n\n).)*)'
ARCH_PATTERN = r'(?:\*\*)?Architectural progress:(?:\*\*)?\s*((?:(?!\n\n).)*)'
OTHER_PATTERN = r'(?:\*\*)?Other security advisory IDs:(?:\*\*)?\s*((?:(?!\n\n).)*)'
AOSA_PATTERN = r'(AOSA-\d{4}-\d+)'
REFERENCE_REPO = 'https://packages.aosc.io/repo/amd64/stable?page=all&type=json'
HEAD_TEMPLATE = """Hi all,

Here below is a comprehensive list of AOSC OS Security Advisories announced in the period between {date_start} and {date_end}. This is the 1st issue/batch of security advisories announced here for {date_month} on the security mailing list.

Please update your system at your earliest convenience!

"""


def minimatch(names, pattern):
    actual_pattern = pattern.replace('{', '[').replace('}', ']')
    return fnmatch.filter(names, actual_pattern)


def get_updated_version_simple(issue):
    title = issue.title
    if title.find('to') > 0:
        return title.split('to')[-1].strip(' ^')
    return None


def get_updated_version_timeline(issue):
    # TODO: deduce patched version from Git commits
    pass


def get_updated_version_guess(issue):
    names = get_expanded_names(issue, packages)
    def fetch_version(name):
        logging.warning('%s: Using heuristics to determine patched version' % name)
        # dangerous escaping...
        data = {
            'q': "select epoch, version, release from package_versions where commit_time < strftime('%s', 'now', '-1 days') and package = '{}' and (branch = 'stable' or branch = 'stable-proposed') order by epoch, version, release desc;".format(name)}
        resp = requests.post("https://packages.aosc.io/query/",
                            data=data, headers={'X-Requested-With': 'XMLHttpRequest'})
        resp.raise_for_status()
        resp = resp.json()['rows']
        if not resp:
            return
        resp = resp[0]
        version = ''
        if resp[0]:
            version = resp[0] + ':'
        version += resp[1]
        if resp[2]:
            version += '-' + resp[2]
        return version
    return ', '.join([fetch_version(name) for name in names])


def get_updated_version(issue):
    for method in [get_updated_version_simple, get_updated_version_timeline, get_updated_version_guess]:
        result = method(issue)
        if result:
            return result
    return None


def get_bulletin_number(issue):
    body = issue.body
    numbers = []
    result = re.search(CVE_PATTERN, body)
    if result:
        cve = result.group(1).strip().replace('N/A', '')
        if cve:
            numbers.append(cve)
    result = re.search(OTHER_PATTERN, body)
    if result:
        other = result.group(1).strip().replace('N/A', '')
        if other:
            numbers.append(other)
    return numbers


def get_aosa_number(issue):
    aosa = None
    for page in range(issue.get_comments().totalCount):
        for comment in issue.get_comments().get_page(page):
            result = re.search(AOSA_PATTERN, comment.body)
            if result:
                aosa = result.group(1).strip()
    return aosa


def get_issues_after(date: datetime.datetime, repo, label):
    issues = []
    page = 0
    while True:
        finish = False
        page = repo.get_issues(state='closed', labels=[label]).get_page(page)
        for issue in page:
            if issue.created_at >= date:
                issues.append(issue)
                continue
            finish = True
            break
        if finish:
            break
    return issues


def get_expanded_names(issue, packages):
    pattern = issue.title.split(': ')[0]
    return minimatch(packages, pattern) or [pattern]


def generate_head(start, end):
    return HEAD_TEMPLATE.format(date_start=start.strftime('%B %-d'), date_end=end.strftime('%B %-d'), date_month=end.strftime('%B of %Y'))


def main():
    logging.info('Fetching issues from GitHub...')
    gh = Github(base_url="https://api.github.com",
                login_or_token='')
    repo = gh.get_repo(REPO_NAME)
    label = repo.get_label(TARGET_LABEL)
    bulletins = get_issues_after(AFTER_DATE, repo, label)
    output = ''
    for bulletin in bulletins:
        aosa = get_aosa_number(bulletin)
        version = get_updated_version(bulletin)
        bulletin_number = ', '.join(get_bulletin_number(bulletin))
        name = ', '.join(get_expanded_names(bulletin, packages))
        if not aosa:
            aosa = 'AOSA-????-????'
            logging.warning('AOSA number not found for: %s' %
                            bulletin.html_url)
        output += ('- %s: Update %s to %s (%s)\n' %
                   (aosa, name, version, bulletin_number))
    print(
        '\n\n' + generate_head(bulletins[-1].created_at, bulletins[0].created_at) + output)


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    logging.info("Fetching information from package site...")
    resp = requests.get(REFERENCE_REPO)
    resp.raise_for_status()
    packages = resp.json()['packages']
    packages = [i['name'] for i in packages]
    main()
