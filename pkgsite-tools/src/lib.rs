use itertools::Itertools;

pub const PACKAGES_SITE_URL: &str = "https://packages.aosc.io";

pub fn dedup_packages(packages: Vec<String>) -> Vec<String> {
    packages.into_iter().dedup().collect::<Vec<String>>()
}

#[macro_export]
macro_rules! print_res {
    ( unannotated $struct:ty, $($arg:expr), * ) => {
        println!(
            "{}",
            <$struct>::fetch(&dedup_packages($($arg), *))
                .await?
                .iter()
                .map(|res| res.to_string())
                .collect::<Vec<String>>()
                .join("\n\n")
        );
    };

    ( annotated $struct:ty, $($arg:expr), * ) => {
        println!(
            "{}",
            <$struct>::fetch(&dedup_packages($($arg), *))
                .await?
                .iter()
                .map(|(pkg, res)| format!("{}:\n{}", pkg, res))
                .collect::<Vec<String>>()
                .join("\n\n")
        );
    };

    ( single $struct:ty, $($arg:expr), * ) => {
        println!("{}", <$struct>::fetch(&$($arg), *).await?.to_string());
    };
}
