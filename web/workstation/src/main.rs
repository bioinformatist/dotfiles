mod app;
mod generator;

use app::App;

fn main() {
    std::panic::set_hook(Box::new(console_error_panic_hook::hook));
    leptos::mount::mount_to_body(App);
}
