use std::{
    collections::HashSet,
    fs::File,
    io::{BufRead, BufReader, Write},
    path::Path,
};

use anyhow::{Context, Result};
use clap::{ArgAction, Parser, Subcommand};
use dirs_next::cache_dir;
use fancy_regex::Regex;
use flate2::read::GzDecoder;
use log::info;
use oma_contents::searcher::{search, Mode};
use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use reqwest::blocking::ClientBuilder;
use simplelog::{ColorChoice, Config, LevelFilter, TermLogger, TerminalMode};

const USER_AGENT: &str = "Wget/1.20.3 (linux-gnu)";
const UBUNTU_CODENAME: &[&str] = &["jammy", "noble"];

#[derive(Debug, Parser)]
struct App {
    #[clap(subcommand)]
    subcmd: Subcmd,
}

#[derive(Debug, Subcommand)]
enum Subcmd {
    /// Query aosc package name from debian package name
    Query {
        /// Package name
        #[arg(requires = "true", action = ArgAction::Append)]
        names: Vec<String>,
    },
    /// Update cache
    UpdateCache,
}

fn main() -> Result<()> {
    let app = App::parse();

    TermLogger::init(
        LevelFilter::Info,
        Config::default(),
        TerminalMode::Stderr,
        ColorChoice::Auto,
    )?;

    let dir = cache_dir().context("Failed to get cache dir")?;

    let spiral_data_path = dir.join("spiral_data");

    match app.subcmd {
        Subcmd::Query { names } => {
            let data = if !spiral_data_path.exists() {
                update_data(&dir)?
            } else {
                let f = File::open(spiral_data_path)?;
                bincode::deserialize_from(f)?
            };

            let mut set = HashSet::new();

            let res = data
                .iter()
                .filter(|x| names.contains(&x.1))
                .flat_map(|x| Path::new(&x.0).file_name().map(|x| x.to_string_lossy()));

            for i in res {
                let pkg = get_aosc_package_name(&i)?;
                for p in pkg {
                    set.insert(p);
                }
            }

            for i in set {
                print!("{} ", i);
            }
            println!();
        }
        Subcmd::UpdateCache => {
            update_data(&dir)?;
        }
    }

    Ok(())
}

fn get_aosc_package_name(so_file: &str) -> Result<Vec<String>> {
    let mut v = vec![];

    let input = format!("/usr/lib/{}", so_file);

    info!("Searching {input}");

    search(
        "/var/lib/apt/lists",
        Mode::Provides,
        &input,
        |(pkg, file)| {
            if file == input {
                v.push(pkg);
            }
        },
    )
    .ok();

    Ok(v)
}

fn update_data(dir: &Path) -> Result<Vec<(String, String)>> {
    info!("Updating spiral cache");

    let re = Regex::new(
        r"/?usr/lib/(?:x86_64-linux-gnu/)?(?P<key>lib[a-zA-Z0-9\-._+]+\.so(?:\.[0-9]+)*)",
    )?;
    let client = ClientBuilder::new().user_agent(USER_AGENT).build()?;

    let res = UBUNTU_CODENAME
        .par_iter()
        .flat_map(|i| -> Result<Vec<(String, String)>> {
            let mut res = vec![];

            let resp = client
                .get(format!(
                    "http://archive.ubuntu.com/ubuntu/dists/{}/Contents-amd64.gz",
                    i
                ))
                .send()?
                .error_for_status()?;

            let reader = BufReader::new(GzDecoder::new(resp));

            for i in reader.lines() {
                let i = i?;
                let (file, pkg) = i
                    .rsplit_once(|c: char| c.is_whitespace() && c != '\n')
                    .context("Failed to parse contents")?;
                if re.is_match(file)? {
                    let pkgs = pkg.split(',');
                    for p in pkgs {
                        res.push((
                            file.trim().to_string(),
                            p.split('/')
                                .last()
                                .context("Failed to parse contents line")?
                                .to_string(),
                        ));
                    }
                }
            }

            Ok(res)
        })
        .flatten()
        .collect::<Vec<_>>();

    let mut f = File::create(dir.join("spiral_data"))?;
    let ser = bincode::serialize(&res)?;
    f.write_all(&ser)?;

    info!("Updated spiral cache");

    Ok(res)
}
