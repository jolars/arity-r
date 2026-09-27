//! Resolve formatter configuration without coupling the formatting engine to disk.

use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

use arity_formatter::{FormatStyle, LineEnding};
use serde::Deserialize;

#[derive(Default, Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
struct Config {
    format: FormatConfig,
    // These settings belong to other CLI operations, but may share the same file.
    #[serde(rename = "exclude")]
    _exclude: Option<Vec<String>>,
    #[serde(rename = "extend-exclude")]
    _extend_exclude: Option<Vec<String>>,
    #[serde(rename = "cache")]
    _cache: Option<bool>,
    #[serde(rename = "lint")]
    _lint: Option<toml::Table>,
    #[serde(rename = "compat")]
    _compat: Option<toml::Table>,
    #[serde(rename = "index")]
    _index: Option<toml::Table>,
}

#[derive(Deserialize)]
#[serde(default, deny_unknown_fields, rename_all = "kebab-case")]
pub struct FormatConfig {
    pub line_width: i32,
    pub indent_width: i32,
    pub line_ending: String,
    // The R package treats explicitly supplied files as R source.
    #[serde(rename = "description")]
    _description: Option<bool>,
}

impl Default for FormatConfig {
    fn default() -> Self {
        let style = FormatStyle::default();
        Self {
            line_width: style.line_width as i32,
            indent_width: style.indent_width as i32,
            line_ending: match style.line_ending {
                LineEnding::Auto => "auto",
                LineEnding::Lf => "lf",
                LineEnding::Crlf => "crlf",
                LineEnding::Native => "native",
            }
            .into(),
            _description: None,
        }
    }
}

impl FormatConfig {
    pub fn resolve(
        anchor: &Path,
        explicit: Option<&Path>,
        no_config: bool,
        fallback: Option<&Path>,
    ) -> Result<Self, String> {
        if no_config {
            return Ok(Self::default());
        }
        if let Some(path) = explicit {
            return Self::load(path);
        }
        if let Some(path) = discover(anchor)? {
            return Self::load(&path);
        }
        if let Some(path) = fallback {
            return Self::load(path);
        }
        Ok(Self::default())
    }

    fn load(path: &Path) -> Result<Self, String> {
        let source = fs::read_to_string(path)
            .map_err(|error| format!("failed to read config `{}`: {error}", path.display()))?;
        let config: Config = toml::from_str(&source)
            .map_err(|error| format!("invalid config `{}`: {error}", path.display()))?;
        let config = config.format;
        for (name, value) in [
            ("line-width", config.line_width),
            ("indent-width", config.indent_width),
        ] {
            if !(super::MIN_WIDTH..=super::MAX_WIDTH).contains(&value) {
                return Err(format!(
                    "invalid config `{}`: `{name}` must be from {} through {}, got {value}",
                    path.display(),
                    super::MIN_WIDTH,
                    super::MAX_WIDTH,
                ));
            }
        }
        if !matches!(
            config.line_ending.as_str(),
            "auto" | "lf" | "crlf" | "native"
        ) {
            return Err(format!(
                "invalid config `{}`: `line-ending` must be one of \"auto\", \"lf\", \"crlf\", or \"native\"",
                path.display(),
            ));
        }
        Ok(config)
    }
}

fn discover(anchor: &Path) -> Result<Option<PathBuf>, String> {
    let anchor = if anchor.is_absolute() {
        anchor.to_path_buf()
    } else {
        std::env::current_dir()
            .map_err(|error| format!("failed to locate working directory for config: {error}"))?
            .join(anchor)
    };
    // An editor may name a buffer in a directory that has not been created yet.
    let mut start = None;
    for directory in anchor.ancestors() {
        match directory.canonicalize() {
            Ok(path) => {
                start = Some(path);
                break;
            }
            Err(error) if error.kind() == ErrorKind::NotFound => continue,
            Err(error) => {
                return Err(format!(
                    "failed to discover config from `{}`: {error}",
                    directory.display(),
                ));
            }
        }
    }
    let Some(start) = start else {
        return Ok(None);
    };
    for directory in start.ancestors() {
        let candidate = directory.join("arity.toml");
        match candidate.try_exists() {
            Ok(true) => return Ok(Some(candidate)),
            Ok(false) => {}
            Err(error) => {
                return Err(format!(
                    "failed to discover config `{}`: {error}",
                    candidate.display(),
                ));
            }
        }
        if directory.join(".git").exists() {
            break;
        }
    }
    Ok(None)
}
