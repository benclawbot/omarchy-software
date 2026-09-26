//! omarchy-software-core — Omarchy Software
//! Command-line worker: JSON over stdin/stdout.
//! Started by the Qt GUI; the two processes communicate over a Unix socket.

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
            Ok(req) => handle(&req, &mut db, &theme, &mut cache),
            Err(_) => json!({"kind": "error", "message": "Malformed request"}),
        };

        if write_response(&mut stdout, &response).is_err() {
            break;
        }
    }
}

// ── Request routing ─────────────────────────────────────────────────────────

fn handle(req: &Value, db: &mut DbHandle, theme: &theme::Theme, cache: &mut Cache) -> Value {
    match req["op"].as_str().unwrap_or("") {
        "search" => {
            let query = req["query"].as_str().unwrap_or("");
            let source = req["source"].as_str().unwrap_or("all");
            search(db, query, source)
        }
        "installed" => installed(db, req),
        "updates" => updates(db, cache),
        "refresh" => refresh(db, cache),
        "preview_install" => preview_install(db, req),
        "preview_remove" => preview_remove(db, req),
        "commit" => commit(db, req),
        "cancel" => {
            db.interrupt();
            json!({"kind": "action", "results": [{"ok": true, "message": "Operation cancelled"}]})
        }
        "cancel_preview" => {
            cache.preview = None;
            json!({"kind": "action", "results": [{"ok": true, "message": "Preview cleared"}]})
        }
        "cache_clean" => cache_clean(req),
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

fn search(db: &DbHandle, query: &str, source: &str) -> Value {
    let mut results: Vec<Value> = Vec::new();

    if source != "aur" {
        for pkg in db.search_repo(query) {
            results.push(json!({
                "name": pkg.name,
                "version": pkg.version,
                "description": pkg.description,
                "source": "repo",
                "repo": pkg.repo,
                "installed": pkg.installed,
                "size": pkg.size,
            }));
        }
    }

    if source != "repo" {
        // AUR search is blocking — run in a thread pool to avoid blocking
        if let Ok(Ok(aur_results)) = std::thread::scope(|s| {
            s.spawn(|| aur::search(query)).join()
        }) {
            for pkg in aur_results {
                results.push(json!({
                    "name": pkg.name,
                    "version": pkg.version,
                    "description": pkg.description,
                    "source": "aur",
                    "repo": "AUR",
                    "installed": false,
                    "votes": pkg.votes,
                }));
            }
        }
    }

    json!({"kind": "search_results", "results": results})
}

fn installed(db: &DbHandle, req: &Value) -> Value {
    let filter = req["filter"].as_str().unwrap_or("all");
    let sort = req["sort"].as_str().unwrap_or("name");
    let reverse = req["reverse"].as_bool().unwrap_or(false);

    let packages = db.installed_packages(filter, sort, reverse);
    let total_size: u64 = packages.iter().map(|p| p.size).sum();
    let package_values: Vec<Value> = packages.into_iter().map(|p| serde_json::to_value(p).unwrap()).collect();

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

    let aur_pkgs: Vec<String> = packages
        .iter()
        .zip(sources.iter())
        .filter(|(_, s)| s.as_str() == "aur")
        .map(|(n, _)| n.clone())
        .collect();

    if !aur_pkgs.is_empty() {
        if let Ok(Ok(aur_info)) = std::thread::scope(|s| {
            s.spawn(|| aur::info_by_name(&aur_pkgs)).join()
        }) {
            for pkg in aur_info {
                preview.add_install_aur(&pkg);
            }
        }
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn preview_remove(db: &mut DbHandle, req: &Value) -> Value {
    let packages: Vec<String> = serde_json::from_value(req["packages"].clone())
        .unwrap_or_default();

    if packages.is_empty() {
        return json!({"kind": "error", "message": "No packages specified"});
    }

    let mut preview = transaction::Preview::new();
    if let Err(e) = db.preview_remove(&packages, &mut preview) {
        return json!({"kind": "error", "message": e});
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn commit(db: &mut DbHandle, req: &Value) -> Value {
    let preview_map = match req["preview"].as_object() {
        Some(m) => m.clone(),
        _ => return json!({"kind": "error", "message": "Invalid preview"}),
    };

    let preview: transaction::Preview = match serde_json::from_value(serde_json::Value::Object(preview_map)) {
        Ok(p) => p,
        Err(e) => return json!({"kind": "error", "message": format!("Cannot parse preview: {e}")}),
    };

    match db.commit(&preview) {
        Ok(out) => json!({"kind": "commit_result", "ok": true, "output": out}),
        Err(e) => json!({"kind": "error", "message": e}),
    }
}

fn cache_clean(req: &Value) -> Value {
    let mode = req["mode"].as_str().unwrap_or("keep_last");
    match transaction::clean_cache(mode) {
        Ok((freed, units)) => json!({
            "kind": "cache_cleaned",
            "freed_bytes": freed,
            "freed_units": units,
        }),
        Err(e) => json!({"kind": "error", "message": e}),
    }
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
