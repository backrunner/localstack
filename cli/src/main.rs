use anyhow::{anyhow, Context, Result};
use clap::{Args, Parser, Subcommand};
use serde_json::{json, Value};
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

const VERSION: &str = "0.1.0";

#[derive(Parser, Debug)]
#[command(name = "localstack", version = VERSION, about = "管理本机可打开的开发服务，并提供 LocalStack MCP 服务")]
struct Cli {
    #[arg(long, global = true, help = "输出机器可读 JSON")]
    json: bool,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
enum Command {
    #[command(about = "检查 Coordinator 和本地接口")]
    Status,
    #[command(about = "列出当前可打开的本地服务")]
    List,
    #[command(about = "通过 Coordinator 验证并注册一个服务")]
    Register(RegisterArgs),
    #[command(about = "停止一个已验证的服务")]
    Terminate(TerminateArgs),
    #[command(subcommand, about = "安装、运行和诊断 MCP")]
    Mcp(McpCommand),
}

#[derive(Args, Debug)]
struct RegisterArgs {
    #[arg(long)]
    pid: i32,
    #[arg(long)]
    port: u16,
    #[arg(long)]
    url: Option<String>,
    #[arg(long)]
    name: Option<String>,
    #[arg(long)]
    project_root: Option<String>,
}

#[derive(Args, Debug)]
struct TerminateArgs {
    #[arg(long)]
    service_id: String,
    #[arg(long)]
    force: bool,
}

#[derive(Subcommand, Debug)]
enum McpCommand {
    #[command(about = "在 stdio 上运行 MCP server")]
    Serve,
    #[command(about = "安装到 Codex、Claude Code 或 Cursor")]
    Install(TargetArgs),
    #[command(about = "移除 LocalStack MCP 配置")]
    Uninstall(TargetArgs),
    #[command(about = "诊断配置、socket 和版本")]
    Doctor,
}

#[derive(Args, Debug)]
struct TargetArgs {
    #[arg(
        long,
        default_value = "auto",
        help = "codex、claude、cursor、all 或 auto"
    )]
    target: String,
}

fn main() {
    let cli = Cli::parse();
    let json_output = cli.json;
    if let Err(error) = run(cli) {
        if json_output {
            println!(
                "{}",
                serde_json::to_string(&json!({"ok": false, "error": error.to_string()})).unwrap()
            );
        } else {
            eprintln!("localstack: {error:#}");
        }
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> Result<()> {
    match cli.command {
        Command::Status => print_result(cli.json, coordinator_call("system.status", json!({}))?),
        Command::List => print_result(cli.json, coordinator_call("service.list", json!({}))?),
        Command::Register(args) => {
            let source = if env::var_os("LOCALSTACK_MCP_CALL").is_some() {
                "mcp"
            } else {
                "sdk"
            };
            let result = coordinator_call(
                "service.register",
                json!({
                    "pid": args.pid,
                    "port": args.port,
                    "url": args.url,
                    "displayName": args.name,
                    "projectRoot": args.project_root,
                    "source": source,
                }),
            )?;
            print_result(cli.json, result)
        }
        Command::Terminate(args) => {
            let preview = coordinator_call(
                "service.prepareTermination",
                json!({"serviceID": args.service_id}),
            )?;
            let token = preview
                .get("token")
                .and_then(Value::as_str)
                .context("Coordinator 没有返回停止 token")?;
            let result = coordinator_call(
                "service.terminate",
                json!({"serviceID": args.service_id, "token": token, "force": args.force}),
            )?;
            print_result(cli.json, result)
        }
        Command::Mcp(command) => match command {
            McpCommand::Serve => serve_mcp(),
            McpCommand::Install(args) => install_mcp(&args.target, cli.json),
            McpCommand::Uninstall(args) => uninstall_mcp(&args.target, cli.json),
            McpCommand::Doctor => doctor(cli.json),
        },
    }
}

fn coordinator_call(method: &str, params: Value) -> Result<Value> {
    let path = socket_path();
    let mut stream = UnixStream::connect(&path).with_context(|| {
        format!(
            "无法连接 Coordinator socket: {}。请先启动 LocalStackApp 或 LocalStackCoordinator",
            path.display()
        )
    })?;
    stream.set_read_timeout(Some(std::time::Duration::from_secs(5)))?;
    stream.set_write_timeout(Some(std::time::Duration::from_secs(5)))?;
    let request =
        json!({"id": format!("cli-{}", std::process::id()), "method": method, "params": params});
    stream.write_all(serde_json::to_string(&request)?.as_bytes())?;
    stream.write_all(b"\n")?;
    stream.shutdown(std::net::Shutdown::Write)?;
    let mut response = String::new();
    stream.read_to_string(&mut response)?;
    let value: Value =
        serde_json::from_str(response.trim()).context("Coordinator 返回了无效 JSON")?;
    if let Some(error) = value.get("error") {
        let code = error
            .get("code")
            .and_then(Value::as_str)
            .unwrap_or("unknown");
        let message = error
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("unknown error");
        return Err(anyhow!("{code}: {message}"));
    }
    Ok(value.get("result").cloned().unwrap_or(Value::Null))
}

fn print_result(json_output: bool, result: Value) -> Result<()> {
    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({"ok": true, "data": result}))?
        );
    } else if let Some(services) = result.as_array() {
        if services.is_empty() {
            println!("没有可打开的本地服务");
        } else {
            for service in services {
                let name = service
                    .get("displayName")
                    .and_then(Value::as_str)
                    .unwrap_or("未命名服务");
                let url = service.get("url").and_then(Value::as_str).unwrap_or("-");
                let health = service
                    .get("health")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown");
                println!("{name:<28} {url:<34} {health}");
            }
        }
    } else {
        println!("{}", serde_json::to_string_pretty(&result)?);
    }
    Ok(())
}

fn serve_mcp() -> Result<()> {
    let stdin = std::io::stdin();
    for line in BufReader::new(stdin.lock()).lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let request: Value = match serde_json::from_str(&line) {
            Ok(request) => request,
            Err(error) => {
                println!(
                    "{}",
                    serde_json::to_string(
                        &json!({"jsonrpc": "2.0", "id": Value::Null, "error": {"code": -32700, "message": format!("MCP 请求不是有效 JSON: {error}")}})
                    )?
                );
                std::io::stdout().flush()?;
                continue;
            }
        };
        if request.get("id").is_none() {
            continue;
        }
        let response = handle_mcp_request(&request);
        println!("{}", serde_json::to_string(&response)?);
        std::io::stdout().flush()?;
    }
    Ok(())
}

fn handle_mcp_request(request: &Value) -> Value {
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    let method = request.get("method").and_then(Value::as_str).unwrap_or("");
    match method {
        "initialize" => json!({
            "jsonrpc": "2.0", "id": id,
            "result": {"protocolVersion": "2025-06-18", "capabilities": {"tools": {}}, "serverInfo": {"name": "localstack", "version": VERSION}}
        }),
        "tools/list" => json!({"jsonrpc": "2.0", "id": id, "result": {"tools": mcp_tools()}}),
        "tools/call" => {
            let params = request.get("params").cloned().unwrap_or_else(|| json!({}));
            let name = params.get("name").and_then(Value::as_str).unwrap_or("");
            let arguments = params
                .get("arguments")
                .cloned()
                .unwrap_or_else(|| json!({}));
            match call_mcp_tool(name, arguments) {
                Ok(value) => {
                    json!({"jsonrpc": "2.0", "id": id, "result": {"content": [{"type": "text", "text": serde_json::to_string_pretty(&value).unwrap()}]}})
                }
                Err(error) => {
                    json!({"jsonrpc": "2.0", "id": id, "result": {"isError": true, "content": [{"type": "text", "text": error.to_string()}]}})
                }
            }
        }
        _ => {
            json!({"jsonrpc": "2.0", "id": id, "error": {"code": -32601, "message": format!("未知 MCP 方法: {method}")}})
        }
    }
}

fn mcp_tools() -> Value {
    json!([
        {"name": "localstack_register_service", "description": "验证并注册一个可访问的本地 HTML 开发服务", "inputSchema": {"type": "object", "required": ["pid", "port"], "properties": {"pid": {"type": "integer"}, "port": {"type": "integer"}, "url": {"type": "string"}, "displayName": {"type": "string"}, "projectRoot": {"type": "string"}}}},
        {"name": "localstack_list_services", "description": "列出当前已验证、可以在浏览器中打开的本地服务", "inputSchema": {"type": "object", "properties": {}}},
        {"name": "localstack_terminate_service", "description": "按精确 serviceId 停止一个本地服务，默认发送 SIGTERM", "inputSchema": {"type": "object", "required": ["serviceId"], "properties": {"serviceId": {"type": "string"}, "force": {"type": "boolean"}}}}
    ])
}

fn call_mcp_tool(name: &str, arguments: Value) -> Result<Value> {
    match name {
        "localstack_list_services" => coordinator_call("service.list", json!({})),
        "localstack_register_service" => {
            let pid = arguments
                .get("pid")
                .and_then(Value::as_i64)
                .context("缺少 pid")?;
            let port = arguments
                .get("port")
                .and_then(Value::as_i64)
                .context("缺少 port")?;
            coordinator_call(
                "service.register",
                json!({
                    "pid": pid, "port": port, "url": arguments.get("url"), "displayName": arguments.get("displayName"), "projectRoot": arguments.get("projectRoot"), "source": "mcp"
                }),
            )
        }
        "localstack_terminate_service" => {
            let service_id = arguments
                .get("serviceId")
                .and_then(Value::as_str)
                .context("缺少 serviceId")?;
            let preview = coordinator_call(
                "service.prepareTermination",
                json!({"serviceID": service_id}),
            )?;
            let token = preview
                .get("token")
                .and_then(Value::as_str)
                .context("Coordinator 没有返回停止 token")?;
            coordinator_call(
                "service.terminate",
                json!({"serviceID": service_id, "token": token, "force": arguments.get("force").and_then(Value::as_bool).unwrap_or(false)}),
            )
        }
        _ => Err(anyhow!("未知 MCP 工具: {name}")),
    }
}

fn install_mcp(target: &str, json_output: bool) -> Result<()> {
    let targets = selected_targets(target)?;
    let command = env::current_exe()?.to_string_lossy().to_string();
    let mut installed = Vec::new();
    for name in targets {
        let path = config_path(&name);
        if name == "codex" {
            let mut root = read_toml_or_empty(&path)?;
            let servers = root
                .as_table_mut()
                .context("Codex 配置根节点必须是 TOML table")?
                .entry("mcp_servers")
                .or_insert_with(|| toml::Value::Table(toml::map::Map::new()));
            let server = servers
                .as_table_mut()
                .context("mcp_servers 必须是 TOML table")?
                .entry("localstack")
                .or_insert_with(|| toml::Value::Table(toml::map::Map::new()));
            let table = server
                .as_table_mut()
                .context("mcp_servers.localstack 必须是 TOML table")?;
            table.insert("command".into(), toml::Value::String(command.clone()));
            table.insert(
                "args".into(),
                toml::Value::Array(vec![
                    toml::Value::String("mcp".into()),
                    toml::Value::String("serve".into()),
                ]),
            );
            write_toml_config(&path, &root)?;
        } else {
            let mut root = read_json_or_empty(&path)?;
            let servers = root
                .as_object_mut()
                .context("MCP 配置根节点必须是 JSON object")?
                .entry("mcpServers")
                .or_insert_with(|| json!({}));
            servers
                .as_object_mut()
                .context("mcpServers 必须是 JSON object")?
                .insert(
                    "localstack".to_string(),
                    json!({"command": command, "args": ["mcp", "serve"]}),
                );
            write_config(&path, &root)?;
        }
        installed.push(name);
    }
    let result = json!({"installed": installed});
    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({"ok": true, "data": result}))?
        );
    } else {
        println!("已安装 LocalStack MCP：{}", installed.join(", "));
    }
    Ok(())
}

fn uninstall_mcp(target: &str, json_output: bool) -> Result<()> {
    let targets = selected_targets(target)?;
    let mut removed = Vec::new();
    for name in targets {
        let path = config_path(&name);
        if !path.exists() {
            continue;
        }
        if name == "codex" {
            let mut root = read_toml_or_empty(&path)?;
            if let Some(servers) = root
                .get_mut("mcp_servers")
                .and_then(toml::Value::as_table_mut)
            {
                servers.remove("localstack");
            }
            write_toml_config(&path, &root)?;
        } else {
            let mut root = read_json_or_empty(&path)?;
            if let Some(servers) = root.get_mut("mcpServers").and_then(Value::as_object_mut) {
                servers.remove("localstack");
            }
            write_config(&path, &root)?;
        }
        removed.push(name);
    }
    let result = json!({"removed": removed});
    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({"ok": true, "data": result}))?
        );
    } else {
        println!("已移除 LocalStack MCP：{}", removed.join(", "));
    }
    Ok(())
}

fn doctor(json_output: bool) -> Result<()> {
    let socket = socket_path();
    let coordinator = coordinator_call("system.status", json!({}));
    let targets = ["codex", "claude", "cursor"].iter().map(|name| json!({"name": name, "config": config_path(name), "exists": config_path(name).exists()})).collect::<Vec<_>>();
    let result = json!({"version": VERSION, "socket": socket, "socketExists": socket.exists(), "coordinator": coordinator.as_ref().ok(), "targets": targets});
    if coordinator.is_err() {
        return Err(anyhow!("Coordinator 不可用：{}", coordinator.unwrap_err()));
    }
    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({"ok": coordinator.is_ok(), "data": result}))?
        );
    } else {
        println!("{}", serde_json::to_string_pretty(&result)?);
    }
    Ok(())
}

fn selected_targets(target: &str) -> Result<Vec<String>> {
    match target {
        "all" => Ok(vec!["codex".into(), "claude".into(), "cursor".into()]),
        "auto" => Ok(vec![
            "codex".to_string(),
            "claude".to_string(),
            "cursor".to_string(),
        ]
        .into_iter()
        .filter(|name| config_path(name).exists())
        .collect()),
        "codex" | "claude" | "cursor" => Ok(vec![target.to_string()]),
        _ => Err(anyhow!(
            "未知 target: {target}，可用 codex、claude、cursor、all、auto"
        )),
    }
}

fn config_path(target: &str) -> PathBuf {
    let home = env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    match target {
        "codex" => home.join(".codex/config.toml"),
        "claude" => home.join(".claude.json"),
        "cursor" => home.join(".cursor/mcp.json"),
        _ => home.join(".config/localstack/unknown.json"),
    }
}

fn read_json_or_empty(path: &Path) -> Result<Value> {
    if !path.exists() {
        return Ok(json!({}));
    }
    let data = fs::read_to_string(path).with_context(|| format!("无法读取 {}", path.display()))?;
    serde_json::from_str(&data)
        .with_context(|| format!("{} 不是有效 JSON，拒绝覆盖", path.display()))
}

fn read_toml_or_empty(path: &Path) -> Result<toml::Value> {
    if !path.exists() {
        return Ok(toml::Value::Table(toml::map::Map::new()));
    }
    let data = fs::read_to_string(path).with_context(|| format!("无法读取 {}", path.display()))?;
    toml::from_str::<toml::Table>(&data)
        .map(toml::Value::Table)
        .with_context(|| format!("{} 不是有效 TOML，拒绝覆盖", path.display()))
}

fn write_config(path: &Path, value: &Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        fs::copy(path, backup_path(path))?;
    }
    atomic_write(path, &serde_json::to_vec_pretty(value)?)?;
    Ok(())
}

fn write_toml_config(path: &Path, value: &toml::Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        fs::copy(path, backup_path(path))?;
    }
    atomic_write(path, toml::to_string_pretty(value)?.as_bytes())?;
    Ok(())
}

fn backup_path(path: &Path) -> PathBuf {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or_default();
    let name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("config");
    path.with_file_name(format!("{name}.bak-{stamp}-{}", std::process::id()))
}

fn atomic_write(path: &Path, data: &[u8]) -> Result<()> {
    let parent = path.parent().context("配置路径没有父目录")?;
    let temp = parent.join(format!(
        ".{}.tmp-{}",
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("config"),
        std::process::id()
    ));
    let mode = fs::metadata(path)
        .map(|metadata| metadata.permissions().mode() & 0o777)
        .unwrap_or(0o600);
    fs::write(&temp, data)?;
    fs::set_permissions(&temp, fs::Permissions::from_mode(mode))?;
    if let Err(error) = fs::rename(&temp, path) {
        let _ = fs::remove_file(&temp);
        return Err(error.into());
    }
    Ok(())
}

fn socket_path() -> PathBuf {
    env::var_os("LOCALSTACK_SOCKET")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            env::var_os("HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."))
                .join("Library/Application Support/LocalStack/coordinator.sock")
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mcp_exposes_the_three_product_tools() {
        let value = mcp_tools();
        let tools = value.as_array().expect("tools array");
        assert_eq!(tools.len(), 3);
        assert_eq!(tools[0]["name"], "localstack_register_service");
        assert_eq!(tools[1]["name"], "localstack_list_services");
        assert_eq!(tools[2]["name"], "localstack_terminate_service");
    }

    #[test]
    fn target_selection_rejects_unknown_agents() {
        assert!(selected_targets("unknown-agent").is_err());
        assert_eq!(
            selected_targets("codex").unwrap(),
            vec!["codex".to_string()]
        );
    }

    #[test]
    fn codex_toml_adapter_round_trips() {
        let path =
            std::env::temp_dir().join(format!("localstack-config-{}.toml", std::process::id()));
        let mut root = toml::Value::Table(toml::map::Map::new());
        let mut server = toml::map::Map::new();
        server.insert("command".into(), toml::Value::String("localstack".into()));
        let mut servers = toml::map::Map::new();
        servers.insert("localstack".into(), toml::Value::Table(server));
        root.as_table_mut()
            .unwrap()
            .insert("mcp_servers".into(), toml::Value::Table(servers));
        write_toml_config(&path, &root).unwrap();
        let loaded = read_toml_or_empty(&path).unwrap();
        assert!(loaded.get("mcp_servers").is_some());
        fs::remove_file(path).unwrap();
    }
}
