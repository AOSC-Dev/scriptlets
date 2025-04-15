use anyhow::Result;
use reqwest;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fmt::Display};

use pkgsite_tools::PACKAGES_SITE_URL;

#[derive(Debug, Serialize, Deserialize)]
struct RevDependency {
    package: String,
    version: String,
    architecture: String,
}

impl Display for RevDependency {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}{}{}",
            &self.package,
            &self.version,
            if self.architecture.is_empty() {
                String::new()
            } else {
                format!(" [{}]", &self.architecture)
            }
        )
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct RevDependencyGroup {
    description: String,
    deps: Vec<RevDependency>,
}

impl Display for RevDependencyGroup {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}: {}",
            &self.description,
            &self
                .deps
                .iter()
                .map(|pkg| pkg.to_string())
                .collect::<Vec<String>>()
                .join(", ")
        )
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RDepends {
    revdeps: Vec<RevDependencyGroup>,
    sobreaks: Vec<Vec<String>>,
    sobreaks_circular: Vec<String>,
    sorevdeps: HashMap<String, Vec<String>>,
}

impl RDepends {
    pub async fn fetch(packages: &[String]) -> Result<Vec<(String, Self)>> {
        let mut res = Vec::new();
        for package in packages.iter() {
            res.push((
                package.clone(),
                reqwest::get(format!(
                    "{}/revdep/{}?type=json",
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

impl Display for RDepends {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}{}{}{}",
            if self.revdeps.is_empty() {
                String::new()
            } else {
                format!(
                    "{}\n",
                    self.revdeps
                        .iter()
                        .map(|revdep| revdep.to_string())
                        .collect::<Vec<String>>()
                        .join("\n")
                )
            },
            if self.sobreaks.is_empty() {
                String::new()
            } else {
                format!(
                    "\nLibrary depended by:\n{}\n",
                    &self
                        .sobreaks
                        .iter()
                        .map(|sobreak| format!("- {}", sobreak.join(", ")))
                        .collect::<Vec<String>>()
                        .join("\n")
                )
            },
            if self.sobreaks_circular.is_empty() {
                String::new()
            } else {
                format!(
                    "- (Circular dependencies) {}\n",
                    &self.sobreaks_circular.join(", ")
                )
            },
            if self.sorevdeps.is_empty() {
                String::new()
            } else {
                format!(
                    "\nReverse dependencies of the libraries:\n{}",
                    &self
                        .sorevdeps
                        .iter()
                        .map(|(lib, revdep)| format!("- {}: {}", lib, revdep.join(", ")))
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
            RDepends::fetch(["wayland".to_owned()].as_slice())
                .await
                .unwrap()
        );
    }
}
