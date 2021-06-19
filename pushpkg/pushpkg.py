#!/usr/bin/python3

import argparse
import os
import subprocess


def main():
    parser = argparse.ArgumentParser(
        description="pushpkg, push aosc package to repo.aosc.io")
    parser.add_argument("username", metavar="USERNAME", type=str,
                        help="Your LDAP Username")
    parser.add_argument("branch", metavar="BRANCH", type=str,
                        help="push package to branch")
    parser.add_argument("component", metavar="COMPONENT",
                        type=str, help="push package to component", nargs="?", default="main")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-d", "--delete", action="store_true")
    args = parser.parse_args()
    if not args.username or not args.branch:
        print("[!!!] Please specify a LDAP user and specify a branch!")
        parser.print_help()
        exit(1)
    if not os.path.isdir("./debs"):
        print("[!!!] debs is not a directory!")
        exit(1)
    username = args.username
    branch = args.branch
    component = args.component
    verbose = args.verbose
    delete = args.delete
    delete_junk()
    mkdir_on_repo(username, branch, component, verbose)
    rsync_non_noarch_file(username, branch, component, verbose)
    rsync_noarch_file(username, branch, component, verbose)
    if delete:
        clean_output_directory()
    exit(0)


def delete_junk():
    debs_path = os.path.abspath("./debs")
    subprocess.run(
        "sudo find {} -maxdepth 1 -type f -delete -print".format(debs_path))


def mkdir_on_repo(username: str, branch: str, component: str, verbose=False):
    command = "ssh {} {}@repo.aosc.io \"mkdir -p '/mirror/debs/pool/${}/${}'".format(
        "" if not verbose else "-vvv", username, branch, component)
    subprocess.run(command)


def rsync_non_noarch_file(username: str, branch: str, component: str, verbose=False):
    command = "rsync {} -rlOvhze ssh --progress --exclude \"*_noarch.deb\" . \"{}@repo.aosc.io:/mirror/debs/pool/{}/{}/\"".format(
        "" if not verbose else "-v", username, branch, component)
    subprocess.run(command)


def rsync_noarch_file(username: str, branch: str, component: str, verbose=False):
    command = "rsync {} -rlOvhze ssh --progress --include \"*_noarch.deb\" .  \"{}@repo.aosc.io:/mirror/debs/pool/{}/{}/\"".format(
        "" if not verbose else "-v", username, branch, component)
    subprocess.run(command)


def clean_output_directory():
    print("Cleaning debs...")
    debs_path = os.path.abspath("./debs")
    subprocess.run("sudo rm -rv {}".format(debs_path))


if __name__ == "__main__":
    main()
