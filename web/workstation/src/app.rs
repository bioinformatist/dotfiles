use js_sys::{Array, Uint8Array};
use leptos::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{Blob, BlobPropertyBag, HtmlAnchorElement, Url};

use crate::generator::{
    derive_state, generate, zip_project, NetworkMode, ProductSpec, UPSTREAM_REV,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LoginChoice {
    Ssh,
    Password,
}

#[component]
pub fn App() -> impl IntoView {
    let host_name = RwSignal::new("workstation".to_owned());
    let username = RwSignal::new("user".to_owned());
    let login_choice = RwSignal::new(LoginChoice::Ssh);
    let ssh_public_key = RwSignal::new(String::new());
    let initial_password = RwSignal::new(String::new());
    let password_salt = RwSignal::new(random_salt());
    let git_name = RwSignal::new(String::new());
    let git_email = RwSignal::new(String::new());
    let disk_path = RwSignal::new(String::new());
    let nvidia = RwSignal::new(false);
    let network_mode = RwSignal::new(NetworkMode::China);
    let flash = RwSignal::new(String::new());

    let spec = move || ProductSpec {
        host_name: host_name.get(),
        username: username.get(),
        ssh_public_key: if login_choice.get() == LoginChoice::Ssh {
            ssh_public_key.get()
        } else {
            String::new()
        },
        initial_password: if login_choice.get() == LoginChoice::Password {
            initial_password.get()
        } else {
            String::new()
        },
        password_salt: password_salt.get(),
        git_name: git_name.get(),
        git_email: git_email.get(),
        disk_path: disk_path.get(),
        nvidia: nvidia.get(),
        network_mode: network_mode.get(),
    };

    let state = Memo::new(move |_| derive_state(&spec()));
    let file_preview = Memo::new(move |_| {
        generate(&spec())
            .map(|project| {
                project
                    .files
                    .into_iter()
                    .map(|file| format!("{}\n{}", file.path, "-".repeat(file.path.len())))
                    .collect::<Vec<_>>()
                    .join("\n\n")
            })
            .unwrap_or_else(|err| err)
    });
    let install_command = Memo::new(move |_| {
        let spec = spec();
        if derive_state(&spec).can_install {
            format!(
                "nix run github:nix-community/nixos-anywhere -- --flake .#{} root@<target-ip>",
                spec.host_name.trim()
            )
        } else {
            "填写稳定的 /dev/disk/by-id/... 目标磁盘后才会生成安装命令。".to_owned()
        }
    });

    let download_zip = move |_| {
        flash.set(String::new());
        let spec = spec();
        match generate(&spec).and_then(|project| zip_project(&project)) {
            Ok(bytes) => {
                match download_bytes(&format!("nixos-{}.zip", spec.host_name.trim()), &bytes) {
                    Ok(()) => flash.set("配置包已生成。".to_owned()),
                    Err(err) => flash.set(err),
                }
            }
            Err(err) => flash.set(err),
        }
    };

    let copy_command = move |_| {
        let command = install_command.get();
        match copy_to_clipboard(&command) {
            Ok(()) => flash.set("安装命令已复制。".to_owned()),
            Err(err) => flash.set(err),
        }
    };

    view! {
        <main class="app-shell">
            <section class="workspace">
                <header class="page-header">
                    <div>
                        <p class="eyebrow">"NixOS workstation"</p>
                        <h1>"配置生成器"</h1>
                    </div>
                    <div class="revision">"upstream " <code>{UPSTREAM_REV}</code></div>
                </header>

                <div class="layout">
                    <form class="panel form-panel">
                        <fieldset>
                            <legend>"基础信息"</legend>
                            <label>
                                <span>"hostName"</span>
                                <input
                                    prop:value=move || host_name.get()
                                    on:input=move |ev| host_name.set(event_target_value(&ev))
                                />
                            </label>
                            <label>
                                <span>"username"</span>
                                <input
                                    prop:value=move || username.get()
                                    on:input=move |ev| username.set(event_target_value(&ev))
                                />
                            </label>
                        </fieldset>

                        <fieldset>
                            <legend>"登录方式"</legend>
                            <div class="segmented">
                                <button
                                    type="button"
                                    class:active=move || login_choice.get() == LoginChoice::Ssh
                                    on:click=move |_| login_choice.set(LoginChoice::Ssh)
                                >
                                    "SSH public key"
                                </button>
                                <button
                                    type="button"
                                    class:active=move || login_choice.get() == LoginChoice::Password
                                    on:click=move |_| login_choice.set(LoginChoice::Password)
                                >
                                    "初始密码"
                                </button>
                            </div>
                            <Show
                                when=move || login_choice.get() == LoginChoice::Ssh
                                fallback=move || view! {
                                    <label>
                                        <span>"初始密码"</span>
                                        <input
                                            type="password"
                                            autocomplete="new-password"
                                            prop:value=move || initial_password.get()
                                            on:input=move |ev| initial_password.set(event_target_value(&ev))
                                        />
                                    </label>
                                }
                            >
                                <label>
                                    <span>"SSH public key"</span>
                                    <textarea
                                        rows="4"
                                        prop:value=move || ssh_public_key.get()
                                        on:input=move |ev| ssh_public_key.set(event_target_value(&ev))
                                    ></textarea>
                                </label>
                            </Show>
                            <p class="hint">"这里配置的是安装完成后的新 NixOS 用户；运行 nixos-anywhere 前仍需能 SSH 登录目标机的 root installer 环境。"</p>
                        </fieldset>

                        <fieldset>
                            <legend>"安装目标"</legend>
                            <label>
                                <span class="with-help">
                                    "目标磁盘"
                                    <span class="help" title="在目标机运行 ls -l /dev/disk/by-id/ 查看稳定路径。disko 会清空这个系统盘。">"?"</span>
                                </span>
                                <input
                                    placeholder="/dev/disk/by-id/..."
                                    prop:value=move || disk_path.get()
                                    on:input=move |ev| disk_path.set(event_target_value(&ev))
                                />
                            </label>
                            <label class="check-row">
                                <input
                                    type="checkbox"
                                    prop:checked=move || nvidia.get()
                                    on:change=move |ev| nvidia.set(event_target_checked(&ev))
                                />
                                <span>"启用 NVIDIA 桌面补丁"</span>
                            </label>
                        </fieldset>

                        <fieldset>
                            <legend>"网络模式"</legend>
                            <div class="segmented">
                                <button
                                    type="button"
                                    class:active=move || network_mode.get() == NetworkMode::China
                                    on:click=move |_| network_mode.set(NetworkMode::China)
                                >
                                    "China"
                                </button>
                                <button
                                    type="button"
                                    class:active=move || network_mode.get() == NetworkMode::Global
                                    on:click=move |_| network_mode.set(NetworkMode::Global)
                                >
                                    "Global"
                                </button>
                            </div>
                            <Show when=move || network_mode.get() == NetworkMode::China>
                                <p class="notice">"China 模式会安装 Clash Verge，并让 nix-daemon 默认走 http://127.0.0.1:7897。安装完成后请先配置 Clash 订阅。"</p>
                            </Show>
                        </fieldset>

                        <fieldset>
                            <legend>"Git identity"</legend>
                            <label>
                                <span class="with-help">
                                    "用户名"
                                    <span class="help" title="可选。填写后安装完成即可直接使用 Git identity。">"?"</span>
                                </span>
                                <input
                                    prop:value=move || git_name.get()
                                    on:input=move |ev| git_name.set(event_target_value(&ev))
                                />
                            </label>
                            <label>
                                <span>"邮箱"</span>
                                <input
                                    type="email"
                                    prop:value=move || git_email.get()
                                    on:input=move |ev| git_email.set(event_target_value(&ev))
                                />
                            </label>
                        </fieldset>
                    </form>

                    <aside class="panel status-panel">
                        <section>
                            <h2>"状态"</h2>
                            <For
                                each=move || state.get().errors
                                key=|msg| msg.clone()
                                children=|msg| view! { <p class="message error">{msg}</p> }
                            />
                            <For
                                each=move || state.get().warnings
                                key=|msg| msg.clone()
                                children=|msg| view! { <p class="message warning">{msg}</p> }
                            />
                            <For
                                each=move || state.get().notices
                                key=|msg| msg.clone()
                                children=|msg| view! { <p class="message notice-soft">{msg}</p> }
                            />
                            <Show when=move || state.get().errors.is_empty() && state.get().warnings.is_empty() && state.get().notices.is_empty()>
                                <p class="message ok">"配置可以生成。"</p>
                            </Show>
                        </section>

                        <section>
                            <h2>"安装命令"</h2>
                            <pre class="command">{move || install_command.get()}</pre>
                            <div class="actions">
                                <button
                                    type="button"
                                    disabled=move || !state.get().can_download
                                    on:click=download_zip
                                >
                                    "下载 zip"
                                </button>
                                <button
                                    type="button"
                                    disabled=move || !state.get().can_install
                                    on:click=copy_command
                                >
                                    "复制命令"
                                </button>
                            </div>
                            <Show when=move || !flash.get().is_empty()>
                                <p class="flash">{move || flash.get()}</p>
                            </Show>
                        </section>

                        <section>
                            <h2>"文件预览"</h2>
                            <pre class="preview">{move || file_preview.get()}</pre>
                        </section>
                    </aside>
                </div>
            </section>
        </main>
    }
}

fn download_bytes(filename: &str, bytes: &[u8]) -> Result<(), String> {
    let window = web_sys::window().ok_or_else(|| "无法访问 window。".to_owned())?;
    let document = window
        .document()
        .ok_or_else(|| "无法访问 document。".to_owned())?;
    let array = Uint8Array::from(bytes);
    let parts = Array::new();
    parts.push(array.as_ref());

    let options = BlobPropertyBag::new();
    options.set_type("application/zip");
    let blob = Blob::new_with_u8_array_sequence_and_options(&parts, &options)
        .map_err(|_| "无法创建 zip Blob。".to_owned())?;
    let url =
        Url::create_object_url_with_blob(&blob).map_err(|_| "无法创建下载 URL。".to_owned())?;
    let anchor = document
        .create_element("a")
        .map_err(|_| "无法创建下载链接。".to_owned())?
        .dyn_into::<HtmlAnchorElement>()
        .map_err(|_| "无法创建下载链接。".to_owned())?;

    anchor.set_href(&url);
    anchor.set_download(filename);
    let body = document
        .body()
        .ok_or_else(|| "无法访问 document body。".to_owned())?;
    body.append_child(&anchor)
        .map_err(|_| "无法挂载下载链接。".to_owned())?;
    anchor.click();
    body.remove_child(&anchor)
        .map_err(|_| "无法移除下载链接。".to_owned())?;
    Url::revoke_object_url(&url).ok();
    Ok(())
}

fn copy_to_clipboard(text: &str) -> Result<(), String> {
    let window = web_sys::window().ok_or_else(|| "无法访问 window。".to_owned())?;
    let clipboard = window.navigator().clipboard();
    let _ = clipboard.write_text(text);
    Ok(())
}

fn random_salt() -> String {
    const ALPHABET: &[u8] = b"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    (0..16)
        .map(|_| {
            let index = (js_sys::Math::random() * ALPHABET.len() as f64).floor() as usize;
            ALPHABET[index.min(ALPHABET.len() - 1)] as char
        })
        .collect()
}
