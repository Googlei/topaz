// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';

import 'data_handler.dart';

// ignore_for_file: public_member_api_docs

class ActionLogDataHandler extends ActionLogListener with DataHandler {
  @override
  String get name => 'action_log';

  // cache for current context state
  final List<UserAction> _actionLogCache = <UserAction>[];

  // connection to ActionLog
  UserActionLogProxy _actionLog;
  ActionLogListenerBinding _actionLogListener;

  SendWebSocketMessage _sendMessage;

  @override
  void init(StartupContext context, SendWebSocketMessage sender) {
    _sendMessage = sender;

    // Connect to the ActionLog
    _actionLog = new UserActionLogProxy();
    _actionLogListener = new ActionLogListenerBinding();
    connectToService(context.environmentServices, _actionLog.ctrl);
    assert(_actionLog.ctrl.isBound);

    // Subscribe to ActionLog Actions
    _actionLog.subscribe(_actionLogListener.wrap(this));
  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    // /data/action_log/all returns all of the actions in the log
    if (requestString == '/all') {
      request.response.write(json.encode(_actionLogCache));
      request.response.close();
      return true;
    }
    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {
    // send all cached data to the socket
    String message =
        json.encode(<String, dynamic>{'action_log.all': _actionLogCache});
    socket.add(message);
  }

  @override
  void onAction(UserAction action) {
    _actionLogCache.add(action);
    _sendMessage(json.encode(<String, dynamic>{
      'action_log.new_action': <String, String>{
        'componentUrl': action.componentUrl,
        'method': action.method,
        'parameters': action.parameters,
      }
    }));
  }
}
