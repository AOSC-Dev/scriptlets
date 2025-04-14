use anyhow::Result;
use reqwest;
use serde::{Deserialize, Serialize};
use std::fmt::Display;

use pkgsite_tools::PACKAGES_SITE_URL;

#[derive(Debug, Serialize, Deserialize)]
pub struct Dependency {
    pub relationship: String,
    pub arch: String,
    pub packages: Vec<(String, String)>,
}

impl Display for Dependency {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}{}: {}",
            &self.relationship,
            if self.arch.is_empty() {
                String::new()
            } else {
                format!(" {}", &self.arch)
            },
            &self
                .packages
                .iter()
                .map(|(pkg, ver)| { format!("{}{}", pkg, ver) })
                .collect::<Vec<String>>()
                .join(", ")
        )
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Depends {
    pub dependencies: Vec<Dependency>,
    pub library_dependencies: Vec<String>,
}

impl Depends {
    pub async fn fetch(packages: &[String]) -> Result<Vec<(String, Self)>> {
        let mut res = Vec::new();
        for package in packages.iter() {
            res.push((
                package.clone(),
                reqwest::get(format!(
                    "{}/packages/{}?type=json",
                    PACKAGES_SITE_URL, package
                ))
                .await?
                .json::<Self>()
                .await?,
            ));
        }
        Ok(res)
    }
}

impl Display for Depends {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}
Library Dependencies: {}",
            &self
                .dependencies
                .iter()
                .map(|dep| dep.to_string())
                .collect::<Vec<String>>()
                .join("\n"),
            &self.library_dependencies.join(", ")
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
            Depends::fetch(["sway".to_owned()].as_slice())
                .await
                .unwrap()
        );
    }
}
