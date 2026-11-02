#ifndef RUNNER_MINI_READER_WINDOW_H_
#define RUNNER_MINI_READER_WINDOW_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include "window_binding.h"

class MiniReaderWindow {
 public:
  MiniReaderWindow(HWND window, flutter::BinaryMessenger* messenger);
  ~MiniReaderWindow();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam);

 private:
  void Leave();
  void PollCursor();
  void SetHidden(bool hidden);
  void ToggleHidden();
  bool RegisterBossKey(const flutter::EncodableValue* value);
  void SyncBinding();
  void NotifyVisibility();

  HWND window_;
  WindowBinding binding_;
  HWINEVENTHOOK foreground_hook_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool active_ = false;
  bool hotkey_registered_ = false;
  bool hover_hide_ = false;
  bool menu_open_ = false;
  bool hidden_ = false;
  bool reported_hidden_ = false;
  bool boss_hidden_ = false;
  bool reveal_until_enter_ = false;
  bool inside_ = true;
  bool was_layered_ = false;
};

#endif  // RUNNER_MINI_READER_WINDOW_H_
