//! AUR RPC client — no external process required.
//! Uses the AUR RPC API at https://aur.archlinux.org/rpc.php

use crate::alpm_db::PackageInfo;
use serde::Deserialize;

const AUR_RPC: &str = "https://aur.archlinux.org/rpc.php";
const USER_AGENT: &str = "omarchy-software/0.1";

#[derive(Debug, Deserialize)]
struct RpcResponse {
    #[serde(rename = "type")]
    result_type: String,
    results: Vec<RpcPackage>,
    #[serde(default)]
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
struct RpcPackage {
    Name: String,
    Version: String,
    Description: String,
    #[serde(default)]
    NumVotes: Option<i32>,
    #[serde(default)]
    OutOfDate: Option<i64>,
}

impl RpcPackage {
    fn into_info(self) -> PackageInfo {
        PackageInfo {
            name: self.Name,
            version: self.Version,
            description: self.Description,
            source: "aur".to_string(),
            repo: "AUR".to_string(),
            installed: false,
            votes: self.NumVotes,
            out_of_date: self.OutOfDate.map(|_| true),
            ..Default::default()
        }
    }
}

fn client() -> reqwest::blocking::Client {
    reqwest::blocking::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .expect("AUR HTTP client")
}

pub fn search(query: &str) -> Result<Vec<PackageInfo>, String> {
    let url = format!("{}?v=5&type=search&arg={}", AUR_RPC, urlencoding(query));
    let resp = client()
        .get(&url)
        .send()
        .map_err(|e| format!("AUR request failed: {e}"))?
        .json::<RpcResponse>()
        .map_err(|e| format!("AUR parse error: {e}"))?;

    if resp.result_type == "error" {
        return Err(resp.error.unwrap_or_else(|| "AUR error".to_string()));
    }

    Ok(resp.results.into_iter().map(|p| p.into_info()).collect())
}

pub fn info_by_name(names: &[String]) -> Result<Vec<PackageInfo>, String> {
    if names.is_empty() {
        return Ok(Vec::new());
    }
    let arg = names.join(",");
    let url = format!("{}?v=5&type=info&arg={}", AUR_RPC, urlencoding(&arg));

    let resp = client()
        .get(&url)
        .send()
        .map_err(|e| format!("AUR request failed: {e}"))?
        .json::<RpcResponse>()
        .map_err(|e| format!("AUR parse error: {e}"))?;

    if resp.result_type == "error" {
        return Err(resp.error.unwrap_or_else(|| "AUR error".to_string()));
    }

    Ok(resp.results.into_iter().map(|p| p.into_info()).collect())
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => {
                out.push_str(&format!("%{:02X}", b));
            }
        }
    }
    out
}
