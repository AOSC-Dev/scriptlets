use std::{
    env::{args, current_exe},
    fs,
    io::Read,
};

use anyhow::{anyhow, Context, Result};
use reqwest::blocking::ClientBuilder;
use tar::Archive;
use walkdir::WalkDir;
use xz::read::XzDecoder;

fn main() -> Result<()> {
    let tree = args().nth(1).context(format!(
        "Usage: {} TREE_PATH",
        current_exe().unwrap().display()
    ))?;

    let mut users = sysusers(&tree)?;
    usergroup(&mut users, &tree)?;
    bootstrap(&mut users)?;

    for u in users {
        println!("{}", u);
    }

    Ok(())
}

fn sysusers(tree: &str) -> Result<Vec<String>> {
    let mut users = vec![];
    for i in WalkDir::new(tree).min_depth(8).max_depth(8) {
        let i = i?;
        if i.path().to_string_lossy().contains("sysusers.d")
            && i.path().extension().is_some_and(|x| x == "conf")
        {
            let f = fs::read_to_string(i.path())?;
            for i in f.lines() {
                if i.starts_with('#') {
                    continue;
                }
                let user = i.split_ascii_whitespace().nth(1);
                if let Some(user) = user {
                    if !users.contains(&user.to_string()) {
                        users.push(user.to_string());
                    }
                }
            }
        }
    }

    Ok(users)
}

fn usergroup(users: &mut Vec<String>, tree: &str) -> Result<()> {
    for i in WalkDir::new(tree).min_depth(4).max_depth(4) {
        let i = i?;
        if i.path().ends_with("usergroup") {
            let f = fs::read_to_string(i.path())?;
            let line = f
                .trim()
                .lines()
                .nth(1)
                .ok_or(anyhow!("Failed to parse: {}", i.path().display()))?;
            let user = line.split_ascii_whitespace().nth(1);
            if let Some(user) = user {
                if !users.contains(&user.to_string()) {
                    users.push(user.to_string());
                }
            }
        }
    }

    Ok(())
}

fn bootstrap(users: &mut Vec<String>) -> Result<()> {
    let client = ClientBuilder::new().user_agent("wget").build()?;
    let resp = client.get("https://raw.githubusercontent.com/AOSC-Dev/aoscbootstrap/refs/heads/master/assets/etc-bootstrap.tar.xz")
        .send()?
        .error_for_status()?;

    let xz = XzDecoder::new(resp);
    let mut tar = Archive::new(xz);

    for file in tar.entries()? {
        let mut f = file?;
        if f.path()?.to_string_lossy() == "etc/passwd" {
            let mut s = String::new();
            f.read_to_string(&mut s)?;
            for i in s.trim().lines() {
                let (user, _) = i
                    .split_once(':')
                    .ok_or(anyhow!("Failed to parse etc/passwd"))?;
                if !users.contains(&user.to_string()) {
                    users.push(user.to_string());
                }
            }
        }
    }

    Ok(())
}
