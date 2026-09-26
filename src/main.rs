//! omarchy-software-core — Omarchy Software
//! Command-line worker: JSON over stdin/stdout.
//! Started by the Qt GUI; the two processes communicate over newline-delimited JSON on stdin/stdout.

mod alpm_db;
mod aur;
mod config;
mod process;
mod theme;
mod transaction;

use alpm_db::DbHandle;
use serde_json::{json, Value};
use std::io::{self, BufRead, Read, Write};

fn main() {
    if let Err(e) = theme::init_logging() {
        eprintln!("Cannot initialise logging: {e}");
    }

    let mut db = match DbHandle::new() {
        Ok(db) => db,
        Err(e) => {
            eprintln!("Cannot initialise package database: {e}");
            std::process::exit(1);
        }
    };

    let theme = theme::Theme::load();
    let config = config::Config::load();

    if let Err(e) = process::install_cancellation() {
        eprintln!("Cannot install worker shutdown handler: {e}");
    }

    let mut cache = Cache::default();
    let stdin = io::stdin();
    let mut stdout = io::BufWriter::new(io::stdout());
    let mut input = stdin.lock();

    while !process::cancelled() {
        let Ok(Some(line)) = request_line(&mut input) else {
            break;
        };

        let response = match serde_json::from_str::<Value>(&line) {
            Ok(req) => handle(&req, &mut db, &theme, &config, &mut cache),
            Err(_) => json!({"kind": "error", "message": "Malformed request"}),
        };

        if write_response(&mut stdout, &response).is_err() {
            break;
        }
    }
}

// ── Request routing ─────────────────────────────────────────────────────────

fn handle(
    req: &Value,
    db: &mut DbHandle,
    theme: &theme::Theme,
    config: &config::Config,
    cache: &mut Cache,
) -> Value {
    match req["op"].as_str().unwrap_or("") {
        "search" => {
            let query = req["query"].as_str().unwrap_or("");
            let source = req["source"].as_str().unwrap_or("all");
            let repository = req["repository"].as_str().unwrap_or("");
            let category = req["category"].as_str().unwrap_or("all");
            search(db, query, source, repository, category, config)
        }
        "installed" => installed(db, req, config),
        "updates" => updates(db, cache),
        "refresh" => refresh(db, cache),
        "preview_install" => preview_install(db, req),
        "preview_updates" => preview_updates(db),
        "preview_remove" => preview_remove(db, req, config),
        "commit" => commit(db, req, config, cache),
        "cancel" => {
            db.interrupt();
            json!({"kind": "action", "results": [{"ok": true, "message": "Operation cancelled"}]})
        }
        "cancel_preview" => {
            cache.preview = None;
            json!({"kind": "action", "results": [{"ok": true, "message": "Preview cleared"}]})
        }
        "aur_info" => aur_info(req),
        "theme" => json!({
            "kind": "theme",
            "colors": serde_json::to_value(theme).unwrap()
        }),
        "quit" => {
            std::process::exit(0);
        }
        _ => json!({"kind": "error", "message": "Unknown request"}),
    }
}

// ── Operations ───────────────────────────────────────────────────────────────

fn search(
    db: &DbHandle,
    query: &str,
    source: &str,
    repository: &str,
    category: &str,
    config: &config::Config,
) -> Value {
    let mut results: Vec<Value> = Vec::new();
    // Empty queries browse sync repository packages. The AUR API requires a
    // meaningful search term, so it is queried only for non-empty searches.
    let mut categories = Vec::new();

    if source != "aur" {
        let (packages, package_categories) = db.search_repo(query, repository);
        categories = package_categories;

        for mut pkg in packages {
            let category_matches = match category {
                "all" | "" => true,
                "Uncategorized" => pkg.groups.is_empty(),
                selected => pkg.groups.iter().any(|group| group == selected),
            };
            if !category_matches {
                continue;
            }
            pkg.protected = is_protected(config, &pkg.name);
            results.push(json!({
                "name": pkg.name,
                "version": pkg.version,
                "description": pkg.description,
                "source": "repo",
                "repo": pkg.repo,
                "installed": pkg.installed,
                "protected": pkg.protected,
                "groups": pkg.groups,
                "size": pkg.size,
            }));
        }
    }

    if source != "repo"
        && !query.is_empty()
        && repository.is_empty()
        && (category == "all" || category.is_empty())
    {
        // AUR search is blocking — run in a thread pool to avoid blocking
        if let Ok(Ok(aur_results)) = std::thread::scope(|s| {
            s.spawn(|| aur::search(query)).join()
        }) {
            for pkg in aur_results {
                let installed = db.is_installed(&pkg.name);
                results.push(json!({
                    "name": pkg.name,
                    "version": pkg.version,
                    "description": pkg.description,
                    "source": "aur",
                    "repo": "AUR",
                    "installed": installed,
                    "protected": is_protected(config, &pkg.name),
                    "groups": [],
                    "votes": pkg.votes,
                }));
            }
        }
    }

    results.sort_by(|left, right| {
        let left_source = left["source"].as_str().unwrap_or("");
        let right_source = right["source"].as_str().unwrap_or("");
        left["name"]
            .as_str()
            .unwrap_or("")
            .cmp(right["name"].as_str().unwrap_or(""))
            .then_with(|| left["repo"].as_str().unwrap_or("").cmp(right["repo"].as_str().unwrap_or("")))
            .then_with(|| left["version"].as_str().unwrap_or("").cmp(right["version"].as_str().unwrap_or("")))
            .then_with(|| left_source.cmp(right_source))
    });

    json!({
        "kind": "search_results",
        "results": results,
        "categories": categories,
        "repositories": db.repository_names(),
    })
}

fn installed(db: &DbHandle, req: &Value, config: &config::Config) -> Value {
    let filter = req["filter"].as_str().unwrap_or("all");
    let sort = req["sort"].as_str().unwrap_or("name");
    let reverse = req["reverse"].as_bool().unwrap_or(false);

    let packages = db.installed_packages(filter, sort, reverse);
    let total_size: u64 = packages.iter().map(|p| p.size).sum();
    let package_values: Vec<Value> = packages
        .into_iter()
        .map(|mut package| {
            package.protected = is_protected(config, &package.name);
            serde_json::to_value(package).unwrap()
        })
        .collect();

    json!({
        "kind": "installed",
        "packages": package_values,
        "total_count": package_values.len(),
        "total_size": total_size,
    })
}

fn updates(db: &DbHandle, cache: &mut Cache) -> Value {
    if let Some(cached) = &cache.updates {
        if cached.0.elapsed().as_secs() < 300 {
            return cached.1.clone();
        }
    }

    let (repos, aur) = db.check_updates();
    let total = repos.len() + aur.len();

    let result = json!({
        "kind": "updates",
        "repos": repos.into_iter().map(|p| serde_json::to_value(p).unwrap()).collect::<Vec<Value>>(),
        "aur": aur.into_iter().map(|p| serde_json::to_value(p).unwrap()).collect::<Vec<Value>>(),
        "total": total,
        "timestamp": std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0),
    });

    cache.updates = Some((std::time::Instant::now(), result.clone()));
    result
}

fn refresh(db: &mut DbHandle, cache: &mut Cache) -> Value {
    match db.refresh() {
        Ok(msg) => {
            cache.updates = None;
            json!({"kind": "action", "results": [{"ok": true, "message": msg}]})
        }
        Err(e) => json!({"kind": "error", "message": e}),
    }
}

fn preview_install(db: &mut DbHandle, req: &Value) -> Value {
    let packages: Vec<String> = serde_json::from_value(req["packages"].clone())
        .unwrap_or_default();
    let sources: Vec<String> = serde_json::from_value(req["sources"].clone())
        .unwrap_or_default();

    if packages.is_empty() {
        return json!({"kind": "error", "message": "No packages specified"});
    }

    if sources.len() != packages.len() {
        return json!({"kind": "error", "message": "Package source information is incomplete"});
    }
    let unsupported: Vec<_> = packages.iter().zip(&sources)
        .filter(|(_, source)| source.as_str() != "repo")
        .map(|(name, _)| name.clone()).collect();
    if !unsupported.is_empty() {
        return json!({"kind": "error", "message": format!(
            "Cannot install unsupported package sources: {}", unsupported.join(", "))});
    }

    let mut preview = transaction::Preview::new();

    let repo_pkgs: Vec<String> = packages
        .iter()
        .zip(sources.iter())
        .filter(|(_, s)| s.as_str() != "aur")
        .map(|(n, _)| n.clone())
        .collect();

    if !repo_pkgs.is_empty() {
        if let Err(e) = db.preview_install(&repo_pkgs, &mut preview) {
            return json!({"kind": "error", "message": e});
        }
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn preview_updates(db: &DbHandle) -> Value {
    let (packages, _) = db.check_updates();
    if packages.is_empty() {
        return json!({"kind": "error", "message": "No repository updates are available"});
    }
    let mut preview = transaction::Preview::new();
    preview.system_upgrade = true;
    preview.install = packages;
    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn preview_remove(db: &mut DbHandle, req: &Value, config: &config::Config) -> Value {
    let packages: Vec<String> = serde_json::from_value(req["packages"].clone())
        .unwrap_or_default();

    if packages.is_empty() {
        return json!({"kind": "error", "message": "No packages specified"});
    }
    let blocked: Vec<_> = packages
        .iter()
        .filter(|name| is_protected(config, name))
        .cloned()
        .collect();
    if !blocked.is_empty() {
        return json!({
            "kind": "error",
            "message": format!("Protected packages cannot be removed: {}", blocked.join(", ")),
        });
    }

    let mut preview = transaction::Preview::new();
    if let Err(e) = db.preview_remove(&packages, &mut preview) {
        return json!({"kind": "error", "message": e});
    }

    let blocked_cascade: Vec<_> = preview
        .all_removing()
        .iter()
        .filter(|package| is_protected(config, &package.name))
        .map(|package| package.name.clone())
        .collect();
    if !blocked_cascade.is_empty() {
        return json!({
            "kind": "error",
            "message": format!("Removal would include protected packages: {}", blocked_cascade.join(", ")),
        });
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn commit(db: &mut DbHandle, req: &Value, config: &config::Config, cache: &mut Cache) -> Value {
    let preview_map = match req["preview"].as_object() {
        Some(m) => m.clone(),
        _ => return json!({"kind": "error", "message": "Invalid preview"}),
    };

    let preview: transaction::Preview = match serde_json::from_value(serde_json::Value::Object(preview_map)) {
        Ok(p) => p,
        Err(e) => return json!({"kind": "error", "message": format!("Cannot parse preview: {e}")}),
    };

    let blocked: Vec<_> = preview
        .all_removing()
        .into_iter()
        .filter(|package| is_protected(config, &package.name))
        .map(|package| package.name.clone())
        .collect();
    if !blocked.is_empty() {
        return json!({
            "kind": "error",
            "message": format!("Protected packages cannot be removed: {}", blocked.join(", ")),
        });
    }

    match db.commit(&preview) {
        Ok(out) => {
            // The installed set and version table just changed, so the
            // cached updates list is stale — drop it so the next
            // checkUpdates() call re-queries pacman.
            cache.updates = None;
            json!({"kind": "commit_result", "ok": true, "output": out})
        }
        Err(e) => json!({"kind": "error", "message": e}),
    }
}

fn is_protected(config: &config::Config, name: &str) -> bool {
    config.protected_packages.iter().any(|protected| protected == name)
}

fn aur_info(req: &Value) -> Value {
    let packages: Vec<String> = req["packages"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v["name"].as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default();

    if packages.is_empty() {
        return json!({"kind": "aur_info", "packages": []});
    }

    match aur::info_by_name(&packages) {
        Ok(infos) => {
            let vals: Vec<Value> = infos.into_iter().map(|p| serde_json::to_value(p).unwrap()).collect();
            json!({"kind": "aur_info", "packages": vals})
        }
        Err(e) => json!({"kind": "aur_info", "packages": [], "error": e}),
    }
}

// ── Protocol helpers ─────────────────────────────────────────────────────────

const RESPONSE_LIMIT: usize = 16 * 1024 * 1024;

fn write_response(output: &mut impl Write, response: &Value) -> io::Result<()> {
    let mut buffer = process::BoundedBuffer::new(RESPONSE_LIMIT);
    if serde_json::to_writer(&mut buffer, response).is_err() {
        buffer = process::BoundedBuffer::new(RESPONSE_LIMIT);
        serde_json::to_writer(
            &mut buffer,
            &json!({"kind": "error", "message": "Response exceeds 16 MiB"}),
        )
        .ok();
    }
    output.write_all(buffer.bytes())?;
    output.write_all(b"\n")?;
    output.flush()
}

const REQUEST_LIMIT: u64 = 1024 * 1024;

fn request_line(input: &mut impl BufRead) -> io::Result<Option<String>> {
    let mut line = String::new();
    let read = input.take(REQUEST_LIMIT + 1).read_line(&mut line)?;
    if read as u64 > REQUEST_LIMIT {
        return Err(io::Error::other("Request exceeds limit"));
    }
    Ok((read > 0).then_some(line))
}

// ── Cache ───────────────────────────────────────────────────────────────────

#[derive(Default)]
struct Cache {
    updates: Option<(std::time::Instant, Value)>,
    preview: Option<transaction::Preview>,
}
