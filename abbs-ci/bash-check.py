import bashvar
import sys
import pyparsing as pp
from pathlib import Path
import warnings

warnings.simplefilter("ignore")

failed = False

def lint_file(filepath):
    global failed
    whole_file = open(filepath, 'r').read()

    try:
        _ = bashvar.eval_bashvar_literal(whole_file)
    except pp.ParseException as e:
        lineno = str(e.lineno)
        print(filepath + ':' + str(e.lineno))
        print('\t' + e.line)
        print()
        failed = True

tree = Path(sys.argv[1])

for category in tree.iterdir():
    if not category.is_dir() or category.name == 'groups':
        continue
    for package in category.iterdir():
        if not package.is_dir():
            continue
        
        spec = package.joinpath('spec')
        if spec.exists():
            lint_file(str(spec))

        defines = package.joinpath('autobuild', 'defines')
        if defines.exists():
            lint_file(str(defines))

        for sub_package in package.iterdir():
            if not sub_package.is_dir() or sub_package.name == 'autobuild':
                continue
            defines = sub_package.joinpath('autobuild', 'defines')
            if defines.exists():
                lint_file(str(defines))

exit(1 if failed else 0)
