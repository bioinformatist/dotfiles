use std::env;
use std::error::Error;
use std::path::PathBuf;
use std::process::Command;

use leptos_i18n_build::{Config, TranslationsInfos};
use serde_json::Value;

fn repo_root() -> PathBuf {
    PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is set")).join("../..")
}

fn command_output(program: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(program)
        .args(args)
        .current_dir(repo_root())
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    String::from_utf8(output.stdout)
        .ok()
        .map(|s| s.trim().to_owned())
}

fn flake_metadata(target: &str) -> Option<Value> {
    command_output("nix", &["flake", "metadata", "--json", target])
        .and_then(|output| serde_json::from_str(&output).ok())
}

fn metadata_string(metadata: Option<&Value>, pointer: &str) -> Option<String> {
    metadata?.pointer(pointer)?.as_str().map(ToOwned::to_owned)
}

fn metadata_number(metadata: Option<&Value>, pointer: &str) -> Option<String> {
    metadata?
        .pointer(pointer)?
        .as_u64()
        .map(|value| value.to_string())
}

fn generate_i18n() -> Result<(), Box<dyn Error>> {
    println!("cargo:rerun-if-changed=locales");
    let i18n_mod_directory =
        PathBuf::from(env::var_os("OUT_DIR").expect("OUT_DIR is set")).join("i18n");
    let config = Config::new("en")?.add_locale("zh-CN")?;
    let translations = TranslationsInfos::parse(config)?;
    translations.emit_diagnostics();
    translations.rerun_if_locales_changed();
    translations.generate_i18n_module(i18n_mod_directory)?;
    Ok(())
}

fn main() {
    println!("cargo:rerun-if-changed=../../flake.lock");
    println!("cargo:rerun-if-changed=../../.git/HEAD");
    generate_i18n().expect("i18n code generation succeeds");

    let git_rev = command_output("git", &["rev-parse", "HEAD"]);
    let clean_metadata = git_rev.as_deref().and_then(|rev| {
        let target = format!("git+file://{}?rev={rev}", repo_root().display());
        flake_metadata(&target)
    });
    let current_metadata = flake_metadata(".");

    let rev = env::var("DOTFILES_GENERATOR_UPSTREAM_REV")
        .ok()
        .or_else(|| metadata_string(clean_metadata.as_ref(), "/locked/rev"))
        .or(git_rev)
        .or_else(|| metadata_string(current_metadata.as_ref(), "/locked/rev"))
        .or_else(|| metadata_string(current_metadata.as_ref(), "/locked/dirtyRev"))
        .unwrap_or_else(|| "UNKNOWN_REV".to_owned());

    let last_modified = env::var("DOTFILES_GENERATOR_UPSTREAM_LAST_MODIFIED")
        .ok()
        .or_else(|| command_output("git", &["log", "-1", "--format=%ct"]))
        .or_else(|| metadata_number(clean_metadata.as_ref(), "/locked/lastModified"))
        .or_else(|| metadata_number(current_metadata.as_ref(), "/locked/lastModified"))
        .or_else(|| metadata_number(current_metadata.as_ref(), "/lastModified"))
        .unwrap_or_else(|| "0".to_owned());

    let nar_hash = env::var("DOTFILES_GENERATOR_UPSTREAM_NAR_HASH")
        .ok()
        .or_else(|| metadata_string(clean_metadata.as_ref(), "/locked/narHash"))
        .or_else(|| metadata_string(current_metadata.as_ref(), "/locked/narHash"))
        .unwrap_or_else(|| "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".to_owned());

    println!("cargo:rustc-env=DOTFILES_GENERATOR_UPSTREAM_REV={rev}");
    println!("cargo:rustc-env=DOTFILES_GENERATOR_UPSTREAM_LAST_MODIFIED={last_modified}");
    println!("cargo:rustc-env=DOTFILES_GENERATOR_UPSTREAM_NAR_HASH={nar_hash}");
}
