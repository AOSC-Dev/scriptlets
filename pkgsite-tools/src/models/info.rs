use anyhow::Result;
use console::{Alignment, measure_text_width, pad_str, style};
use reqwest;
use serde::{Deserialize, Serialize};
use std::fmt::Display;

use pkgsite_tools::{PACKAGES_SITE_URL, PADDING};

#[derive(Debug, Serialize, Deserialize)]
struct PackageError {
    message: String,
    path: String,
    tree: String,
    branch: String,
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
struct DpkgMeta {
    hasmeta: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct MatrixRow {
    repo: String,
    meta: Vec<DpkgMeta>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Version {
    testing: bool,
    version: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Info {
    name: String,
    version: String,
    description: String,
    category: String,
    section: String,
    errors: Vec<PackageError>,
    srctype: String,
    srcurl_base: String,
    srcurl: String,
    full_version: String,
    versions: Vec<Version>,
    version_matrix: Vec<MatrixRow>,
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
        let max_repo_width = &self
            .version_matrix
            .iter()
            .map(|m| measure_text_width(&m.repo))
            .max()
            .unwrap_or(10);

        let ver_width = [
            &self.versions.first().map(|v| v.version.len()).unwrap_or(10),
            &self.versions.get(1).map(|v| v.version.len()).unwrap_or(10),
            &self.versions.get(2).map(|v| v.version.len()).unwrap_or(10),
        ];

        write!(
            f,
            "Package: {}
Version: {} ({})
Description: {}
Section: {}-{}
Upstream: {}
Source: ({}) {}{}

Available versions:
{}{}
{}
{}",
            &self.name,
            &self.full_version,
            &self.version,
            &self.description,
            &self.category,
            &self.section,
            &self.srcurl_base,
            &self.srctype,
            &self.srcurl,
            if self.errors.is_empty() {
                String::new()
            } else {
                format!(
                    "\nErrors:\n{}",
                    &self
                        .errors
                        .iter()
                        .map(|e| e.to_string())
                        .collect::<Vec<String>>()
                        .join("\n")
                )
            },
            pad_str("Version", max_repo_width + PADDING, Alignment::Left, None),
            &self
                .versions
                .iter()
                .take(3)
                .fold(String::new(), |acc, version| {
                    let italic_version = style(&version.version).italic().to_string();
                    acc + &pad_str(
                        if version.testing {
                            &italic_version
                        } else {
                            &version.version
                        },
                        version.version.len() + PADDING,
                        Alignment::Left,
                        None,
                    )
                }),
            &self
                .version_matrix
                .iter()
                .map(|repo| {
                    format!(
                        "{}{}",
                        &pad_str(&repo.repo, max_repo_width + PADDING, Alignment::Left, None)
                            .to_string(),
                        &repo.meta.iter().take(3).enumerate().fold(
                            String::new(),
                            |acc, (idx, meta)| {
                                if meta.hasmeta {
                                    acc + &pad_str(
                                        "✓",
                                        *ver_width[idx] + PADDING,
                                        Alignment::Left,
                                        None,
                                    )
                                } else {
                                    acc + &pad_str(
                                        "x",
                                        *ver_width[idx] + PADDING,
                                        Alignment::Left,
                                        None,
                                    )
                                }
                            },
                        )
                    )
                })
                .collect::<Vec<String>>()
                .join("\n"),
            if self.versions.iter().any(|version| version.testing) {
                format!(
                    "\nNOTE: {} versions are italicized.",
                    style("Testing").italic(),
                )
            } else {
                String::new()
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
