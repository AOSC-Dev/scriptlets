use core::str;
use std::{
	fs::{self, File},
	io::Write,
	path::{Path, PathBuf},
	sync::Arc,
};

use anyhow::Result;
use breakit::PkgBreakContext;
use clap::Parser;
use console::style;
use libabbs::{
	apml::{
		ApmlContext, ast,
		editor::ApmlEditor,
		lst::{self, ApmlLst},
		value::array::StringArray,
	},
	tree::{AbbsError, AbbsTree},
};

#[derive(Parser, Debug)]
#[command(version, about = "BreakIt: AOSC OS package rebuild collector")]
struct Args {
	/// Path of ABBS tree.
	#[arg(short = 'C', env = "ABBS_TREE")]
	tree: Option<PathBuf>,
	/// Package name.
	#[arg()]
	packages: Vec<String>,
	/// Breakage kind.
	#[arg(short = 't', long = "type")]
	kind: Option<String>,
	/// Write PKGBREAK.
	#[arg(short, long)]
	write: bool,
	/// Write rebuild group file.
	#[arg(long)]
	write_group: Option<PathBuf>,
	/// Bump REL for broken packages.
	///
	/// Packages that are already updated in the topic will not be bumped
	/// (in comparsion with local stable branch).
	#[arg(long)]
	bump_rel: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
	let args = Args::parse();
	eprintln!("BreakIt! {}", env!("CARGO_PKG_VERSION"));

	let tree = args
		.tree
		.unwrap_or_else(|| std::env::current_dir().unwrap());
	let abbs = AbbsTree::new(&tree);
	let repo = git2::Repository::open(&tree)?;
	let head_commit = repo.head()?.peel_to_commit()?;
	let head_tree = head_commit.tree()?;

	let stable_commit = repo
		.find_branch("stable", git2::BranchType::Local)?
		.get()
		.peel_to_commit()?;
	let stable_tree = stable_commit.tree()?;

	let total_packages = args.packages.len();
	let mut visited = Vec::new();
	let mut directives = Vec::new();
	let ctx = Arc::new(PkgBreakContext {
		abbs: abbs.clone(),
		http_client: reqwest::ClientBuilder::new()
			.user_agent(format!("BreakIt!/{}", env!("CARGO_PKG_VERSION")))
			.build()?,
	});

	for (index, package) in args.packages.into_iter().enumerate() {
		let package = abbs.find_package(package)?;
		let spec = ApmlContext::eval_source(&fs::read_to_string(
			package.join("spec"),
		)?)?;

		// detect rebuild kind
		let kind = match &args.kind {
			Some(kind) => kind.as_str(),
			None => {
				let head_spec = head_tree.get_path(Path::new(&format!(
					"{}/{}/spec",
					package.section(),
					package.name()
				)))?;
				let head_spec = head_spec.to_object(&repo)?.peel_to_blob()?;
				let head_spec = str::from_utf8(head_spec.content())?;
				let old_spec = ApmlContext::eval_source(head_spec)?;
				if old_spec.get("VER") != spec.get("VER") {
					"update"
				} else {
					"build"
				}
			}
		};

		eprintln!(
			"{} {}/{} ({})",
			style(format!("[{}/{}]", index + 1, total_packages))
				.dim()
				.bold(),
			package.section(),
			package.name(),
			kind
		);
		directives.push(format!("{} ({})", package.name(), kind));

		// collect broken packages
		let broke_packages = ctx.select(&package, kind).await?;

		// resolve versions of broken packages
		let mut broke_reqs = Vec::with_capacity(broke_packages.len());
		for broke_pkg_name in broke_packages {
			let broke_pkg = match abbs.find_subpackage(&broke_pkg_name) {
				Ok(pkg) => pkg,
				Err(AbbsError::PackageNotFound(pkg)) => {
					eprintln!("{pkg} has ben dropped from repository");
					continue;
				}
				Err(err) => return Err(err.into()),
			};
			let srcpkg = broke_pkg.source_package();

			let stable_spec = stable_tree.get_path(Path::new(&format!(
				"{}/{}/spec",
				srcpkg.section(),
				srcpkg.name()
			)));
			let stable_defines = stable_tree.get_path(Path::new(&format!(
				"{}/{}/{}/defines",
				srcpkg.section(),
				srcpkg.name(),
				broke_pkg.dir_name(),
			)));
			match (stable_spec, stable_defines) {
				(Ok(stable_spec), Ok(stable_defines)) => {
					let stable_spec =
						stable_spec.to_object(&repo)?.peel_to_blob()?;
					let stable_spec = str::from_utf8(stable_spec.content())?;
					let stable_spec = ApmlContext::eval_source(stable_spec)?;

					let stable_defines =
						stable_defines.to_object(&repo)?.peel_to_blob()?;
					let stable_defines =
						str::from_utf8(stable_defines.content())?;
					let stable_defines =
						ApmlContext::eval_source(stable_defines)?;

					// build version string
					let mut ver = String::with_capacity(10);

					let epoch = stable_defines
						.get("PKGEPOCH")
						.map(|val| val.as_string());
					if let Some(epoch) = epoch {
						if epoch != "0" {
							ver.push_str(&epoch);
							ver.push(':');
						}
					}

					ver.push_str(&stable_spec.read("VER").into_string());
					let rel = stable_spec.get("REL").map(|val| val.as_string());
					if let Some(rel) = rel {
						if rel != "0" {
							ver.push('-');
							ver.push_str(&rel);
						}
					}

					broke_reqs.push(format!("{}<={}", &broke_pkg_name, ver));
					visited.push((srcpkg.section(), srcpkg.name().to_string()));
				}
				(Err(err), _) | (_, Err(err)) => {
					if !(err.class() == git2::ErrorClass::Tree
						&& err.code() == git2::ErrorCode::NotFound)
					{
						return Err(err.into());
					} else {
						eprintln!("    Skipped: no in stable");
					}
				}
			}
		}
		broke_reqs.sort();

		let pkgbreak_val = StringArray::new(broke_reqs).print();
		// print
		println!("{pkgbreak_val}");

		// write PKGBREAK back
		if args.write {
			let pkgbreak_lst = lst::VariableValue::String(pkgbreak_val.into());
			for subpkg in package.subpackages()? {
				for recipe in subpkg.modifier_suffixes()? {
					let defines_path = subpkg.join(format!("defines{recipe}"));
					let defines_text = fs::read_to_string(&defines_path)?;
					let mut defines_lst = ApmlLst::parse(&defines_text)?;
					let mut defines_editor = ApmlEditor::wrap(&mut defines_lst);
					defines_editor
						.replace_var_lst("PKGBREAK", pkgbreak_lst.clone());

					let defines_text = defines_lst.to_string();
					fs::write(&defines_path, defines_text)?;
					eprintln!("Written to {defines_path:?}");
				}
			}
		}
	}

	visited.sort();
	visited.dedup();

	// write rebuild group
	if let Some(path) = args.write_group {
		let mut file = File::create(tree.join(path))?;
		writeln!(
			file,
			"# Auto-generated by BreakIt! {}, DO NOT EDIT",
			env!("CARGO_PKG_VERSION")
		)?;
		writeln!(file, "# Source: {}", directives.join(", "))?;
		writeln!(file, "# Base commit: {}", head_commit.id())?;

		// write
		for (sec, pkg) in &visited {
			writeln!(file, "{sec}/{pkg}")?;
		}
	}

	// bump REL
	if args.bump_rel {
		let total_visited = visited.len();
		for (index, (sec, pkg)) in visited.iter().enumerate() {
			eprintln!(
				"Bump REL: {} {}/{}",
				style(format!("[{}/{}]", index + 1, total_visited))
					.dim()
					.bold(),
				sec,
				pkg
			);

			let package = abbs.package(sec, pkg).unwrap();
			let spec_path = package.join("spec");
			let spec_src = fs::read_to_string(&spec_path)?;
			let mut spec_lst = ApmlLst::parse(&spec_src)?;
			let spec_ctx = ApmlContext::eval_lst(&spec_lst)?;

			let stable_spec = stable_tree.get_path(Path::new(&format!(
				"{}/{}/spec",
				package.section(),
				package.name()
			)))?;
			let stable_spec = stable_spec.to_object(&repo)?.peel_to_blob()?;
			let stable_spec = str::from_utf8(stable_spec.content())?;
			let stable_spec = ApmlContext::eval_source(stable_spec)?;

			let [stable_ver, current_ver] =
				[&stable_spec, &spec_ctx].map(|spec| {
					format!(
						"{}:{}",
						spec.read("VER").into_string(),
						spec.read("REL").into_string()
					)
				});
			if current_ver != stable_ver {
				eprintln!(
					"    Skipped: changed since stable, {stable_ver} -> {current_ver}"
				);
				continue;
			}

			let mut spec_editor = ApmlEditor::wrap(&mut spec_lst);
			let new_rel = spec_ctx
				.get("REL")
				.map(|val| {
					val.as_string().parse::<usize>().map(|rel| {
						ast::VariableValue::String((rel + 1).to_string().into())
					})
				})
				.unwrap_or_else(|| {
					Ok(ast::VariableValue::String("1".into()))
				})?;
			spec_editor.replace_var_ast("REL", &new_rel);

			fs::write(spec_path, spec_lst.to_string())?;
		}
	}

	Ok(())
}
