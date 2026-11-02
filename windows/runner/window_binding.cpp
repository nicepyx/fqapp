#include "window_binding.h"

#include <filesystem>
#include <iterator>

namespace {
constexpr UINT kPositionFlags = SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE;
struct Enumeration {
  HWND exclude;
  DWORD process;
  std::vector<WindowBindingTarget> targets;
};

BOOL CALLBACK CollectWindow(HWND window, LPARAM parameter) {
  auto& state = *reinterpret_cast<Enumeration*>(parameter);
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  if (window == state.exclude || process == state.process ||
      !IsWindowVisible(window) || GetWindow(window, GW_OWNER) != nullptr ||
      (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOOLWINDOW)) return TRUE;
  const int length = GetWindowTextLengthW(window);
  if (length == 0) return TRUE;
  std::wstring title(length + 1, L'\0');
  title.resize(GetWindowTextW(window, title.data(), length + 1));
  std::wstring application;
  HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process);
  if (handle) {
    wchar_t path[32768];
    DWORD size = static_cast<DWORD>(std::size(path));
    if (QueryFullProcessImageNameW(handle, 0, path, &size)) {
      application = std::filesystem::path(path).filename().wstring();
    }
    CloseHandle(handle);
  }
  state.targets.push_back({window, std::move(title), std::move(application)});
  return TRUE;
}
}  // namespace

std::vector<WindowBindingTarget> WindowBinding::Enumerate(HWND exclude) {
  Enumeration state{exclude, GetCurrentProcessId(), {}};
  EnumWindows(CollectWindow, reinterpret_cast<LPARAM>(&state));
  return state.targets;
}

bool WindowBinding::Bind(HWND target) {
  if (!IsWindow(target) || target == window_) return false;
  Detach();
  target_ = target;
  Sync();
  return true;
}

void WindowBinding::Detach() {
  target_ = nullptr;
  if (hidden_for_target_) ShowWindow(window_, SW_SHOWNOACTIVATE);
  hidden_for_target_ = false;
}

bool WindowBinding::Sync() {
  if (!IsWindow(target_)) {
    Detach();
    return false;
  }
  if (IsIconic(target_) || !IsWindowVisible(target_)) {
    if (!hidden_for_target_) {
      // Hiding keeps normal geometry and avoids the taskbar minimize animation.
      ShowWindow(window_, SW_HIDE);
      hidden_for_target_ = true;
    }
    return true;
  }
  const bool target_topmost = (GetWindowLongPtr(target_, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
  const bool reader_topmost = (GetWindowLongPtr(window_, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
  if (target_topmost != reader_topmost) {
    SetWindowPos(window_, target_topmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, kPositionFlags);
  }
  HWND previous = GetWindow(target_, GW_HWNDPREV);
  UINT flags = kPositionFlags;
  if (hidden_for_target_) flags |= SWP_SHOWWINDOW;
  if (previous == window_) {
    if (!hidden_for_target_) return true;
    flags |= SWP_NOZORDER;
  }
  // Insert immediately above the target, preserving unrelated windows above it.
  else if (previous == nullptr || (!target_topmost && (GetWindowLongPtr(previous, GWL_EXSTYLE) & WS_EX_TOPMOST))) {
    previous = HWND_TOP;
  }
  // Restore visibility and stacking together so the reader cannot flash on top.
  SetWindowPos(window_, previous, 0, 0, 0, 0, flags);
  hidden_for_target_ = false;
  return true;
}
