use std::{
    collections::HashMap,
    io::BufRead,
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{Context, Result};
use clap::Parser;
use oma_contents::searcher::{pure_search, ripgrep_search, Mode};

#[derive(Debug, Parser)]
struct App {
    /// Display match package binary path
    #[arg(long)]
    print_paths: bool,
    /// Binary path
    path: PathBuf,
    /// Only display +32 Package(s) result
    #[arg(long)]
    optenv32: bool,
    /// Allow search non /usr/lib path
    #[arg(long)]
    all_prefix: bool,
    /// Print result to one line
    #[arg(long)]
    oneline: bool,
}

fn main() -> Result<()> {
    let App {
        print_paths,
        path,
        optenv32,
        all_prefix,
        oneline,
    } = App::parse();

    let cmd = Command::new("readelf")
        .env("LANG", "C")
        .arg("-d")
        .arg(path)
        .output()?;

    let output = cmd.stdout.lines();

    let mut deps = vec![];

    for o in output {
        let o = o?;
        if !o.contains("(NEEDED)") {
            continue;
        }
        let Some(lib) = o.split_ascii_whitespace().next_back() else {
            continue;
        };

        deps.push(
            lib.strip_prefix('[')
                .and_then(|x| x.strip_suffix(']'))
                .context("Failed to parse readelf output")?
                .to_string()
        );
    }

    let mut map: HashMap<String, String> = HashMap::new();

    for dep in deps {
        if which::which("rg").is_ok() {
            ripgrep_search("/var/lib/apt/lists", Mode::Provides, &dep, |(pkg, path)| {
                if path.ends_with(&format!("/{}", dep)) {
                    map.insert(pkg, path);
                }
            })?;
        } else {
            pure_search("/var/lib/apt/lists", Mode::Provides, &dep, |(pkg, path)| {
                if path.ends_with(&format!("/{}", dep)) {
                    map.insert(pkg, path);
                }
            })?;
        };
    }

    let mut result = map.into_iter().collect::<Vec<_>>();
    result.sort_unstable_by(|a, b| a.0.cmp(&b.0));

    result
        .iter()
        .filter(|x| !optenv32 || x.0.ends_with("+32"))
        .filter(|x| {
            (all_prefix || optenv32)
                || Path::new(&x.1)
                    .parent()
                    .is_some_and(|x| x.to_string_lossy() == "/usr/lib")
        })
        .for_each(|x| {
            if print_paths {
                println!("{} ({})", x.0, x.1)
            } else if oneline {
                print!("{} ", x.0);
            } else {
                println!("{}", x.0);
            }
        });

        if oneline {
            println!();
        }

    Ok(())
}
