use std::collections::BTreeMap;

use js_sys::{Array, Uint8Array};
use leptos::prelude::*;
use thaw::{Button, ButtonAppearance, ConfigProvider, Text, TextTag};
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::{spawn_local, JsFuture};
use web_sys::{Blob, BlobPropertyBag, HtmlAnchorElement, HtmlDocument, HtmlTextAreaElement, Url};

use crate::generator::{
    derive_state, generate, zip_project, GeneratedFile, IssueCode, NetworkMode, ProductSpec,
    UPSTREAM_REV,
};
use crate::i18n::*;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LoginChoice {
    Ssh,
    Password,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum FlashMessage {
    DownloadReady,
    CommandCopied,
    DownloadFailed,
    ClipboardFailed,
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <I18nContextProvider>
            <ConfigProvider>
                <GeneratorApp />
            </ConfigProvider>
        </I18nContextProvider>
    }
}

#[component]
fn GeneratorApp() -> impl IntoView {
    let i18n = use_i18n();
    Effect::new(move |_| i18n.set_locale(Locale::en));

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
    let flash = RwSignal::new(None::<FlashMessage>);

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
    let has_host_error =
        Memo::new(move |_| state.get().errors.contains(&IssueCode::HostNameInvalid));
    let has_username_error =
        Memo::new(move |_| state.get().errors.contains(&IssueCode::UsernameInvalid));
    let has_login_missing =
        Memo::new(move |_| state.get().errors.contains(&IssueCode::LoginMethodMissing));
    let has_ssh_error =
        Memo::new(move |_| state.get().errors.contains(&IssueCode::SshPublicKeyInvalid));
    let has_password_error = Memo::new(move |_| {
        state
            .get()
            .errors
            .contains(&IssueCode::InitialPasswordTooShort)
    });
    let has_disk_missing =
        Memo::new(move |_| state.get().warnings.contains(&IssueCode::DiskMissing));
    let has_disk_error =
        Memo::new(move |_| state.get().errors.contains(&IssueCode::DiskPathUnstable));
    let has_china_notice =
        Memo::new(move |_| state.get().notices.contains(&IssueCode::ChinaNetwork));

    let file_preview = Memo::new(move |_| {
        if !state.get().can_download {
            return None;
        }

        generate(&spec())
            .ok()
            .map(|project| render_file_tree(i18n, &project.files))
    });
    let install_command = Memo::new(move |_| {
        let spec = spec();
        if derive_state(&spec).can_install {
            Some(format!(
                "nix run github:nix-community/nixos-anywhere -- --flake .#{} root@<target-ip>",
                spec.host_name.trim()
            ))
        } else {
            None
        }
    });

    let download_zip = move |_| {
        flash.set(None);
        let spec = spec();
        match generate(&spec).and_then(|project| zip_project(&project)) {
            Ok(bytes) => {
                match download_bytes(&format!("nixos-{}.zip", spec.host_name.trim()), &bytes) {
                    Ok(()) => flash.set(Some(FlashMessage::DownloadReady)),
                    Err(()) => flash.set(Some(FlashMessage::DownloadFailed)),
                }
            }
            Err(_) => flash.set(Some(FlashMessage::DownloadFailed)),
        }
    };

    let copy_command = move |_| {
        flash.set(None);
        match install_command.get() {
            Some(command) => {
                if copy_with_selection_fallback(&command).is_ok() {
                    flash.set(Some(FlashMessage::CommandCopied));
                    return;
                }

                spawn_local(async move {
                    let message = match copy_with_clipboard_api(&command).await {
                        Ok(()) => FlashMessage::CommandCopied,
                        Err(()) => FlashMessage::ClipboardFailed,
                    };
                    flash.set(Some(message));
                });
            }
            None => flash.set(Some(FlashMessage::ClipboardFailed)),
        }
    };

    view! {
        <main class="app-shell">
            <section class="workspace">
                <header class="page-header">
                    <div>
                        <p class="eyebrow">{move || t_string!(i18n, app.eyebrow)}</p>
                        <h1>{move || t_string!(i18n, app.title)}</h1>
                    </div>
                    <div class="header-tools">
                        <div class="language-switcher" aria-label=move || t_string!(i18n, language.label)>
                            <For
                                each=Locale::get_all
                                key=|locale| **locale
                                let:locale
                            >
                                <button
                                    type="button"
                                    class:active=move || i18n.get_locale() == *locale
                                    on:click=move |_| i18n.set_locale(*locale)
                                >
                                    {td_string!(*locale, language_name)}
                                </button>
                            </For>
                        </div>
                        <div class="revision">
                            {move || t_string!(i18n, app.upstream)} " " <code>{UPSTREAM_REV}</code>
                        </div>
                    </div>
                </header>

                <div class="layout">
                    <form class="panel form-panel">
                        <fieldset>
                            <legend>{move || t_string!(i18n, sections.basics)}</legend>
                            <label for="host-name">{move || t_string!(i18n, fields.host_name)}</label>
                            <input
                                id="host-name"
                                aria-invalid=move || bool_attr(has_host_error.get())
                                aria-describedby="host-name-error"
                                prop:value=move || host_name.get()
                                on:input=move |ev| host_name.set(event_target_value(&ev))
                            />
                            <Show when=move || has_host_error.get()>
                                <p id="host-name-error" class="field-error">
                                    {move || t_string!(i18n, validation.host_name_invalid)}
                                </p>
                            </Show>

                            <label for="username">{move || t_string!(i18n, fields.username)}</label>
                            <input
                                id="username"
                                aria-invalid=move || bool_attr(has_username_error.get())
                                aria-describedby="username-error"
                                prop:value=move || username.get()
                                on:input=move |ev| username.set(event_target_value(&ev))
                            />
                            <Show when=move || has_username_error.get()>
                                <p id="username-error" class="field-error">
                                    {move || t_string!(i18n, validation.username_invalid)}
                                </p>
                            </Show>
                        </fieldset>

                        <fieldset>
                            <legend>{move || t_string!(i18n, sections.login)}</legend>
                            <div class="segmented" role="group" aria-label=move || t_string!(i18n, sections.login)>
                                <button
                                    type="button"
                                    class:active=move || login_choice.get() == LoginChoice::Ssh
                                    on:click=move |_| login_choice.set(LoginChoice::Ssh)
                                >
                                    {move || t_string!(i18n, choices.ssh)}
                                </button>
                                <button
                                    type="button"
                                    class:active=move || login_choice.get() == LoginChoice::Password
                                    on:click=move |_| login_choice.set(LoginChoice::Password)
                                >
                                    {move || t_string!(i18n, choices.password)}
                                </button>
                            </div>
                            <Show
                                when=move || login_choice.get() == LoginChoice::Ssh
                                fallback=move || view! {
                                    <label for="initial-password">{move || t_string!(i18n, fields.initial_password)}</label>
                                    <input
                                        id="initial-password"
                                        type="password"
                                        autocomplete="new-password"
                                        aria-invalid=move || bool_attr(has_login_missing.get() || has_password_error.get())
                                        aria-describedby="initial-password-error login-help"
                                        prop:value=move || initial_password.get()
                                        on:input=move |ev| initial_password.set(event_target_value(&ev))
                                    />
                                    <Show when=move || has_login_missing.get()>
                                        <p id="initial-password-error" class="field-error">
                                            {move || t_string!(i18n, validation.password_required)}
                                        </p>
                                    </Show>
                                    <Show when=move || has_password_error.get()>
                                        <p class="field-error">{move || t_string!(i18n, validation.password_too_short)}</p>
                                    </Show>
                                }
                            >
                                <label for="ssh-public-key">{move || t_string!(i18n, fields.ssh_public_key)}</label>
                                <textarea
                                    id="ssh-public-key"
                                    rows="4"
                                    aria-invalid=move || bool_attr(has_login_missing.get() || has_ssh_error.get())
                                    aria-describedby="ssh-public-key-error login-help"
                                    prop:value=move || ssh_public_key.get()
                                    on:input=move |ev| ssh_public_key.set(event_target_value(&ev))
                                ></textarea>
                                <Show when=move || has_login_missing.get()>
                                    <p id="ssh-public-key-error" class="field-error">
                                        {move || t_string!(i18n, validation.ssh_required)}
                                    </p>
                                </Show>
                                <Show when=move || has_ssh_error.get()>
                                    <p class="field-error">{move || t_string!(i18n, validation.ssh_invalid)}</p>
                                </Show>
                            </Show>
                            <p id="login-help" class="field-help">{move || t_string!(i18n, help.login)}</p>
                        </fieldset>

                        <fieldset>
                            <legend>{move || t_string!(i18n, sections.target)}</legend>
                            <label for="target-disk">{move || t_string!(i18n, fields.target_disk)}</label>
                            <input
                                id="target-disk"
                                placeholder="/dev/disk/by-id/..."
                                aria-invalid=move || bool_attr(has_disk_error.get())
                                aria-describedby="target-disk-help target-disk-risk target-disk-error"
                                prop:value=move || disk_path.get()
                                on:input=move |ev| disk_path.set(event_target_value(&ev))
                            />
                            <p id="target-disk-help" class="field-help">
                                {move || t_string!(i18n, help.disk_intro)}
                                " "
                                <Text tag=TextTag::Code>"ls -l /dev/disk/by-id/"</Text>
                                " "
                                {move || t_string!(i18n, help.disk_copy)}
                                " "
                                <Text tag=TextTag::Code>"/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_..."</Text>
                                {move || t_string!(i18n, help.disk_avoid_prefix)}
                                " "
                                <Text tag=TextTag::Code>"/dev/sdX"</Text>
                                ", "
                                <Text tag=TextTag::Code>"/dev/nvme0n1"</Text>
                                " "
                                {move || t_string!(i18n, help.disk_or_partition)}
                                " "
                                <Text tag=TextTag::Code>"-partN"</Text>
                                {move || t_string!(i18n, help.disk_suffix)}
                            </p>
                            <p id="target-disk-risk" class="danger-callout">{move || t_string!(i18n, help.disk_risk)}</p>
                            <Show when=move || has_disk_missing.get()>
                                <p class="field-warning">{move || t_string!(i18n, help.disk_missing)}</p>
                            </Show>
                            <Show when=move || has_disk_error.get()>
                                <p id="target-disk-error" class="field-error">
                                    {move || t_string!(i18n, validation.disk_unstable)}
                                </p>
                            </Show>

                            <label class="check-row">
                                <input
                                    type="checkbox"
                                    prop:checked=move || nvidia.get()
                                    on:change=move |ev| nvidia.set(event_target_checked(&ev))
                                />
                                <span>{move || t_string!(i18n, fields.nvidia)}</span>
                            </label>
                        </fieldset>

                        <fieldset>
                            <legend>{move || t_string!(i18n, sections.network)}</legend>
                            <div class="segmented" role="group" aria-label=move || t_string!(i18n, sections.network)>
                                <button
                                    type="button"
                                    class:active=move || network_mode.get() == NetworkMode::China
                                    on:click=move |_| network_mode.set(NetworkMode::China)
                                >
                                    {move || t_string!(i18n, choices.china)}
                                </button>
                                <button
                                    type="button"
                                    class:active=move || network_mode.get() == NetworkMode::Global
                                    on:click=move |_| network_mode.set(NetworkMode::Global)
                                >
                                    {move || t_string!(i18n, choices.global)}
                                </button>
                            </div>
                            <Show when=move || has_china_notice.get()>
                                <p class="field-notice">{move || t_string!(i18n, help.china_network)}</p>
                            </Show>
                        </fieldset>

                        <fieldset>
                            <legend>{move || t_string!(i18n, sections.git)}</legend>
                            <p class="field-help">{move || t_string!(i18n, help.git)}</p>
                            <label for="git-name">{move || t_string!(i18n, fields.git_name)}</label>
                            <input
                                id="git-name"
                                prop:value=move || git_name.get()
                                on:input=move |ev| git_name.set(event_target_value(&ev))
                            />
                            <label for="git-email">{move || t_string!(i18n, fields.git_email)}</label>
                            <input
                                id="git-email"
                                type="email"
                                prop:value=move || git_email.get()
                                on:input=move |ev| git_email.set(event_target_value(&ev))
                            />
                        </fieldset>
                    </form>

                    <aside class="panel output-panel">
                        <section>
                            <h2>{move || t_string!(i18n, sections.package)}</h2>
                            <Show
                                when=move || state.get().can_download
                                fallback=move || view! {
                                    <p class="message error">{move || t_string!(i18n, output.package_blocked)}</p>
                                }
                            >
                                <p class="message ok">{move || t_string!(i18n, output.package_ready)}</p>
                            </Show>
                            <div class="actions">
                                <Button
                                    appearance=ButtonAppearance::Primary
                                    disabled=move || !state.get().can_download
                                    on_click=download_zip
                                >
                                    {move || t_string!(i18n, actions.download)}
                                </Button>
                                <Button
                                    disabled=move || !state.get().can_install
                                    on_click=copy_command
                                >
                                    {move || t_string!(i18n, actions.copy_command)}
                                </Button>
                            </div>
                            <Show when=move || state.get().can_download && !state.get().can_install>
                                <p class="action-note">{move || t_string!(i18n, output.command_unavailable)}</p>
                            </Show>
                            <Show when=move || flash.get().is_some()>
                                <p class="flash">{move || flash_text(i18n, flash.get())}</p>
                            </Show>
                        </section>

                        <section>
                            <h2>{move || t_string!(i18n, sections.command)}</h2>
                            <Show
                                when=move || install_command.get().is_some()
                                fallback=move || view! {
                                    <p class="empty-output">{move || t_string!(i18n, output.command_unavailable)}</p>
                                }
                            >
                                <pre class="command">{move || install_command.get().unwrap_or_default()}</pre>
                            </Show>
                        </section>

                        <section>
                            <h2>{move || t_string!(i18n, sections.files)}</h2>
                            <Show
                                when=move || file_preview.get().is_some()
                                fallback=move || view! {
                                    <p class="empty-output">{move || t_string!(i18n, output.preview_unavailable)}</p>
                                }
                            >
                                <pre class="preview">{move || file_preview.get().unwrap_or_default()}</pre>
                            </Show>
                        </section>
                    </aside>
                </div>
            </section>
        </main>
    }
}

fn flash_text(i18n: leptos_i18n::I18nContext<Locale>, message: Option<FlashMessage>) -> String {
    match message {
        Some(FlashMessage::DownloadReady) => t_string!(i18n, flash.download_ready).to_string(),
        Some(FlashMessage::CommandCopied) => t_string!(i18n, flash.command_copied).to_string(),
        Some(FlashMessage::DownloadFailed) => t_string!(i18n, flash.download_failed).to_string(),
        Some(FlashMessage::ClipboardFailed) => t_string!(i18n, flash.clipboard_failed).to_string(),
        None => String::new(),
    }
}

#[derive(Default)]
struct TreeNode {
    children: BTreeMap<String, TreeNode>,
    note: Option<String>,
}

fn render_file_tree(i18n: leptos_i18n::I18nContext<Locale>, files: &[GeneratedFile]) -> String {
    let mut root = TreeNode::default();
    let mut sorted_files = files.iter().collect::<Vec<_>>();
    sorted_files.sort_by(|left, right| left.path.cmp(&right.path));

    for file in sorted_files {
        let note = file_tree_note(i18n, file);
        let mut node = &mut root;

        for part in file.path.split('/') {
            node = node.children.entry(part.to_owned()).or_default();
        }

        node.note = note;
    }

    let mut lines = vec![".".to_owned()];
    append_tree_lines(&root, "", &mut lines);
    lines.join("\n")
}

fn file_tree_note(i18n: leptos_i18n::I18nContext<Locale>, file: &GeneratedFile) -> Option<String> {
    if file.path == "flake.nix"
        && file
            .contents
            .contains("upstream.nixosModules.nvidiaDesktop")
    {
        return Some(t_string!(i18n, tree.nvidia).to_string());
    }

    if file.path.ends_with("/configuration.nix") && file.contents.contains("profile = \"china\"") {
        return Some(t_string!(i18n, tree.china_mainland).to_string());
    }

    if file.path.ends_with("/disko-config.nix") {
        return Some(t_string!(i18n, tree.disko).to_string());
    }

    None
}

fn append_tree_lines(node: &TreeNode, prefix: &str, lines: &mut Vec<String>) {
    let child_count = node.children.len();

    for (index, (name, child)) in node.children.iter().enumerate() {
        let is_last = index + 1 == child_count;
        let connector = if is_last { "`-- " } else { "|-- " };
        let note = child
            .note
            .as_ref()
            .map(|text| format!("  # {text}"))
            .unwrap_or_default();

        lines.push(format!("{prefix}{connector}{name}{note}"));

        let child_prefix = if is_last {
            format!("{prefix}    ")
        } else {
            format!("{prefix}|   ")
        };
        append_tree_lines(child, &child_prefix, lines);
    }
}

fn bool_attr(value: bool) -> &'static str {
    if value {
        "true"
    } else {
        "false"
    }
}

fn download_bytes(filename: &str, bytes: &[u8]) -> Result<(), ()> {
    let window = web_sys::window().ok_or(())?;
    let document = window.document().ok_or(())?;
    let array = Uint8Array::from(bytes);
    let parts = Array::new();
    parts.push(array.as_ref());

    let options = BlobPropertyBag::new();
    options.set_type("application/zip");
    let blob = Blob::new_with_u8_array_sequence_and_options(&parts, &options).map_err(|_| ())?;
    let url = Url::create_object_url_with_blob(&blob).map_err(|_| ())?;
    let anchor = document
        .create_element("a")
        .map_err(|_| ())?
        .dyn_into::<HtmlAnchorElement>()
        .map_err(|_| ())?;

    anchor.set_href(&url);
    anchor.set_download(filename);
    let body = document.body().ok_or(())?;
    body.append_child(&anchor).map_err(|_| ())?;
    anchor.click();
    body.remove_child(&anchor).map_err(|_| ())?;
    Url::revoke_object_url(&url).ok();
    Ok(())
}

async fn copy_with_clipboard_api(text: &str) -> Result<(), ()> {
    let window = web_sys::window().ok_or(())?;
    let promise = window.navigator().clipboard().write_text(text);
    JsFuture::from(promise).await.map_err(|_| ())?;
    Ok(())
}

fn copy_with_selection_fallback(text: &str) -> Result<(), ()> {
    let window = web_sys::window().ok_or(())?;
    let document = window.document().ok_or(())?;
    let body = document.body().ok_or(())?;
    let textarea = document
        .create_element("textarea")
        .map_err(|_| ())?
        .dyn_into::<HtmlTextAreaElement>()
        .map_err(|_| ())?;

    textarea.set_value(text);
    textarea
        .set_attribute("readonly", "readonly")
        .map_err(|_| ())?;
    textarea
        .set_attribute(
            "style",
            "position:fixed;left:-9999px;top:0;opacity:0;pointer-events:none;",
        )
        .map_err(|_| ())?;

    body.append_child(&textarea).map_err(|_| ())?;
    textarea.select();
    let html_document = document.dyn_into::<HtmlDocument>().map_err(|_| ())?;
    let copied = html_document.exec_command("copy").unwrap_or(false);
    body.remove_child(&textarea).ok();

    if !copied {
        return Err(());
    }

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
