use anyhow::Result;
use reqwest;
use serde::{Deserialize, Serialize};
use std::fmt::Display;

use pkgsite_tools::PACKAGES_SITE_URL;

#[derive(Debug, Serialize, Deserialize)]
pub struct PackageError {
    pub message: String,
    pub path: String,
    pub tree: String,
    pub branch: String,
}

impl Display for PackageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({}:{}) {}: {}",
            &self.tree, &self.branch, &self.path, &self.message
        )
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Info {
    pub name: String,
    pub version: String,
    pub category: String,
    pub section: String,
    pub errors: Vec<PackageError>,
    pub srctype: String,
    pub srcurl_base: String,
    pub srcurl: String,
    pub full_version: String,
}

impl Info {
    pub async fn fetch(packages: &[String]) -> Result<Vec<Self>> {
        let mut res = Vec::new();
        for package in packages.iter() {
            res.push(
                reqwest::get(format!(
                    "{}/packages/{}?type=json",
                    PACKAGES_SITE_URL, package
                ))
                .await?
                .json::<Self>()
                .await?,
            );
        }
        Ok(res)
    }
}

impl Display for Info {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Package: {}
Version: {} ({})
Section: {}-{}
Upstream: {}
Source: ({}) {}{}",
            &self.name,
            &self.full_version,
            &self.version,
            &self.category,
            &self.section,
            &self.srcurl_base,
            &self.srctype,
            &self.srcurl,
            if self.errors.is_empty() {
                String::new()
            } else {
                format!(
                    "\nErrors: {}",
                    &self
                        .errors
                        .iter()
                        .map(|e| e.to_string())
                        .collect::<Vec<String>>()
                        .join("\n")
                )
            }
        )
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_fetch() {
        println!(
            "{:?}",
            Info::fetch(["wayland".to_owned()].as_slice())
                .await
                .unwrap()
        );
    }

    #[tokio::test]
    async fn test_display() {
        println!(
            "{}",
            Info::fetch(["wayland".to_owned()].as_slice())
                .await
                .unwrap()
                .first()
                .unwrap()
        );
    }
}
