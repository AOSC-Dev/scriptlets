use std::{collections::HashSet, fs, str::FromStr, sync::Arc};

use anyhow::{Result, anyhow, bail};
use libabbs::{
	apml::{
		ApmlContext,
		value::{array::StringArray, union::Union},
	},
	tree::{AbbsSourcePackage, AbbsTree},
};
use regex::Regex;
use tokio::task::JoinSet;

mod pkgcontents;
mod pkgsite;

#[derive(Debug)]
pub struct PkgBreakContext {
	pub abbs: AbbsTree,
	pub http_client: reqwest::Client,
}

impl PkgBreakContext {
	/// Selects a set of packages to be rebuilt.
	///
	/// Note that the produced list are not filtered
	/// and may include packages that have been dropped
	/// from the repository. However, it must never include
	/// the trigger package itself.
	pub async fn select(
		self: &Arc<Self>,
		package: &AbbsSourcePackage,
		kind: &str,
	) -> Result<HashSet<String>> {
		let kind = kind.to_ascii_uppercase();

		let mut result = HashSet::new();
		let mut jobs = JoinSet::new();

		let spec = fs::read_to_string(package.join("spec"))?;
		let spec_ctx = ApmlContext::eval_source(&spec)?;
		let pkgrebuild = spec_ctx
			.get(&format!("PKGREBUILD__{}", kind))
			.or_else(|| spec_ctx.get("PKGREBUILD"))
			.map(|val| StringArray::from(val.as_string()))
			.map(|val| {
				val.unwrap()
					.into_iter()
					.map(|dir| Directive::from_str(&dir))
					.collect()
			})
			.unwrap_or_else(|| {
				if kind == "ABI" {
					Ok(vec![
						Directive::PackageDependents(None),
						Directive::LibraryDependents(None),
					])
				} else {
					Ok(vec![])
				}
			})?;

		for directive in pkgrebuild {
			// fast-path for pkg directives
			if let Directive::Package(pkg) = &directive {
				result.insert(pkg.to_string());
				continue;
			}

			let ctx = self.clone();
			let package = package.clone();
			jobs.spawn(async move {
				ctx.select_directive(&package, &directive).await
			});
		}

		while let Some(part) = jobs.join_next().await {
			let part = part?;
			let part = part?;
			result.extend(part);
		}

		result.remove(package.name());
		Ok(result)
	}

	/// Selects a set of packages to be rebuilt.
	pub async fn select_directive(
		&self,
		package: &AbbsSourcePackage,
		directive: &Directive,
	) -> Result<HashSet<String>> {
		match directive {
			Directive::LibraryDependents(pkg) => {
				let deps = pkgsite::find_deps(
					&self.http_client,
					&pkg.to_owned()
						.unwrap_or_else(|| package.name().to_string()),
					false,
				)
				.await?;
				Ok(deps)
			}
			Directive::PackageDependents(pkg) => {
				let deps = pkgsite::find_deps(
					&self.http_client,
					&pkg.to_owned()
						.unwrap_or_else(|| package.name().to_string()),
					true,
				)
				.await?;
				Ok(deps)
			}
			Directive::PathPattern(regex) => {
				pkgcontents::find_deps(&self.http_client, regex).await
			}
			Directive::Section(section) => {
				let mut result = HashSet::new();
				for package in self.abbs.section_packages(&section.into())? {
					for package in package.subpackages()? {
						result.insert(package.name()?);
					}
				}
				Ok(result)
			}
			Directive::Package(pkg) => Ok(HashSet::from([pkg.clone()])),
			Directive::PackagePattern(regex) => {
				let mut result = HashSet::new();
				for package in self.abbs.all_packages()? {
					for package in package.subpackages()? {
						let name = package.name()?;
						if regex.is_match(&name) {
							result.insert(name);
						}
					}
				}
				Ok(result)
			}
		}
	}
}

/// A PKGREBUILD selector directive.
#[derive(Debug, Clone)]
pub enum Directive {
	/// Shared-library dependents.
	LibraryDependents(Option<String>),
	/// Reverse dependents.
	PackageDependents(Option<String>),
	/// Packages providing files matching the pattern.
	PathPattern(Regex),
	/// Packages in a certain section.
	Section(String),
	/// A certain package.
	Package(String),
	/// Packages matching the pattern.
	PackagePattern(Regex),
}

impl FromStr for Directive {
	type Err = anyhow::Error;

	fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
		let un = Union::try_from(s)?;
		match un.tag.as_str() {
			"sodep" => Ok(Self::LibraryDependents(un.argument)),
			"revdep" => Ok(Self::PackageDependents(un.argument)),
			"path" => {
				Ok(Self::PathPattern(Regex::new(&un.argument.ok_or_else(
					|| anyhow!("path directive must have an argument"),
				)?)?))
			}
			"section" => Ok(Self::Section(un.argument.ok_or_else(|| {
				anyhow!("section directive must have an argument")
			})?)),
			"pkg" => Ok(Self::Package(un.argument.ok_or_else(|| {
				anyhow!("pkg directive must have an argument")
			})?)),
			"pkgpattern" => {
				Ok(Self::PackagePattern(Regex::new(&un.argument.ok_or_else(
					|| anyhow!("pkgpattern directive must have an argument"),
				)?)?))
			}
			_ => bail!("unsupported tag in PKGREBUILD directive"),
		}
	}
}
