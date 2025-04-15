use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(about, author, version, arg_required_else_help(true))]
pub struct Cli {
    #[command(subcommand)]
    pub subcommands: Option<Subcommands>,
}

#[derive(Subcommand, Debug)]
pub enum Subcommands {
    /// Query dependencies of packages
    #[command(visible_alias = "dep")]
    Depends { packages: Vec<String> },
    /// Query reverse dependencies of packages
    #[command(visible_alias = "rdep")]
    Rdepends { packages: Vec<String> },
    /// Get package information
    #[command(visible_alias = "info")]
    Show { packages: Vec<String> },
    /// Search for packages
    Search { pattern: String },
}
