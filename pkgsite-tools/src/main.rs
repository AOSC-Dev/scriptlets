use anyhow::Result;
use clap::Parser;

mod cli;
mod models;

use cli::*;
use pkgsite_tools::dedup_packages;

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
                );
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
                );
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
            Subcommands::Search { pattern } => {
                println!(
                    "{}",
                    models::search::Search::fetch(&pattern).await?.to_string()
                );
            }
        },
        None => unreachable!(),
    };

    Ok(())
}
