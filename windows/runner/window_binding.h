#ifndef RUNNER_WINDOW_BINDING_H_
#define RUNNER_WINDOW_BINDING_H_

#include <windows.h>
#include <string>
#include <vector>

struct WindowBindingTarget {
  HWND handle;
  std::wstring title;
  std::wstring application;
};

class WindowBinding {
 public:
  explicit WindowBinding(HWND window) : window_(window) {}
  static std::vector<WindowBindingTarget> Enumerate(HWND exclude);
  bool Bind(HWND target);
  void Detach();
  bool Sync();
  HWND target() const { return target_; }

 private:
  HWND window_;
  HWND target_ = nullptr;
  bool hidden_for_target_ = false;
};

#endif
