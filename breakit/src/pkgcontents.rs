//! Helpers to scan the `Contents` file of a APT repository.

use core::str;
use std::collections::HashSet;

use anyhow::Result;
use bytes::Buf;
use regex::Regex;

pub(crate) async fn find_deps(
	client: &reqwest::Client,
	pattern: &Regex,
) -> Result<HashSet<String>> {
	let mut packages = HashSet::new();

	for arch in ["all", "amd64", "arm64"] {
		// TODO: cache Contents file
		let resp = client
			.execute(
				client
					.get(format!(
						"https://repo.aosc.io/debs/dists/stable/main/Contents-{arch}.zst"
					))
					.build()?,
			)
			.await?
			.error_for_status()?
			.bytes()
			.await?;
		let resp = zstd::decode_all(resp.reader())?;
		let resp = String::from_utf8(resp)?;
		for line in resp.lines() {
			let line_bytes = line.as_bytes();
			let mut idx = line_bytes.len() - 1;
			while idx > 0 && line_bytes[idx] != b' ' {
				idx -= 1;
			}
			if idx == 0 {
				continue;
			}
			let path = str::from_utf8(&line_bytes[0..idx])?.trim_ascii_end();
			if pattern.is_match(path) {
				let pkg = str::from_utf8(&line_bytes[idx + 1..])?;
				for pkg in pkg.split(',') {
					let pkg = pkg.split('/').next_back().unwrap_or(pkg);
					packages.insert(pkg.to_string());
				}
			}
		}
	}

	Ok(packages)
}
