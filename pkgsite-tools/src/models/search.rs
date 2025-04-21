use anyhow::{Result, bail};
use console::{Alignment, measure_text_width, pad_str, style};
use regex::{Captures, Regex};
use reqwest::{Client, StatusCode, redirect::Policy};
use serde::{Deserialize, Serialize};
use std::fmt::Display;

use pkgsite_tools::{PACKAGES_SITE_URL, PADDING};

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Package {
    name_highlight: String,
    full_version: String,
    desc_highlight: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Search {
    packages: Vec<Package>,
}

impl Search {
    pub async fn fetch(pattern: &str, noredir: bool) -> Result<Box<dyn ToString>> {
        let client = Client::builder().redirect(Policy::none()).build()?;
        let response = client
            .get(format!(
                "{}/search?q={}&type=json{}",
                PACKAGES_SITE_URL,
                pattern,
                if noredir { "&noredir=true" } else { "" }
            ))
            .send()
            .await?;

        match response.status() {
            StatusCode::OK => Ok(Box::new(response.json::<Self>().await?)),
            StatusCode::SEE_OTHER => {
                let package = response
                    .headers()
                    .get("location")
                    .unwrap()
                    .to_str()?
                    .strip_prefix("/packages/")
                    .unwrap()
                    .to_string();
                Ok(Box::new(format!(
                    "Found an exact match:\n(append --search-only to search the keyword instead)\n\n{}",
                    super::info::Info::fetch(&[package])
                        .await?
                        .iter()
                        .map(|res| res.to_string())
                        .collect::<Vec<String>>()
                        .join("\n\n"),
                )))
            }
            _ => bail!("Error searching for packages"),
        }
    }
}

impl Display for Search {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let highlight_regex = Regex::new(r"<b>(?<highlight>.+?)<\/b>").unwrap();
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
                desc_highlight: html_escape::decode_html_entities(
                    &highlight_regex
                        .replace_all(&pkg.desc_highlight, highlight_rep)
                        .to_string(),
                )
                .to_string(),
                ..(*pkg).clone()
            })
            .collect::<Vec<Package>>();

        let max_pkgname_width = packages
            .iter()
            .map(|pkg| measure_text_width(&pkg.name_highlight))
            .max()
            .unwrap_or(10);
        let max_version_width = packages
            .iter()
            .map(|pkg| measure_text_width(&pkg.full_version))
            .max()
            .unwrap_or(10);

        write!(
            f,
            "{}",
            packages
                .iter()
                .map(|pkg| format!(
                    "{}{}{}",
                    pad_str(
                        &pkg.name_highlight,
                        max_pkgname_width + PADDING,
                        Alignment::Left,
                        None
                    ),
                    pad_str(
                        &pkg.full_version,
                        max_version_width + PADDING,
                        Alignment::Left,
                        None
                    ),
                    pkg.desc_highlight,
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
