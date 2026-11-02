//! Servo for Arma: one engine per profile, many pages, each drawn into its own
//! host NSView, driven through a C API on the main thread. Servo wakes the host
//! from any thread through the engine's `wake`; the host then calls
//! `arma_servo_engine_spin` on the main thread.

use std::cell::RefCell;
use std::ffi::{CStr, CString, c_char, c_void};
use std::ptr::NonNull;
use std::rc::Rc;
use std::str::FromStr;

use dpi::PhysicalSize;
use euclid::Scale;
use raw_window_handle::{
    AppKitDisplayHandle, AppKitWindowHandle, DisplayHandle, RawDisplayHandle, RawWindowHandle, WindowHandle,
};
use servo::{
    Code, DevicePoint, InputEvent, Key, KeyState, KeyboardEvent, LoadStatus, Location, Modifiers, MouseButton,
    MouseButtonAction, MouseButtonEvent, MouseMoveEvent, RenderingContext, Servo, ServoBuilder, WebView,
    UserContentManager, UserScript, WebViewBuilder, WheelDelta, WheelEvent, WheelMode, WindowRenderingContext,
};
use url::Url;

/// Called from any thread when Servo has work for the main thread.
pub type ArmaWake = extern "C" fn(context: *mut c_void);
/// Called on the main thread when a page has a new frame to paint.
pub type ArmaFrame = extern "C" fn(page_context: *mut c_void);
/// Called on the main thread with a page event and its text.
pub type ArmaEvent = extern "C" fn(page_context: *mut c_void, kind: i32, text: *const c_char);

/// Page event kinds.
pub const ARMA_EVENT_TITLE: i32 = 0;
pub const ARMA_EVENT_URL: i32 = 1;
pub const ARMA_EVENT_LOAD_STARTED: i32 = 2;
pub const ARMA_EVENT_LOAD_COMPLETE: i32 = 3;
/// History changed: text is the current entry's index, then each entry's
/// URL, oldest first, one per line.
pub const ARMA_EVENT_HISTORY: i32 = 4;
pub const ARMA_EVENT_LOAD_HEAD_PARSED: i32 = 5;

struct Waker {
    context: usize,
    wake: ArmaWake,
}

impl servo::EventLoopWaker for Waker {
    fn clone_box(&self) -> Box<dyn servo::EventLoopWaker> {
        Box::new(Waker { context: self.context, wake: self.wake })
    }

    fn wake(&self) {
        (self.wake)(self.context as *mut c_void);
    }
}

#[derive(Clone, Copy)]
struct PageCallbacks {
    context: usize,
    frame: ArmaFrame,
    event: ArmaEvent,
}

struct Delegate(PageCallbacks);

impl Delegate {
    fn send(&self, kind: i32, text: &str) {
        let text = CString::new(text.replace('\0', "")).unwrap_or_default();
        (self.0.event)(self.0.context as *mut c_void, kind, text.as_ptr());
    }
}

impl servo::WebViewDelegate for Delegate {
    fn notify_new_frame_ready(&self, _: WebView) {
        (self.0.frame)(self.0.context as *mut c_void);
    }

    fn notify_page_title_changed(&self, _: WebView, title: Option<String>) {
        self.send(ARMA_EVENT_TITLE, title.as_deref().unwrap_or(""));
    }

    fn notify_url_changed(&self, _: WebView, url: Url) {
        self.send(ARMA_EVENT_URL, url.as_str());
    }

    fn notify_load_status_changed(&self, _: WebView, status: LoadStatus) {
        match status {
            LoadStatus::Started => self.send(ARMA_EVENT_LOAD_STARTED, ""),
            LoadStatus::HeadParsed => self.send(ARMA_EVENT_LOAD_HEAD_PARSED, ""),
            LoadStatus::Complete => self.send(ARMA_EVENT_LOAD_COMPLETE, ""),
        }
    }

    fn notify_history_changed(&self, _: WebView, entries: Vec<Url>, current: usize) {
        let mut text = current.to_string();
        for entry in entries {
            text.push('\n');
            text.push_str(entry.as_str());
        }
        self.send(ARMA_EVENT_HISTORY, &text);
    }
}

/// One Servo instance: one profile, holding its cookies and storage in its
/// folder, or in memory without one.
pub struct ArmaServoEngine {
    servo: Servo,
    /// The scripts every page runs, such as extensions' content scripts.
    content: Rc<UserContentManager>,
}

/// One page: a web view drawing into a host NSView.
pub struct ArmaServoPage {
    rendering_context: Rc<WindowRenderingContext>,
    webview: RefCell<Option<WebView>>,
}

fn text(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(value) }.to_str().ok().map(str::to_owned)
}

/// Starts Servo for the profile in `profile_dir`, or in memory for null.
/// Servo's options are the process's, so a process holds one engine.
///
/// # Safety
/// `profile_dir` is null or a NUL-terminated UTF-8 path. Main thread only.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_engine_new(
    profile_dir: *const c_char, context: *mut c_void, wake: ArmaWake,
) -> *mut ArmaServoEngine {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();
    let mut opts = servo::Opts::default();
    match text(profile_dir) {
        Some(dir) => opts.config_dir = Some(std::path::PathBuf::from(dir)),
        None => opts.temporary_storage = true,
    }
    let servo =
        ServoBuilder::default().opts(opts).event_loop_waker(Box::new(Waker { context: context as usize, wake })).build();
    servo.setup_logging();
    let content = Rc::new(UserContentManager::new(&servo));
    Box::into_raw(Box::new(ArmaServoEngine { servo, content }))
}

/// Adds a script every page runs as its documents start, from then on.
/// A page already open runs it once it reloads.
///
/// # Safety
/// `script` is a NUL-terminated UTF-8 string. Main thread only.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_engine_add_user_script(engine: *mut ArmaServoEngine, script: *const c_char) {
    let (Some(engine), Some(script)) = (unsafe { engine.as_ref() }, text(script)) else { return };
    engine.content.add_script(Rc::new(UserScript::new(script, None)));
}

/// Runs the work Servo woke the host for.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_engine_spin(engine: *mut ArmaServoEngine) {
    if let Some(engine) = unsafe { engine.as_ref() } {
        engine.servo.spin_event_loop();
    }
}

/// Shuts Servo down, writing its cookie jar and storage, and frees it. Close
/// every page first.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_engine_free(engine: *mut ArmaServoEngine) {
    if engine.is_null() {
        return;
    }
    let engine = unsafe { Box::from_raw(engine) };
    engine.servo.spin_event_loop();
    drop(engine);
}

/// Opens a page drawing into `ns_view`, `width`×`height` device pixels at
/// `scale`, loading `url`, or about:blank for null.
///
/// # Safety
/// `ns_view` must be a live NSView that outlives the page. Main thread only.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_page_new(
    engine: *mut ArmaServoEngine, ns_view: *mut c_void, width: u32, height: u32, scale: f32, url: *const c_char,
    page_context: *mut c_void, frame: ArmaFrame, event: ArmaEvent,
) -> *mut ArmaServoPage {
    let Some(engine) = (unsafe { engine.as_ref() }) else { return std::ptr::null_mut() };
    let Some(view) = NonNull::new(ns_view) else { return std::ptr::null_mut() };
    let display = unsafe { DisplayHandle::borrow_raw(RawDisplayHandle::AppKit(AppKitDisplayHandle::new())) };
    let window = unsafe { WindowHandle::borrow_raw(RawWindowHandle::AppKit(AppKitWindowHandle::new(view))) };
    let Ok(rendering_context) =
        WindowRenderingContext::new(display, window, PhysicalSize::new(width.max(1), height.max(1)))
    else {
        return std::ptr::null_mut();
    };
    let rendering_context = Rc::new(rendering_context);
    let _ = rendering_context.make_current();
    let start = text(url).and_then(|text| Url::parse(&text).ok()).unwrap_or_else(|| Url::parse("about:blank").unwrap());
    let callbacks = PageCallbacks { context: page_context as usize, frame, event };
    let webview = WebViewBuilder::new(&engine.servo, rendering_context.clone())
        .url(start)
        .hidpi_scale_factor(Scale::new(scale))
        .delegate(Rc::new(Delegate(callbacks)))
        .user_content_manager(engine.content.clone())
        .build();
    Box::into_raw(Box::new(ArmaServoPage { rendering_context, webview: RefCell::new(Some(webview)) }))
}

fn with<T>(page: *mut ArmaServoPage, body: impl FnOnce(&ArmaServoPage, &WebView) -> T) -> Option<T> {
    let page = unsafe { page.as_ref()? };
    let webview = page.webview.borrow().clone()?;
    Some(body(page, &webview))
}

/// Closes the page and frees it.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_free(page: *mut ArmaServoPage) {
    if page.is_null() {
        return;
    }
    let page = unsafe { Box::from_raw(page) };
    page.webview.borrow_mut().take();
}

/// Paints the page's latest frame into its view.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_paint(page: *mut ArmaServoPage) {
    with(page, |page, webview| {
        let _ = page.rendering_context.make_current();
        webview.paint();
        page.rendering_context.present();
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_resize(page: *mut ArmaServoPage, width: u32, height: u32) {
    with(page, |_, webview| webview.resize(PhysicalSize::new(width.max(1), height.max(1))));
}

/// Says whether the page is on show, so Servo can throttle hidden pages.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_set_visible(page: *mut ArmaServoPage, visible: i32) {
    with(page, |_, webview| if visible != 0 { webview.show() } else { webview.hide() });
}

#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_set_focused(page: *mut ArmaServoPage, focused: i32) {
    with(page, |_, webview| webview.set_focused(focused != 0));
}

/// # Safety
/// `url` must be a NUL-terminated UTF-8 string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_page_load(page: *mut ArmaServoPage, url: *const c_char) {
    let Some(url) = text(url).and_then(|text| Url::parse(&text).ok()) else { return };
    with(page, |_, webview| webview.load(url));
}

/// Moves through history: negative steps back, positive forward.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_traverse(page: *mut ArmaServoPage, steps: i32) {
    with(page, |_, webview| {
        if steps < 0 && webview.can_go_back() {
            webview.go_back(steps.unsigned_abs() as usize);
        } else if steps > 0 && webview.can_go_forward() {
            webview.go_forward(steps as usize);
        }
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_reload(page: *mut ArmaServoPage) {
    with(page, |_, webview| webview.reload());
}

/// Scrolls by `dx`, `dy` device pixels at `x`, `y`.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_scroll(page: *mut ArmaServoPage, dx: f64, dy: f64, x: f32, y: f32) {
    with(page, |_, webview| {
        webview.notify_input_event(InputEvent::Wheel(WheelEvent::new(
            WheelDelta { x: dx, y: dy, z: 0.0, mode: WheelMode::DeltaPixel },
            DevicePoint::new(x, y).into(),
        )));
    });
}

/// A press (`down` 1) or release (0) of `button` (0 primary, 1 middle, 2
/// secondary) at `x`, `y` device pixels.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_mouse_button(page: *mut ArmaServoPage, button: i32, down: i32, x: f32, y: f32) {
    let action = if down != 0 { MouseButtonAction::Down } else { MouseButtonAction::Up };
    let button = match button {
        1 => MouseButton::Auxiliary,
        2 => MouseButton::Secondary,
        _ => MouseButton::Primary,
    };
    with(page, |_, webview| {
        webview.notify_input_event(InputEvent::MouseButton(MouseButtonEvent::new(
            action,
            button,
            DevicePoint::new(x, y).into(),
        )));
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_page_mouse_move(page: *mut ArmaServoPage, x: f32, y: f32) {
    with(page, |_, webview| {
        webview.notify_input_event(InputEvent::MouseMove(MouseMoveEvent::new(DevicePoint::new(x, y).into())));
    });
}

/// Modifier bits for `arma_servo_page_key`.
pub const ARMA_MODIFIER_SHIFT: u32 = 1;
pub const ARMA_MODIFIER_CONTROL: u32 = 2;
pub const ARMA_MODIFIER_ALT: u32 = 4;
pub const ARMA_MODIFIER_META: u32 = 8;

/// A key press (`down` 1) or release (0). `key` is the DOM key value: the
/// character typed, or a named key such as "Enter", "Backspace",
/// "ArrowLeft" or "Tab".
///
/// # Safety
/// `key` must be a NUL-terminated UTF-8 string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_page_key(page: *mut ArmaServoPage, down: i32, key: *const c_char, modifiers: u32) {
    let Some(name) = text(key) else { return };
    let key = Key::from_str(&name).unwrap_or(Key::Character(name));
    let mut flags = Modifiers::empty();
    if modifiers & ARMA_MODIFIER_SHIFT != 0 {
        flags |= Modifiers::SHIFT;
    }
    if modifiers & ARMA_MODIFIER_CONTROL != 0 {
        flags |= Modifiers::CONTROL;
    }
    if modifiers & ARMA_MODIFIER_ALT != 0 {
        flags |= Modifiers::ALT;
    }
    if modifiers & ARMA_MODIFIER_META != 0 {
        flags |= Modifiers::META;
    }
    let state = if down != 0 { KeyState::Down } else { KeyState::Up };
    with(page, |_, webview| {
        webview.notify_input_event(InputEvent::Keyboard(KeyboardEvent::new_without_event(
            state,
            key,
            Code::Unidentified,
            Location::Standard,
            flags,
            false,
            false,
        )));
    });
}

/// The number of cookies the engine holds for `url`, or -1.
///
/// # Safety
/// `url` must be a NUL-terminated UTF-8 string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn arma_servo_engine_cookie_count(engine: *mut ArmaServoEngine, url: *const c_char) -> i32 {
    let Some(url) = text(url).and_then(|text| Url::parse(&text).ok()) else { return -1 };
    let Some(engine) = (unsafe { engine.as_ref() }) else { return -1 };
    engine.servo.site_data_manager().cookies_for_url(url, servo::CookieSource::HTTP).len() as i32
}

/// Erases every cookie the engine holds.
#[unsafe(no_mangle)]
pub extern "C" fn arma_servo_engine_clear_cookies(engine: *mut ArmaServoEngine) {
    if let Some(engine) = unsafe { engine.as_ref() } {
        engine.servo.site_data_manager().clear_cookies(None);
    }
}
