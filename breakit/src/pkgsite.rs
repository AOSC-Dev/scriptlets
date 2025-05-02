//! AOSC OS packages site APIs.

use std::collections::HashSet;

use anyhow::Result;
use serde::Deserialize;

pub(crate) async fn find_deps(
	client: &reqwest::Client,
	package: &str,
	sodep: bool,
) -> Result<HashSet<String>> {
	let resp = client
		.execute(
			client
				.get(format!(
					"https://packages.aosc.io/revdep/{package}?type=json"
				))
				.build()?,
		)
		.await?
		.error_for_status()?
		.json::<PackageJson>()
		.await?;
	let mut packages = HashSet::new();

	if !sodep {
		for group in resp.revdeps {
			for dep in group.deps {
				packages.insert(dep.package);
			}
		}
	} else {
		for group in resp.sobreaks {
			packages.extend(group);
		}
		packages.extend(resp.sobreaks_circular);
	}

	Ok(packages)
}

#[derive(Debug, Deserialize)]
struct PackageJson {
	#[serde(default)]
	revdeps: Vec<DependencyGroup>,
	#[serde(default)]
	sobreaks: Vec<Vec<String>>,
	#[serde(default)]
	sobreaks_circular: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct DependencyGroup {
	deps: Vec<Dependency>,
}

#[derive(Debug, Deserialize)]
struct Dependency {
	package: String,
}
