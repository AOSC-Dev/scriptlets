#!/usr/bin/python3

import argparse
import os
import subprocess


def main():
    parser = argparse.ArgumentParser(
        description="pushpkg, push aosc package to repo.aosc.io")
    parser.add_argument("username", metavar="USERNAME", type=str,
                        help="Your LDAP username.")
    parser.add_argument("branch", metavar="BRANCH", type=str,
                        help="AOSC OS update branch (stable, stable-proposed, testing, etc.)")
    parser.add_argument("component", metavar="COMPONENT",
                        type=str, help="(Optional) Repository component (main, bsp-sunxi, etc.) Falls back to \"main\" if not specified.", nargs="?", default="main")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Enable verbose logging for ssh and rsync")
    parser.add_argument("-d", "--delete", action="store_true",
                        help="Clean OUTPUT directory after finishing uploading.")
    args = parser.parse_args()
    if not args.username or not args.branch:
        print("[!!!] Please specify a LDAP user and specify a branch!")
        parser.print_help()
        exit(1)
    if not os.path.isdir("./debs"):
        print("[!!!] debs is not a directory!")
        exit(1)
    delete_junk()
    mkdir_on_repo(args.username, args.branch, args.component, args.verbose)
    rsync_non_noarch_file(args.username, args.branch, args.component, args.verbos)
    rsync_noarch_file(args.username, args.branch, args.component, args.verbos)
    if args.delete:
        clean_output_directory()
    exit(0)


def delete_junk():
    debs_path = os.path.abspath("./debs")
    command = ["sudo", "find", debs_path, "-maxdepth",
               "1", "-type", "f", "-delete", "-print"]
    subprocess.check_call(command)


def mkdir_on_repo(username: str, branch: str, component: str, verbose=False):
    command = ["ssh", "{}@repo.aosc.io".format(
        username), "mkdir", "-p", "/mirror/debs/pool/{}/{}".format(branch, component)]
    if verbose:
        command.insert(1, "-vvv")
    subprocess.check_call(command)


def rsync_non_noarch_file(username: str, branch: str, component: str, verbose=False):
    command = ["rsync", "-rlOvhze", "ssh", "--progress", "--exclude",
               "*_noarch.deb", ".", "{}@repo.aosc.io:/mirror/debs/pool/{}/{}/".format(username, branch, component)]
    if verbose:
        command.insert(1, "-v")
    subprocess.check_call(command)


def rsync_noarch_file(username: str, branch: str, component: str, verbose=False):
    command = ["rsync", "--ignore-existing", "-rlOvhze", "ssh", "--progress", "--include",
               "*_noarch.deb", ".", "{}@repo.aosc.io:/mirror/debs/pool/{}/{}/".format(username, branch, component)]
    if verbose:
        command.insert(1, "-v")
    subprocess.check_call(command)


def clean_output_directory():
    print("Cleaning debs...")
    debs_path = os.path.abspath("./debs")
    subprocess.check_call(["sudo", "rm", "-rv", debs_path])


if __name__ == "__main__":
    main()
