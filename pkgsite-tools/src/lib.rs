use itertools::Itertools;

pub const PACKAGES_SITE_URL: &str = "https://packages.aosc.io";

pub fn dedup_packages(packages: Vec<String>) -> Vec<String> {
    packages.into_iter().dedup().collect::<Vec<String>>()
}
