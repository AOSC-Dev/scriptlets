use anyhow::Result;
use clap::Parser;
use itertools::Itertools;

mod cli;
mod models;

use cli::*;

fn dedup_packages(packages: Vec<String>) -> Vec<String> {
    packages.into_iter().dedup().collect::<Vec<String>>()
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Cli::parse();

    match args.subcommands {
        Some(cmd) => match cmd {
            Subcommands::Depends { packages } => {
                println!(
                    "{}",
                    models::depends::Depends::fetch(&dedup_packages(packages))
                        .await?
                        .iter()
                        .map(|(pkg, res)| format!("{}:\n{}", pkg, res))
                        .collect::<Vec<String>>()
                        .join("\n\n")
                )
            }
            Subcommands::Rdepends { packages } => {
                println!(
                    "{}",
                    models::rdepends::RDepends::fetch(&dedup_packages(packages))
                        .await?
                        .iter()
                        .map(|(pkg, res)| format!("{}:\n{}", pkg, res))
                        .collect::<Vec<String>>()
                        .join("\n\n")
                )
            }
            Subcommands::Show { packages } => {
                println!(
                    "{}",
                    models::info::Info::fetch(&dedup_packages(packages))
                        .await?
                        .iter()
                        .map(|res| res.to_string())
                        .collect::<Vec<String>>()
                        .join("\n\n")
                );
            }
        },
        None => unreachable!(),
    };

    Ok(())
}
