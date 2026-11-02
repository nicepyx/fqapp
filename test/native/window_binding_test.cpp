#include "window_binding.h"

#include <iostream>
#include <stdexcept>

namespace {
constexpr UINT kFlags = SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE;

void Require(bool condition, const char* description) {
  if (!condition) throw std::runtime_error(description);
  std::cout << "PASS: " << description << '\n';
}

HWND Create(const wchar_t* title) {
  HWND window = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", title,
      WS_OVERLAPPEDWINDOW, -20000, -20000, 320, 280,
      nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  ShowWindow(window, SW_SHOWNOACTIVATE);
  return window;
}

bool Above(HWND first, HWND second) {
  for (HWND window = GetTopWindow(nullptr); window; window = GetWindow(window, GW_HWNDNEXT)) {
    if (window == first) return true;
    if (window == second) return false;
  }
  return false;
}
}  // namespace

int main() {
  HWND target = Create(L"Binding test target");
  HWND other = Create(L"Binding test other application");
  HWND reader = Create(L"Binding test reader");
  int result = 0;
  try {
    Require(target && other && reader, "real Win32 windows created");
    WindowBinding binding(reader);
    SetWindowPos(reader, HWND_TOPMOST, 0, 0, 0, 0, kFlags);
    SetWindowPos(other, HWND_TOP, 0, 0, 0, 0, kFlags);
    Require(binding.Bind(target), "target binding succeeds");
    Require(GetWindow(target, GW_HWNDPREV) == reader, "reader is immediately above target");
    Require(!(GetWindowLongPtr(reader, GWL_EXSTYLE) & WS_EX_TOPMOST), "normal target removes global topmost");
    Require(Above(other, reader), "other application remains above both windows");

    SetWindowPos(target, HWND_TOP, 0, 0, 0, 0, kFlags);
    binding.Sync();
    Require(GetWindow(target, GW_HWNDPREV) == reader && Above(reader, other), "raising target raises reader with it");
    SetWindowPos(other, HWND_TOP, 0, 0, 0, 0, kFlags);
    binding.Sync();
    Require(Above(other, reader) && Above(reader, target), "switching application covers reader and target");

    RECT original_bounds;
    GetWindowRect(reader, &original_bounds);
    ShowWindow(target, SW_MINIMIZE);
    HWND foreground = GetForegroundWindow();
    binding.Sync();
    Require(!IsWindowVisible(reader) && !IsIconic(reader), "minimizing target hides reader without entering animated minimized state");
    Require(GetForegroundWindow() == foreground, "hiding reader does not change foreground window");
    ShowWindow(target, SW_SHOWNOACTIVATE);
    foreground = GetForegroundWindow();
    binding.Sync();
    RECT restored_bounds;
    GetWindowRect(reader, &restored_bounds);
    Require(!IsIconic(reader) && IsWindowVisible(reader), "restoring target shows reader without minimized state");
    Require(EqualRect(&original_bounds, &restored_bounds), "hiding and showing reader preserves its normal geometry");
    Require(GetWindow(target, GW_HWNDPREV) == reader, "reader is shown at target layer immediately");
    Require(GetForegroundWindow() == foreground, "showing reader does not activate it");

    Require(!binding.Bind(nullptr) && binding.target() == target, "unavailable selection preserves current binding");
    ShowWindow(target, SW_MINIMIZE);
    binding.Sync();
    DestroyWindow(target);
    target = nullptr;
    Require(!binding.Sync() && !binding.target(), "closing target detaches binding");
    Require(IsWindow(reader) && IsWindowVisible(reader) && !IsIconic(reader), "closing target preserves and restores reader");
    Require(binding.Bind(other), "reader can bind another window");
    binding.Detach();
    Require(binding.target() == nullptr && IsWindow(reader), "manual detach preserves reader");
  } catch (const std::exception& error) {
    std::cerr << "FAIL: " << error.what() << '\n';
    result = 1;
  }
  if (target) DestroyWindow(target);
  DestroyWindow(other);
  DestroyWindow(reader);
  return result;
}
