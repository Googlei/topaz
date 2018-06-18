// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>

#include "topaz/runtime/web_runner_prototype/runner.h"

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigMakeDefault);
  web::Runner runner(fuchsia::sys::StartupContext::CreateFromStartupInfo());
  loop.Run();
  return 0;
}