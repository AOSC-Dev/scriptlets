use anyhow::Result;
use console::style;
use regex::{Captures, Regex};
use reqwest;
use serde::{Deserialize, Serialize};
use std::fmt::Display;

use pkgsite_tools::PACKAGES_SITE_URL;

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Package {
    name_highlight: String,
    name: String,
    full_version: String,
    description: String,
    desc_highlight: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Search {
    packages: Vec<Package>,
}

impl Search {
    pub async fn fetch(pattern: &str) -> Result<Self> {
        Ok(reqwest::get(format!(
            "{}/search?q={}&type=json",
            PACKAGES_SITE_URL, pattern
        ))
        .await?
        .json::<Self>()
        .await?)
    }
}

impl Display for Search {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let highlight_regex = Regex::new(r"<b>(?<highlight>.+)<\/b>").unwrap();
        let highlight_rep = |caps: &Captures| -> String {
            style(&caps["highlight"]).bold().underlined().to_string()
        };
        let packages = &self
            .packages
            .iter()
            .map(|pkg| Package {
                name_highlight: highlight_regex
                    .replace_all(&pkg.name_highlight, highlight_rep)
                    .to_string(),
                desc_highlight: highlight_regex
                    .replace_all(&pkg.desc_highlight, highlight_rep)
                    .to_string(),
                ..(*pkg).clone()
            })
            .collect::<Vec<Package>>();

        let max_pkgname_width = packages
            .iter()
            .map(|pkg| pkg.name_highlight.len())
            .max()
            .unwrap_or(10);
        let max_version_width = packages
            .iter()
            .map(|pkg| pkg.full_version.len())
            .max()
            .unwrap_or(10);

        write!(
            f,
            "{}",
            packages
                .iter()
                .map(|pkg| format!(
                    "{: <name_width$}{: <version_width$}{}",
                    pkg.name_highlight,
                    pkg.full_version,
                    pkg.desc_highlight,
                    name_width = max_pkgname_width + 4,
                    version_width = max_version_width + 4,
                ))
                .collect::<Vec<String>>()
                .join("\n")
        )
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_fetch() {
        println!("{:?}", Search::fetch("-base").await.unwrap());
    }

    #[tokio::test]
    async fn test_display() {
        println!("{}", Search::fetch("-base").await.unwrap());
    }
}
