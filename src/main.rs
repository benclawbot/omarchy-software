//! omarchy-software-core — Omarchy Software
//! Command-line worker that speaks JSON over stdin/stdout.
//! Started by the Qt GUI; the two processes communicate over a Unix socket.

mod alpm_db;
mod aur;
mod config;
mod process;
mod theme;
mod transaction;

use alpm_db::Db;
use serde_json::{json, Value};
use std::collections::HashSet;
use std::io::{self, BufRead, Read, Write};
use std::sync::Arc;
use parking_lot::Mutex;

fn main() {
    // Initialise tracing to XDG_STATE_HOME/omarchy-software/logs
    if let Err(e) = theme::init_logging() {
        eprintln!("Cannot initialise logging: {e}");
    }

    let db = match Db::new() {
        Ok(db) => Arc::new(Mutex::new(db)),
        Err(e) => {
            eprintln!("Cannot initialise package database: {e}");
            std::process::exit(1);
        }
    };

    let theme = theme::Theme::load();

    if let Err(e) = process::install_cancellation() {
        eprintln!("Cannot install worker shutdown handler: {e}");
    }

    let mut cache = CACHE::default();
    let stdin = io::stdin();
    let mut stdout = io::BufWriter::new(io::stdout());
    let mut input = stdin.lock();

    while !process::cancelled() {
        let Ok(Some(line)) = request_line(&mut input) else {
            break;
        };

        let response = match serde_json::from_str::<Value>(&line) {
            Ok(req) => handle(&req, &db, &theme, &mut cache),
            Err(_) => json!({"kind": "error", "message": "Malformed request"}),
        };

        if write_response(&mut stdout, &response).is_err() {
            break;
        }
    }
}

// ── Request routing ─────────────────────────────────────────────────────────

fn handle(req: &Value, db: &Arc<Mutex<Db>>, theme: &theme::Theme, cache: &mut Cache) -> Value {
    match req["op"].as_str().unwrap_or("") {
        "search" => {
            let query = req["query"].as_str().unwrap_or("");
            let source = req["source"].as_str().unwrap_or("all"); // all | repo | aur
            search(db, query, source)
        }
        "installed" => installed(db, req),
        "updates" => updates(db, cache),
        "refresh" => refresh(db, cache),
        "preview_install" => preview_install(db, req),
        "preview_remove" => preview_remove(db, req),
        "commit" => commit(db, req),
        "cancel" => {
            process::cancel();
            json!({"kind": "action", "results": [{"ok": true, "message": "Operation cancelled"}]})
        }
        "cancel_preview" => {
            // Drop any pending preview from cache
            cache.preview = None;
            json!({"kind": "action", "results": [{"ok": true, "message": "Preview cleared"}]})
        }
        "cache_clean" => cache_clean(req),
        "aur_info" => aur::info(req["packages"].as_array().cloned().unwrap_or_default()),
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

fn search(db: &Arc<Mutex<Db>>, query: &str, source: &str) -> Value {
    let db = db.lock();

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
        // AUR search is blocking; run in a blocking task to avoid blocking the thread
        if let Ok(aur_results) = std::thread::scope(|s| {
            s.spawn(|| aur::search(query)).join()
        }) {
            if let Ok(results) = aur_results {
                for pkg in results {
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
    }

    json!({"kind": "search_results", "results": results})
}

fn installed(db: &Arc<Mutex<Db>>, req: &Value) -> Value {
    let db = db.lock();
    let filter = req["filter"].as_str().unwrap_or("all"); // all | explicit | dependency | orphan
    let sort = req["sort"].as_str().unwrap_or("name");
    let reverse = req["reverse"].as_bool().unwrap_or(false);

    let packages = db.installed_packages(filter, sort, reverse);
    let total_size: u64 = packages.iter().map(|p| p.size).sum();

    json!({
        "kind": "installed",
        "packages": packages,
        "total_count": packages.len(),
        "total_size": total_size,
    })
}

fn updates(db: &Arc<Mutex<Db>>, cache: &mut Cache) -> Value {
    // Cache updates for 5 minutes to avoid hammering the mirror on every refresh
    if let Some(cached) = &cache.updates {
        if cached.0.elapsed().as_secs() < 300 {
            return cached.1.clone();
        }
    }

    let db = db.lock();
    let (repos, aur) = db.check_updates();

    let result = json!({
        "kind": "updates",
        "repos": repos,
        "aur": aur,
        "total": repos.len() + aur.len(),
        "timestamp": std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0),
    });

    cache.updates = Some((std::time::Instant::now(), result.clone()));
    result
}

fn refresh(db: &Arc<Mutex<Db>>, cache: &mut Cache) -> Value {
    let db = db.lock();
    match db.refresh() {
        Ok(msg) => {
            cache.updates = None; // invalidate cache
            json!({"kind": "action", "results": [{"ok": true, "message": msg}]})
        }
        Err(e) => json!({"kind": "error", "message": e}),
    }
}

fn preview_install(db: &Arc<Mutex<Db>>, req: &Value) -> Value {
    let packages: Vec<String> = serde_json::from_value(req["packages"].clone())
        .unwrap_or_default();
    let sources: Vec<String> = serde_json::from_value(req["sources"].clone())
        .unwrap_or_default(); // "repo" or "aur"

    if packages.is_empty() {
        return json!({"kind": "error", "message": "No packages specified"});
    }

    let mut to_install = Vec::new();
    let mut to_build = Vec::new();

    for (i, name) in packages.iter().enumerate() {
        let source = sources.get(i).map(|s| s.as_str()).unwrap_or("repo");
        if source == "aur" {
            to_build.push(name.clone());
        } else {
            to_install.push(name.clone());
        }
    }

    let db = db.lock();
    let mut preview = transaction::Preview::new();

    if !to_install.is_empty() {
        if let Err(e) = db.preview_install(&to_install, &mut preview) {
            return json!({"kind": "error", "message": e});
        }
    }

    drop(db); // release lock before potentially blocking AUR fetch

    if !to_build.is_empty() {
        // AUR info fetch is blocking
        if let Ok(aur_info) = std::thread::scope(|s| {
            s.spawn(|| aur::info_by_name(&to_build)).join()
        }) {
            if let Ok(aur_info) = aur_info {
                for pkg in aur_info {
                    preview.add_install_aur(&pkg);
                }
            }
        }
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn preview_remove(db: &Arc<Mutex<Db>>, req: &Value) -> Value {
    let packages: Vec<String> = serde_json::from_value(req["packages"].clone())
        .unwrap_or_default();

    if packages.is_empty() {
        return json!({"kind": "error", "message": "No packages specified"});
    }

    let db = db.lock();
    let mut preview = transaction::Preview::new();
    if let Err(e) = db.preview_remove(&packages, &mut preview) {
        return json!({"kind": "error", "message": e});
    }

    json!({"kind": "preview", "preview": serde_json::to_value(&preview).unwrap()})
}

fn commit(db: &Arc<Mutex<Db>>, req: &Value) -> Value {
    let preview_json = match &req["preview"] {
        Value::Object(map) => map.clone(),
        _ => return json!({"kind": "error", "message": "Invalid preview"}),
    };

    let preview: transaction::Preview = match serde_json::from_value(serde_json::Value::Object(preview_json)) {
        Ok(p) => p,
        Err(e) => return json!({"kind": "error", "message": format!("Cannot parse preview: {e}")}),
    };

    let db = db.lock();
    match db.commit(&preview) {
        Ok(out) => json!({
            "kind": "commit_result",
            "ok": true,
            "output": out,
        }),
        Err(e) => json!({"kind": "error", "message": e}),
    }
}

fn cache_clean(req: &Value) -> Value {
    let mode = req["mode"].as_str().unwrap_or("keep_last"); // "all" | "keep_last"
    match transaction::clean_cache(mode) {
        Ok((freed, units)) => json!({
            "kind": "cache_cleaned",
            "freed_bytes": freed,
            "freed_units": units,
        }),
        Err(e) => json!({"kind": "error", "message": e}),
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
    output.write_all(&buffer.bytes)?;
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
