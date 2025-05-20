use anyhow::Context;
use clap::Parser;
use oma_apt::{Cache, DepType, Package, new_cache};
use std::io::{Write, stdout};
use termtree::Tree;

#[derive(Debug, Parser)]
struct Args {
    /// Query Package name
    package: String,
    /// Search depth
    #[arg(short, long, default_value_t = 5)]
    depth: u8,
    /// invert search dependency
    #[arg(short, long)]
    invert: bool,
}

fn main() -> anyhow::Result<()> {
    let Args {
        depth: limit_depth,
        package: pkg,
        invert,
    } = Args::parse();

    let cache = new_cache!().context("Failed to init apt cache")?;
    let pkg = cache
        .get(&pkg)
        .with_context(|| format!("Failed to get package {}", pkg))?;

    if !invert {
        writeln!(stdout(), "{}", dep_tree(&pkg, &cache, 1, limit_depth)?).ok();
    } else {
        writeln!(
            stdout(),
            "{}",
            reverse_dep_tree(&pkg, &cache, 1, limit_depth)
        )
        .ok();
    }

    Ok(())
}

fn reverse_dep_tree(pkg: &Package<'_>, cache: &Cache, depth: u8, limit: u8) -> Tree<String> {
    let mut res = Tree::new(pkg.name().to_string());

    let rdep = pkg.rdepends();

    if depth > limit {
        return res;
    }

    for (t, deps) in rdep {
        if t == &DepType::Depends {
            for dep in deps {
                let pkg = cache.get(dep.first().name());

                if let Some(pkg) = pkg {
                    if pkg.is_installed() {
                        res.push(reverse_dep_tree(&pkg, cache, depth + 1, limit));
                    }
                }
            }
        }
    }

    res
}

fn dep_tree(
    pkg: &Package<'_>,
    cache: &Cache,
    depth: u8,
    limit: u8,
) -> anyhow::Result<Tree<String>> {
    let mut res = Tree::new(pkg.name().to_string());

    if depth > limit {
        return Ok(res);
    }

    let cand = pkg
        .candidate()
        .with_context(|| format!("Failed to get candidate for package {}", pkg.name()))?;

    let deps = cand.dependencies();

    if let Some(deps) = deps {
        for dep in deps {
            if let Some(dep) = cache.get(dep.first().name()) {
                res.push(dep_tree(&dep, cache, depth + 1, limit)?);
            }
        }
    }

    Ok(res)
}
