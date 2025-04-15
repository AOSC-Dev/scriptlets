use anyhow::Result;
use clap::Parser;

mod cli;
mod models;

use cli::*;
use pkgsite_tools::{dedup_packages, print_res};

#[tokio::main]
async fn main() -> Result<()> {
    let args = Cli::parse();

    match args.subcommands {
        Some(cmd) => match cmd {
            Subcommands::Depends { packages } => {
                print_res!(annotated models::depends::Depends, packages);
            }
            Subcommands::Rdepends { packages } => {
                print_res!(annotated models::rdepends::RDepends, packages);
            }
            Subcommands::Show { packages } => {
                print_res!(unannotated models::info::Info, packages);
            }
            Subcommands::Search { pattern } => {
                print_res!(single models::search::Search, pattern);
            }
        },
        None => unreachable!(),
    };

    Ok(())
}
