use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    process::Command,
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    },
};

use tauri::{
    menu::{AboutMetadata, IsMenuItem, Menu, MenuItem, PredefinedMenuItem, Submenu},
    AppHandle, Emitter, Manager, PhysicalPosition, PhysicalSize, RunEvent, State, WebviewUrl,
    WebviewWindow, WindowEvent,
};
use tauri_plugin_dialog::{DialogExt, FilePath};

const MAIN_WINDOW_LABEL: &str = "main";
const OPEN_MARKDOWN_EVENT: &str = "open-markdown-files";
const FIND_IN_DOCUMENT_EVENT: &str = "find-in-document";
const OPEN_RECENT_FOLDER_EVENT: &str = "open-recent-folder";
const CLEAR_RECENT_FOLDERS_EVENT: &str = "clear-recent-folders";
const OPEN_FOLDER_IN_NEW_WINDOW_MENU_ID: &str = "file.open-folder-new-window";
const RECENT_FOLDER_MENU_ID_PREFIX: &str = "file.open-recent-folder.";
const CLEAR_RECENT_FOLDERS_MENU_ID: &str = "file.clear-recent-folders";
const NO_RECENT_FOLDERS_MENU_ID: &str = "file.no-recent-folders";
const FIND_IN_DOCUMENT_MENU_ID: &str = "edit.find-in-document";
const DEFAULT_THEME: &str = "light";
const WINDOW_STATE_FILE_NAME: &str = "window-state.json";
const MIN_RESTORED_WINDOW_WIDTH: u32 = 640;
const MIN_RESTORED_WINDOW_HEIGHT: u32 = 420;
const PERFORMANCE_PROBE_ENV: &str = "PREVIEWERMD_PERF_PROBE";

#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
struct StoredWindowState {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
struct WindowStateFile {
    document_window: Option<StoredWindowState>,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize)]
struct PerformanceProbeConfig {
    enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
struct WorkspaceFolder {
    name: String,
    path: String,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct DirectoryEntryPayload {
    name: String,
    path: String,
    is_file: bool,
    is_directory: bool,
}

#[derive(serde::Serialize)]
struct PerformanceMetricPayload<'a> {
    name: &'a str,
    elapsed_ms: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct MonitorBounds {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
}

#[derive(Default)]
struct PendingOpenFiles(Mutex<HashMap<String, Vec<String>>>);

#[derive(Default)]
struct WindowThemes(Mutex<HashMap<String, String>>);

#[derive(Default)]
struct WorkspaceWindowCounter(AtomicU64);

#[derive(Default)]
struct RecentWorkspaceFolders(Mutex<Vec<WorkspaceFolder>>);

fn is_supported_markdown_path(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "md" | "markdown"))
        .unwrap_or(false)
}

fn is_document_window_label(label: &str) -> bool {
    label == MAIN_WINDOW_LABEL || label.starts_with("workspace-")
}

fn collect_supported_open_paths(urls: &[url::Url]) -> Vec<String> {
    urls.iter()
        .filter_map(|url| url.to_file_path().ok())
        .filter(|path| is_supported_markdown_path(path))
        .map(|path| path.to_string_lossy().into_owned())
        .collect()
}

fn normalize_theme(theme: Option<&str>) -> Option<&str> {
    theme
        .map(str::trim)
        .filter(|value| !value.is_empty() && *value != DEFAULT_THEME)
}

fn validate_terminal_folder(path: &Path) -> Result<PathBuf, String> {
    if path.is_dir() {
        Ok(path.to_path_buf())
    } else {
        Err(format!(
            "Terminal folder does not exist or is not a directory: {}",
            path.to_string_lossy()
        ))
    }
}

fn env_flag_enabled(value: Option<&str>) -> bool {
    value
        .map(str::trim)
        .map(|value| {
            matches!(
                value.to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(false)
}

fn performance_probe_config_from_env(enabled_value: Option<&str>) -> PerformanceProbeConfig {
    PerformanceProbeConfig {
        enabled: env_flag_enabled(enabled_value),
    }
}

fn current_performance_probe_config() -> PerformanceProbeConfig {
    let enabled = std::env::var(PERFORMANCE_PROBE_ENV).ok();
    performance_probe_config_from_env(enabled.as_deref())
}

fn format_performance_metric_line(name: &str, elapsed_ms: f64) -> String {
    let payload = serde_json::to_string(&PerformanceMetricPayload { name, elapsed_ms })
        .unwrap_or_else(|_| "{}".to_string());

    format!("PREVIEWERMD_PERF {payload}")
}

#[cfg(target_os = "macos")]
fn escape_applescript_string(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

fn build_external_terminal_command(cwd: &Path) -> Command {
    #[cfg(target_os = "macos")]
    {
        let folder_path = escape_applescript_string(&cwd.to_string_lossy());
        let mut command = Command::new("osascript");
        command
            .arg("-e")
            .arg(format!(
                "tell application \"Terminal\" to do script \"cd \" & quoted form of \"{folder_path}\""
            ))
            .arg("-e")
            .arg("tell application \"Terminal\" to activate");
        command
    }

    #[cfg(target_os = "windows")]
    {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", "", "wt", "-d"]).arg(cwd);
        command
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let mut command = Command::new("x-terminal-emulator");
        command.arg("--working-directory").arg(cwd);
        command
    }
}

fn next_workspace_window_label(counter: &WorkspaceWindowCounter) -> String {
    let id = counter.0.fetch_add(1, Ordering::Relaxed) + 1;
    format!("workspace-{id}")
}

fn build_workspace_window_path(
    base_url: &WebviewUrl,
    folder_path: &str,
    theme: Option<&str>,
) -> PathBuf {
    let base_path = match base_url {
        WebviewUrl::App(path) if !path.as_os_str().is_empty() => {
            path.to_string_lossy().into_owned()
        }
        _ => "index.html".to_string(),
    };
    let base_path = base_path.split('?').next().unwrap_or("index.html");

    let mut search = url::form_urlencoded::Serializer::new(String::new());
    search.append_pair("folder", folder_path);

    if let Some(theme) = normalize_theme(theme) {
        search.append_pair("theme", theme);
    }

    PathBuf::from(format!("{base_path}?{}", search.finish()))
}

fn store_window_theme(
    themes: &WindowThemes,
    window_label: &str,
    theme: &str,
) -> Result<(), String> {
    let mut entries = themes.0.lock().map_err(|err| err.to_string())?;
    if theme.trim().is_empty() || theme == DEFAULT_THEME {
        entries.remove(window_label);
    } else {
        entries.insert(window_label.to_string(), theme.to_string());
    }
    Ok(())
}

fn get_window_theme(themes: &WindowThemes, window_label: &str) -> Option<String> {
    themes
        .0
        .lock()
        .ok()
        .and_then(|entries| entries.get(window_label).cloned())
}

fn queue_pending_open_paths(
    pending_state: &PendingOpenFiles,
    window_label: &str,
    paths: Vec<String>,
) -> Result<(), String> {
    let mut pending = pending_state.0.lock().map_err(|err| err.to_string())?;
    pending
        .entry(window_label.to_string())
        .or_default()
        .extend(paths);
    Ok(())
}

fn pending_open_window_label(target_window_label: Option<&str>) -> &str {
    target_window_label.unwrap_or(MAIN_WINDOW_LABEL)
}

fn recent_folder_menu_id(index: usize) -> String {
    format!("{RECENT_FOLDER_MENU_ID_PREFIX}{index}")
}

fn recent_folder_index_from_menu_id(menu_id: &str) -> Option<usize> {
    menu_id
        .strip_prefix(RECENT_FOLDER_MENU_ID_PREFIX)
        .and_then(|index| index.parse::<usize>().ok())
}

fn workspace_folder_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty())
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| path.trim_end_matches(['/', '\\']).to_string())
}

fn normalize_workspace_folder(folder: WorkspaceFolder) -> Option<WorkspaceFolder> {
    let path = folder.path.trim();
    if path.is_empty() {
        return None;
    }

    let name = if folder.name.trim().is_empty() {
        workspace_folder_name(path)
    } else {
        folder.name
    };

    Some(WorkspaceFolder {
        name,
        path: path.to_string(),
    })
}

fn get_recent_workspace_folder(
    state: &RecentWorkspaceFolders,
    index: usize,
) -> Option<WorkspaceFolder> {
    state
        .0
        .lock()
        .ok()
        .and_then(|folders| folders.get(index).cloned())
}

fn window_state_is_visible(state: &StoredWindowState, monitors: &[MonitorBounds]) -> bool {
    if state.width < MIN_RESTORED_WINDOW_WIDTH || state.height < MIN_RESTORED_WINDOW_HEIGHT {
        return false;
    }

    let window_left = state.x as i64;
    let window_top = state.y as i64;
    let window_right = window_left + state.width as i64;
    let window_bottom = window_top + state.height as i64;

    monitors.iter().any(|monitor| {
        let monitor_left = monitor.x as i64;
        let monitor_top = monitor.y as i64;
        let monitor_right = monitor_left + monitor.width as i64;
        let monitor_bottom = monitor_top + monitor.height as i64;

        window_left < monitor_right
            && window_right > monitor_left
            && window_top < monitor_bottom
            && window_bottom > monitor_top
    })
}

fn read_window_state_file(path: &Path) -> WindowStateFile {
    fs::read_to_string(path)
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

fn write_window_state_file(path: &Path, state_file: &WindowStateFile) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }

    let contents = serde_json::to_string_pretty(state_file).map_err(|err| err.to_string())?;
    fs::write(path, contents).map_err(|err| err.to_string())
}

fn write_document_window_state(path: &Path, state: StoredWindowState) -> Result<(), String> {
    let mut state_file = read_window_state_file(path);
    state_file.document_window = Some(state);
    write_window_state_file(path, &state_file)
}

fn window_state_path<R: tauri::Runtime>(app_handle: &AppHandle<R>) -> Option<PathBuf> {
    app_handle
        .path()
        .app_config_dir()
        .ok()
        .map(|dir| dir.join(WINDOW_STATE_FILE_NAME))
}

fn collect_monitor_bounds<R: tauri::Runtime>(window: &WebviewWindow<R>) -> Vec<MonitorBounds> {
    window
        .available_monitors()
        .unwrap_or_default()
        .into_iter()
        .map(|monitor| {
            let position = monitor.position();
            let size = monitor.size();
            MonitorBounds {
                x: position.x,
                y: position.y,
                width: size.width,
                height: size.height,
            }
        })
        .collect()
}

fn capture_document_window_state<R: tauri::Runtime>(
    window: &WebviewWindow<R>,
) -> Option<StoredWindowState> {
    let position = window.outer_position().ok()?;
    let size = window.outer_size().ok()?;

    Some(StoredWindowState {
        x: position.x,
        y: position.y,
        width: size.width,
        height: size.height,
    })
}

fn restore_document_window_state<R: tauri::Runtime>(
    window: &WebviewWindow<R>,
    state_path: &Path,
) {
    let Some(state) = read_window_state_file(state_path).document_window else {
        return;
    };

    let monitors = collect_monitor_bounds(window);
    if !window_state_is_visible(&state, &monitors) {
        return;
    }

    let _ = window.set_size(PhysicalSize::new(state.width, state.height));
    let _ = window.set_position(PhysicalPosition::new(state.x, state.y));
}

fn register_document_window_state<R: tauri::Runtime>(
    window: &WebviewWindow<R>,
    state_path: PathBuf,
) {
    restore_document_window_state(window, &state_path);

    let tracked_window = window.clone();
    window.on_window_event(move |event| {
        if !matches!(event, WindowEvent::Moved(_) | WindowEvent::Resized(_)) {
            return;
        }

        let Some(state) = capture_document_window_state(&tracked_window) else {
            return;
        };

        if let Err(error) = write_document_window_state(&state_path, state) {
            eprintln!("Failed to persist document window state: {error}");
        }
    });
}

fn register_existing_document_window_states<R: tauri::Runtime>(app_handle: &AppHandle<R>) {
    let Some(state_path) = window_state_path(app_handle) else {
        return;
    };

    for (label, window) in app_handle.webview_windows() {
        if is_document_window_label(&label) {
            register_document_window_state(&window, state_path.clone());
        }
    }
}

fn get_target_document_window<R: tauri::Runtime>(
    app_handle: &AppHandle<R>,
) -> Option<WebviewWindow<R>> {
    app_handle
        .webview_windows()
        .into_iter()
        .find_map(|(label, window)| {
            if is_document_window_label(&label) && window.is_focused().unwrap_or(false) {
                Some(window)
            } else {
                None
            }
        })
        .or_else(|| app_handle.get_webview_window(MAIN_WINDOW_LABEL))
}

fn create_workspace_window<R: tauri::Runtime>(
    app_handle: &AppHandle<R>,
    counter: &WorkspaceWindowCounter,
    themes: &WindowThemes,
    folder_path: &str,
    theme: Option<&str>,
) -> Result<String, String> {
    let folder = Path::new(folder_path);
    if !folder.is_dir() {
        return Err(format!(
            "Folder does not exist or is not a directory: {folder_path}"
        ));
    }

    let mut window_config = app_handle
        .config()
        .app
        .windows
        .first()
        .cloned()
        .ok_or_else(|| "Missing main window configuration".to_string())?;

    let label = next_workspace_window_label(counter);
    window_config.label = label.clone();
    window_config.url = WebviewUrl::App(build_workspace_window_path(
        &window_config.url,
        folder_path,
        theme,
    ));

    let window = tauri::WebviewWindowBuilder::from_config(app_handle, &window_config)
        .map_err(|err| err.to_string())?
        .build()
        .map_err(|err| err.to_string())?;

    if let Some(state_path) = window_state_path(app_handle) {
        register_document_window_state(&window, state_path);
    }

    if let Some(theme) = normalize_theme(theme) {
        store_window_theme(themes, &label, theme)?;
    }

    let _ = window.show();
    let _ = window.set_focus();

    Ok(label)
}

fn open_folder_in_new_window_picker<R: tauri::Runtime>(app_handle: &AppHandle<R>) {
    let target_window = get_target_document_window(app_handle);
    let inherited_theme = target_window
        .as_ref()
        .and_then(|window| get_window_theme(&app_handle.state::<WindowThemes>(), window.label()));

    let mut dialog = app_handle
        .dialog()
        .file()
        .set_title("Open Markdown Folder in New Window");

    if let Some(window) = target_window {
        dialog = dialog.set_parent(&window);
    }

    let app_handle = app_handle.clone();
    dialog.pick_folder(move |selected| {
        let Some(path) = selected.and_then(file_path_to_string) else {
            return;
        };

        if let Err(error) = create_workspace_window(
            &app_handle,
            &app_handle.state::<WorkspaceWindowCounter>(),
            &app_handle.state::<WindowThemes>(),
            &path,
            inherited_theme.as_deref(),
        ) {
            eprintln!("Failed to open folder in a new window: {error}");
        }
    });
}

fn file_path_to_string(path: FilePath) -> Option<String> {
    path.into_path()
        .ok()
        .map(|path| path.to_string_lossy().into_owned())
}

fn build_recent_folders_submenu<R: tauri::Runtime>(
    app_handle: &AppHandle<R>,
) -> tauri::Result<Submenu<R>> {
    let folders = app_handle
        .try_state::<RecentWorkspaceFolders>()
        .and_then(|state| state.0.lock().ok().map(|folders| folders.clone()))
        .unwrap_or_default();

    if folders.is_empty() {
        let no_recent_folders = MenuItem::with_id(
            app_handle,
            NO_RECENT_FOLDERS_MENU_ID,
            "No Recent Folders",
            false,
            None::<&str>,
        )?;

        return Submenu::with_items(
            app_handle,
            "Recent Folders",
            true,
            &[&no_recent_folders],
        );
    }

    let recent_folder_items = folders
        .iter()
        .enumerate()
        .map(|(index, folder)| {
            MenuItem::with_id(
                app_handle,
                recent_folder_menu_id(index),
                &folder.name,
                true,
                None::<&str>,
            )
        })
        .collect::<tauri::Result<Vec<_>>>()?;
    let recent_folder_item_refs = recent_folder_items
        .iter()
        .map(|item| item as &dyn IsMenuItem<R>)
        .collect::<Vec<_>>();
    let separator = PredefinedMenuItem::separator(app_handle)?;
    let clear_recent_folders = MenuItem::with_id(
        app_handle,
        CLEAR_RECENT_FOLDERS_MENU_ID,
        "Clear Recent Folders",
        true,
        None::<&str>,
    )?;
    let mut recent_folder_items_with_clear = recent_folder_item_refs;
    recent_folder_items_with_clear.push(&separator);
    recent_folder_items_with_clear.push(&clear_recent_folders);

    Submenu::with_items(
        app_handle,
        "Recent Folders",
        true,
        &recent_folder_items_with_clear,
    )
}

fn build_app_menu<R: tauri::Runtime>(app_handle: &AppHandle<R>) -> tauri::Result<Menu<R>> {
    let package_info = app_handle.package_info();
    let config = app_handle.config();
    let about_metadata = AboutMetadata {
        name: Some(package_info.name.clone()),
        version: Some(package_info.version.to_string()),
        copyright: config.bundle.copyright.clone(),
        authors: config
            .bundle
            .publisher
            .clone()
            .map(|publisher| vec![publisher]),
        ..Default::default()
    };

    let open_folder_in_new_window = MenuItem::with_id(
        app_handle,
        OPEN_FOLDER_IN_NEW_WINDOW_MENU_ID,
        "Open Folder in New Window",
        true,
        Some("CmdOrCtrl+Shift+O"),
    )?;
    let recent_folders = build_recent_folders_submenu(app_handle)?;
    let find_in_document = MenuItem::with_id(
        app_handle,
        FIND_IN_DOCUMENT_MENU_ID,
        "Find",
        true,
        Some("CmdOrCtrl+F"),
    )?;

    let window_menu = Submenu::with_items(
        app_handle,
        "Window",
        true,
        &[
            &PredefinedMenuItem::minimize(app_handle, None)?,
            &PredefinedMenuItem::maximize(app_handle, None)?,
            #[cfg(target_os = "macos")]
            &PredefinedMenuItem::separator(app_handle)?,
            &PredefinedMenuItem::close_window(app_handle, None)?,
        ],
    )?;

    let help_menu = Submenu::with_items(
        app_handle,
        "Help",
        true,
        &[
            #[cfg(not(target_os = "macos"))]
            &PredefinedMenuItem::about(app_handle, None, Some(about_metadata.clone()))?,
        ],
    )?;

    Menu::with_items(
        app_handle,
        &[
            #[cfg(target_os = "macos")]
            &Submenu::with_items(
                app_handle,
                package_info.name.clone(),
                true,
                &[
                    &PredefinedMenuItem::about(app_handle, None, Some(about_metadata))?,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &PredefinedMenuItem::services(app_handle, None)?,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &PredefinedMenuItem::hide(app_handle, None)?,
                    &PredefinedMenuItem::hide_others(app_handle, None)?,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &PredefinedMenuItem::quit(app_handle, None)?,
                ],
            )?,
            &Submenu::with_items(
                app_handle,
                "File",
                true,
                &[
                    &open_folder_in_new_window,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &recent_folders,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &PredefinedMenuItem::close_window(app_handle, None)?,
                    #[cfg(not(target_os = "macos"))]
                    &PredefinedMenuItem::quit(app_handle, None)?,
                ],
            )?,
            &Submenu::with_items(
                app_handle,
                "Edit",
                true,
                &[
                    &PredefinedMenuItem::undo(app_handle, None)?,
                    &PredefinedMenuItem::redo(app_handle, None)?,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &PredefinedMenuItem::cut(app_handle, None)?,
                    &PredefinedMenuItem::copy(app_handle, None)?,
                    &PredefinedMenuItem::paste(app_handle, None)?,
                    &PredefinedMenuItem::separator(app_handle)?,
                    &find_in_document,
                    &PredefinedMenuItem::select_all(app_handle, None)?,
                ],
            )?,
            #[cfg(target_os = "macos")]
            &Submenu::with_items(
                app_handle,
                "View",
                true,
                &[&PredefinedMenuItem::fullscreen(app_handle, None)?],
            )?,
            &window_menu,
            &help_menu,
        ],
    )
}

#[tauri::command]
fn read_markdown_file(path: String) -> Result<String, String> {
    std::fs::read_to_string(path).map_err(|err| err.to_string())
}

#[tauri::command]
fn read_directory(path: String) -> Result<Vec<DirectoryEntryPayload>, String> {
    let mut entries = Vec::new();

    for entry in std::fs::read_dir(path).map_err(|err| err.to_string())? {
        let entry = entry.map_err(|err| err.to_string())?;
        let file_type = entry.file_type().map_err(|err| err.to_string())?;
        entries.push(DirectoryEntryPayload {
            name: entry.file_name().to_string_lossy().into_owned(),
            path: entry.path().to_string_lossy().into_owned(),
            is_file: file_type.is_file(),
            is_directory: file_type.is_dir(),
        });
    }

    Ok(entries)
}

#[tauri::command]
fn write_markdown_file(path: String, contents: String) -> Result<(), String> {
    std::fs::write(path, contents).map_err(|err| err.to_string())
}

#[tauri::command]
fn take_pending_open_files(
    window: WebviewWindow,
    state: State<'_, PendingOpenFiles>,
) -> Result<Vec<String>, String> {
    let mut pending = state.0.lock().map_err(|err| err.to_string())?;
    Ok(pending.remove(window.label()).unwrap_or_default())
}

#[tauri::command]
fn print_current_window(window: tauri::WebviewWindow) -> Result<(), String> {
    window.print().map_err(|err| err.to_string())
}

#[tauri::command]
fn open_folder_in_new_window(
    app: AppHandle,
    state: State<'_, WorkspaceWindowCounter>,
    themes: State<'_, WindowThemes>,
    folder_path: String,
    theme: Option<String>,
) -> Result<String, String> {
    create_workspace_window(&app, &state, &themes, &folder_path, theme.as_deref())
}

#[tauri::command]
fn set_window_theme(
    window: WebviewWindow,
    state: State<'_, WindowThemes>,
    theme: String,
) -> Result<(), String> {
    store_window_theme(&state, window.label(), &theme)
}

#[tauri::command]
fn set_recent_workspace_folders(
    app: AppHandle,
    state: State<'_, RecentWorkspaceFolders>,
    folders: Vec<WorkspaceFolder>,
) -> Result<(), String> {
    let mut normalized_folders = Vec::new();

    for folder in folders {
        let Some(folder) = normalize_workspace_folder(folder) else {
            continue;
        };

        if normalized_folders
            .iter()
            .any(|existing: &WorkspaceFolder| existing.path == folder.path)
        {
            continue;
        }

        normalized_folders.push(folder);
    }

    {
        let mut recent_folders = state.0.lock().map_err(|err| err.to_string())?;
        *recent_folders = normalized_folders;
    }

    app.set_menu(build_app_menu(&app).map_err(|err| err.to_string())?)
        .map(|_| ())
        .map_err(|err| err.to_string())
}

#[tauri::command]
fn get_performance_probe_config() -> PerformanceProbeConfig {
    current_performance_probe_config()
}

#[tauri::command]
fn record_performance_metric(name: String, elapsed_ms: f64) -> Result<(), String> {
    if !current_performance_probe_config().enabled {
        return Ok(());
    }

    println!("{}", format_performance_metric_line(&name, elapsed_ms));
    Ok(())
}

#[tauri::command]
fn open_folder_in_terminal(folder_path: String) -> Result<(), String> {
    let cwd = validate_terminal_folder(Path::new(&folder_path))?;
    build_external_terminal_command(&cwd)
        .spawn()
        .map(|_| ())
        .map_err(|err| err.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        .manage(PendingOpenFiles::default())
        .manage(WindowThemes::default())
        .manage(WorkspaceWindowCounter::default())
        .manage(RecentWorkspaceFolders::default())
        .menu(build_app_menu)
        .on_menu_event(|app_handle, event| {
            if event.id().as_ref() == OPEN_FOLDER_IN_NEW_WINDOW_MENU_ID {
                open_folder_in_new_window_picker(app_handle);
            } else if event.id().as_ref() == FIND_IN_DOCUMENT_MENU_ID {
                if let Some(window) = get_target_document_window(app_handle) {
                    let _ = window.emit(FIND_IN_DOCUMENT_EVENT, ());
                }
            } else if let Some(index) = recent_folder_index_from_menu_id(event.id().as_ref()) {
                let recent_folder =
                    get_recent_workspace_folder(&app_handle.state::<RecentWorkspaceFolders>(), index);

                if let (Some(folder), Some(window)) =
                    (recent_folder, get_target_document_window(app_handle))
                {
                    let _ = window.emit(OPEN_RECENT_FOLDER_EVENT, folder.path);
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            } else if event.id().as_ref() == CLEAR_RECENT_FOLDERS_MENU_ID {
                if let Some(window) = get_target_document_window(app_handle) {
                    let _ = window.emit(CLEAR_RECENT_FOLDERS_EVENT, ());
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
        })
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            print_current_window,
            read_directory,
            read_markdown_file,
            write_markdown_file,
            take_pending_open_files,
            open_folder_in_new_window,
            open_folder_in_terminal,
            set_window_theme,
            set_recent_workspace_folders,
            get_performance_probe_config,
            record_performance_metric
        ])
        .setup(|app| {
            register_existing_document_window_states(app.handle());
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application");

    app.run(|app_handle, event| {
        if let RunEvent::Opened { urls } = event {
            let paths = collect_supported_open_paths(&urls);
            if paths.is_empty() {
                return;
            }

            let target_window = get_target_document_window(app_handle);
            let target_label =
                pending_open_window_label(target_window.as_ref().map(|window| window.label()))
                    .to_string();

            if let Err(error) = queue_pending_open_paths(
                &app_handle.state::<PendingOpenFiles>(),
                &target_label,
                paths.clone(),
            ) {
                eprintln!("Failed to queue external markdown open paths: {error}");
                return;
            }

            if let Some(target_window) = target_window {
                let _ = target_window.emit(OPEN_MARKDOWN_EVENT, paths);
                let _ = target_window.show();
                let _ = target_window.set_focus();
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_workspace_window_path_encodes_folder_and_theme() {
        let path = build_workspace_window_path(
            &WebviewUrl::App("index.html".into()),
            "/Users/ellic/Documents/Project Notes",
            Some("claude-dark"),
        );

        assert_eq!(
            path,
            PathBuf::from(
                "index.html?folder=%2FUsers%2Fellic%2FDocuments%2FProject+Notes&theme=claude-dark"
            )
        );
    }

    #[test]
    fn build_workspace_window_path_preserves_base_app_route() {
        let path = build_workspace_window_path(
            &WebviewUrl::App("editor/index.html?printMode=1".into()),
            "/tmp/docs",
            Some(DEFAULT_THEME),
        );

        assert_eq!(
            path,
            PathBuf::from("editor/index.html?folder=%2Ftmp%2Fdocs")
        );
    }

    #[test]
    fn document_window_labels_exclude_print_windows() {
        assert!(is_document_window_label("main"));
        assert!(is_document_window_label("workspace-3"));
        assert!(!is_document_window_label("print-job-1"));
    }

    #[test]
    fn pending_open_paths_fall_back_to_main_window_when_no_target_exists() {
        assert_eq!(pending_open_window_label(None), MAIN_WINDOW_LABEL);
    }

    #[test]
    fn recent_folder_menu_ids_round_trip_indices() {
        let menu_id = recent_folder_menu_id(3);

        assert_eq!(menu_id, "file.open-recent-folder.3");
        assert_eq!(recent_folder_index_from_menu_id(&menu_id), Some(3));
        assert_eq!(recent_folder_index_from_menu_id("file.open-recent-folder.x"), None);
        assert_eq!(recent_folder_index_from_menu_id(CLEAR_RECENT_FOLDERS_MENU_ID), None);
        assert_eq!(recent_folder_index_from_menu_id("file.open-folder-new-window"), None);
    }

    #[test]
    fn workspace_folder_name_uses_last_path_component() {
        assert_eq!(workspace_folder_name("/Users/ellic/Project Notes"), "Project Notes");
        assert_eq!(workspace_folder_name("/tmp/docs/"), "docs");
    }

    #[test]
    fn terminal_folder_validation_requires_existing_directory() {
        let temp_dir = std::env::temp_dir();
        assert_eq!(validate_terminal_folder(&temp_dir), Ok(temp_dir));

        let missing_dir = std::env::temp_dir().join("previewermd-missing-terminal-cwd");
        assert_eq!(
            validate_terminal_folder(&missing_dir),
            Err(format!(
                "Terminal folder does not exist or is not a directory: {}",
                missing_dir.to_string_lossy()
            ))
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn external_terminal_command_changes_to_the_folder_in_terminal_app() {
        let command = build_external_terminal_command(Path::new("/Users/ellic/Project Notes"));
        let args = command
            .get_args()
            .map(|arg| arg.to_string_lossy().into_owned())
            .collect::<Vec<_>>();

        assert_eq!(command.get_program().to_string_lossy(), "osascript");
        assert_eq!(
            args,
            [
                "-e",
                "tell application \"Terminal\" to do script \"cd \" & quoted form of \"/Users/ellic/Project Notes\"",
                "-e",
                "tell application \"Terminal\" to activate",
            ]
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn applescript_string_escaping_handles_quotes_and_backslashes() {
        assert_eq!(
            escape_applescript_string("/tmp/A \"quoted\" folder\\name"),
            "/tmp/A \\\"quoted\\\" folder\\\\name"
        );
    }

    #[test]
    fn performance_probe_config_requires_explicit_env_flag() {
        assert_eq!(
            performance_probe_config_from_env(None),
            PerformanceProbeConfig {
                enabled: false,
            }
        );
        assert_eq!(
            performance_probe_config_from_env(Some("1")),
            PerformanceProbeConfig {
                enabled: true,
            }
        );
    }

    #[test]
    fn performance_metric_line_is_structured_json() {
        assert_eq!(
            format_performance_metric_line("app.first_render", 42.5),
            "PREVIEWERMD_PERF {\"name\":\"app.first_render\",\"elapsed_ms\":42.5}"
        );
    }

    #[test]
    fn window_state_is_valid_when_it_intersects_a_monitor() {
        let state = StoredWindowState {
            x: 120,
            y: 80,
            width: 1280,
            height: 860,
        };
        let monitors = [MonitorBounds {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080,
        }];

        assert!(window_state_is_visible(&state, &monitors));
    }

    #[test]
    fn window_state_is_rejected_when_it_is_offscreen() {
        let state = StoredWindowState {
            x: 3200,
            y: 200,
            width: 1280,
            height: 860,
        };
        let monitors = [MonitorBounds {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080,
        }];

        assert!(!window_state_is_visible(&state, &monitors));
    }

    #[test]
    fn window_state_round_trips_through_json() {
        let state = StoredWindowState {
            x: 40,
            y: 60,
            width: 1440,
            height: 900,
        };
        let serialized = serde_json::to_string(&WindowStateFile {
            document_window: Some(state),
        })
        .expect("window state should serialize");

        let parsed: WindowStateFile =
            serde_json::from_str(&serialized).expect("window state should deserialize");

        assert_eq!(parsed.document_window, Some(state));
    }
}
