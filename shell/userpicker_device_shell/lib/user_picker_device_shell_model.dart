// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:lib.widgets/modular.dart';

export 'package:lib.widgets/model.dart' show ScopedModel, ScopedModelDescendant;

/// Contains all the relevant data for displaying the list of users and for
/// logging in and creating new users.
class UserPickerDeviceShellModel extends DeviceShellModel {
  List<String> _users;

  bool _isShowingNewUserForm = false;

  /// The list of previously logged in users.
  List<String> get users => _users;

  /// True if the 'new user' form is showing.
  bool get isShowingNewUserForm => _isShowingNewUserForm;

  @override
  void onReady(
    UserProvider userProvider,
    DeviceShellContext deviceShellContext,
  ) {
    super.onReady(userProvider, deviceShellContext);
    _loadUsers();
  }

  /// Refreshes the list of users.
  void refreshUsers() {
    _users = null;
    notifyListeners();
    _loadUsers();
  }

  void _loadUsers() {
    userProvider.previousUsers((List<String> users) {
      _users = new List<String>.unmodifiable(users);
      notifyListeners();
    });
  }

  /// Shows the 'new user' form.
  void showNewUserForm() {
    _isShowingNewUserForm = true;
    notifyListeners();
  }

  /// Hides the 'new user' form.
  void hideNewUserForm() {
    _isShowingNewUserForm = false;
    notifyListeners();
  }
}
