// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'model.dart';

/// Status enum for [EmbedderModel]
enum EmbedderModelStatus {
  /// ModuleState
  starting,

  /// ModuleState
  running,

  /// ModuleState
  unlinked,

  /// ModuleState
  done,

  /// ModuleState
  stopped,

  /// ModuleState
  error,

  /// resolution status
  resolving,

  /// resolution status
  notFound,
}

/// Abstract .
abstract class EmbedderModel extends Model {
  /// The current status of the Module being embedded.
  EmbedderModelStatus status;

  /// The build method to be used by builders of any
  /// ScopedModelDescendant<EmbedderModel>.
  Widget build(BuildContext context);

  /// Stub for starting a module.
  Future<Null> startModule({
    @required String uri,
    @required String name,
    @required String data,
  }) async {}
}
