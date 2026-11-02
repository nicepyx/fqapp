#include "mini_reader_window.h"

#include <flutter/standard_method_codec.h>

namespace {
constexpr int kMiniReaderHotkey = 0x4651;
constexpr UINT_PTR kMiniReaderTimer = 0x4651;
constexpr UINT kBindingChanged = WM_APP + 0x465;
HWND binding_reader = nullptr;

void CALLBACK ForegroundChanged(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD) {
  if (binding_reader) PostMessage(binding_reader, kBindingChanged, 0, 0);
}

std::string Utf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int length = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  std::string result(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), length, nullptr, nullptr);
  return result;
}
}  // namespace

MiniReaderWindow::MiniReaderWindow(HWND window,
                                 flutter::BinaryMessenger* messenger)
    : window_(window),
      binding_(window),
      channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "fqapp/mini_reader",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto& method = call.method_name();
        if (method == "enter") {
          hotkey_registered_ = RegisterBossKey(call.arguments());
          active_ = true;
          was_layered_ =
              (GetWindowLongPtr(window_, GWL_EXSTYLE) & WS_EX_LAYERED) != 0;
          SetTimer(window_, kMiniReaderTimer, 80, nullptr);
          result->Success(flutter::EncodableValue(hotkey_registered_));
          return;
        }
        if (method == "setBossKey") {
          hotkey_registered_ = RegisterBossKey(call.arguments());
          result->Success(flutter::EncodableValue(hotkey_registered_));
          return;
        }
        if (method == "windowTargets") {
          flutter::EncodableList targets;
          for (const auto& target : WindowBinding::Enumerate(window_)) {
            targets.emplace_back(flutter::EncodableMap{
              {flutter::EncodableValue("handle"), flutter::EncodableValue(reinterpret_cast<int64_t>(target.handle))},
              {flutter::EncodableValue("title"), flutter::EncodableValue(Utf8(target.title))},
              {flutter::EncodableValue("application"), flutter::EncodableValue(Utf8(target.application))},
            });
          }
          result->Success(flutter::EncodableValue(targets));
          return;
        }
        if (method == "bindWindow") {
          HWND target = nullptr;
          if (call.arguments()) {
            if (const auto* handle32 = std::get_if<int32_t>(call.arguments())) target = reinterpret_cast<HWND>(static_cast<intptr_t>(*handle32));
            else if (const auto* handle64 = std::get_if<int64_t>(call.arguments())) target = reinterpret_cast<HWND>(*handle64);
          }
          if (target) {
            if (!binding_.Bind(target)) {
              result->Error("window_unavailable", "目标窗口已关闭，请刷新后重新选择");
              return;
            }
            binding_reader = window_;
            if (!foreground_hook_) foreground_hook_ = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
                nullptr, ForegroundChanged, 0, 0, WINEVENT_OUTOFCONTEXT);
          } else {
            binding_.Detach();
            if (foreground_hook_) UnhookWinEvent(foreground_hook_);
            foreground_hook_ = nullptr;
            binding_reader = nullptr;
          }
          NotifyVisibility();
          result->Success();
          return;
        }
        if (method == "leave") {
          Leave();
        } else if (method == "toggleHidden") {
          ToggleHidden();
        } else if (method == "setHoverHide" || method == "setMenuOpen") {
          const auto* value = call.arguments()
                                  ? std::get_if<bool>(call.arguments())
                                  : nullptr;
          if (!value) {
            result->Error("invalid_argument", "Expected a boolean.");
            return;
          }
          if (method == "setHoverHide") {
            hover_hide_ = *value;
          } else {
            menu_open_ = *value;
          }
          PollCursor();
        } else {
          result->NotImplemented();
          return;
        }
        result->Success();
      });
}

MiniReaderWindow::~MiniReaderWindow() {
  Leave();
  channel_->SetMethodCallHandler(nullptr);
}

void MiniReaderWindow::Leave() {
  if (!active_) return;
  binding_.Detach();
  if (foreground_hook_) UnhookWinEvent(foreground_hook_);
  foreground_hook_ = nullptr;
  binding_reader = nullptr;
  KillTimer(window_, kMiniReaderTimer);
  if (hotkey_registered_) UnregisterHotKey(window_, kMiniReaderHotkey);
  hotkey_registered_ = false;
  SetHidden(false);
  active_ = false;
  hover_hide_ = false;
  menu_open_ = false;
  boss_hidden_ = false;
  reveal_until_enter_ = false;
  inside_ = true;
  if (!was_layered_) {
    SetWindowLongPtr(window_, GWL_EXSTYLE,
                     GetWindowLongPtr(window_, GWL_EXSTYLE) & ~WS_EX_LAYERED);
    RedrawWindow(window_, nullptr, nullptr,
                 RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);
  }
}

std::optional<LRESULT> MiniReaderWindow::HandleMessage(UINT message,
                                                      WPARAM wparam) {
  if (!active_) return std::nullopt;
  if (message == WM_TIMER && wparam == kMiniReaderTimer) {
    SyncBinding();
    PollCursor();
    return 0;
  }
  if (message == kBindingChanged) {
    SyncBinding();
    return 0;
  }
  if (message == WM_HOTKEY && wparam == kMiniReaderHotkey) {
    ToggleHidden();
    return 0;
  }
  return std::nullopt;
}

void MiniReaderWindow::PollCursor() {
  POINT cursor;
  RECT bounds;
  if (!GetCursorPos(&cursor) || !GetWindowRect(window_, &bounds)) return;
  const bool inside = PtInRect(&bounds, cursor) != FALSE;
  const bool entered = inside && !inside_;
  if (inside != inside_) {
    inside_ = inside;
    channel_->InvokeMethod("hover",
                           std::make_unique<flutter::EncodableValue>(inside));
  }
  if (boss_hidden_) {
    if (!hotkey_registered_ && entered) {
      boss_hidden_ = false;
      SetHidden(false);
    }
    return;
  }
  // Hotkey recovery must remain visible until the mouse reaches the window.
  if (reveal_until_enter_) {
    if (inside) reveal_until_enter_ = false;
    return;
  }
  SetHidden(hover_hide_ && !menu_open_ && !inside);
}

void MiniReaderWindow::SetHidden(bool hidden) {
  if (hidden_ == hidden) return;
  hidden_ = hidden;
  auto style = GetWindowLongPtr(window_, GWL_EXSTYLE) | WS_EX_LAYERED;
  if (hidden) {
    style |= WS_EX_TRANSPARENT;
  } else {
    style &= ~WS_EX_TRANSPARENT;
  }
  SetWindowLongPtr(window_, GWL_EXSTYLE, style);
  // Keep the HWND alive for cursor polling while hidden clicks pass through.
  SetLayeredWindowAttributes(window_, 0, static_cast<BYTE>(hidden ? 0 : 255),
                             LWA_ALPHA);
  NotifyVisibility();
}

void MiniReaderWindow::ToggleHidden() {
  // Sample the click position so mouse recovery waits for a fresh entry.
  PollCursor();
  boss_hidden_ = !boss_hidden_;
  reveal_until_enter_ = !boss_hidden_;
  SetHidden(boss_hidden_);
}

bool MiniReaderWindow::RegisterBossKey(const flutter::EncodableValue* value) {
  if (hotkey_registered_) UnregisterHotKey(window_, kMiniReaderHotkey);
  const auto* args = value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (!args) return false;
  const auto key = args->find(flutter::EncodableValue("key"));
  const auto modifiers = args->find(flutter::EncodableValue("modifiers"));
  if (key == args->end() || modifiers == args->end() ||
      !std::holds_alternative<int32_t>(key->second) || !std::holds_alternative<int32_t>(modifiers->second)) return false;
  return RegisterHotKey(window_, kMiniReaderHotkey, MOD_NOREPEAT | std::get<int32_t>(modifiers->second),
      std::get<int32_t>(key->second)) != FALSE;
}

void MiniReaderWindow::SyncBinding() {
  if (!binding_.target()) return;
  const bool attached = binding_.Sync();
  NotifyVisibility();
  if (attached) return;
  if (foreground_hook_) UnhookWinEvent(foreground_hook_);
  foreground_hook_ = nullptr;
  binding_reader = nullptr;
  channel_->InvokeMethod("targetClosed", nullptr);
}

void MiniReaderWindow::NotifyVisibility() {
  const bool hidden = hidden_ || !IsWindowVisible(window_);
  if (reported_hidden_ == hidden) return;
  reported_hidden_ = hidden;
  channel_->InvokeMethod("hidden", std::make_unique<flutter::EncodableValue>(hidden));
}
