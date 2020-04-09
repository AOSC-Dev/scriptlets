## AOSA Report Generator

### How to "install"

First create a Python 3 venv: `python3 -m venv venv`

Now if you are using Bash, run `source venv/bin/activate`; if you are using ZSH, run `source venv/bin/activate.zsh`; for FISH users: `source venv/bin/activate.fish`.

Then install the dependencies: `pip install -r requirements.txt`

### How to setup

1. Open the `reporter.py` with your favorite text/code editor
1. Navigate to line 11, and you will see `AFTER_DATE=...`, change the date value to the start of the reporting cycle (the issues *after* this date will be collected)
1. Navigate to line 12, and you need to insert your GitHub access token here. This is required as the anonymous API quota will run out very fast. It's recommended to create a new token for this specific script, a token without any permission scope should do the job
1. Save and close the file

### Usage

After setting up the script, you can now run it with `python3 reporter.py > generated.txt`. The result will be stored in `generated.txt` also take notice of any warnings issued during the run.

You need to pay extra attention to issues printed out during the run when reviewing the generated bulletin.

Also if you want to strip out all the Markdown elements in the generated file, your best bet would be using Pandoc. Here is an example how you may accomplish the job: `pandoc -f markdown -t plain --wrap=none generate.txt -o filtered.txt`.

