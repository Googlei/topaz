import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.device_shell/user_shell_chooser.dart';
import 'package:lib.ui.flutter/child_view.dart';

import 'user_watcher_impl.dart';

/// Handles adding, removing, and logging, and controlling users.
class DeviceShellUserManager {
  final UserProvider _userProvider;
  final UserShellChooser _userShellChooser;

  UserControllerProxy _userControllerProxy;
  UserWatcherImpl _userWatcherImpl;

  final StreamController<void> _userLogoutController =
      StreamController<void>.broadcast();

  DeviceShellUserManager(this._userProvider, this._userShellChooser);

  Stream<void> get onLogout => _userLogoutController.stream;

  /// Adds a new user, displaying UI as required.
  ///
  /// The UI will be displayed in the space provided to authenticationContext
  /// in the device shell widget.
  Future<String> addUser() {
    final completer = Completer<String>();

    _userProvider.addUser(
      IdentityProvider.google,
      (Account account, String errorCode) {
        if (errorCode == null) {
          completer.complete(account.id);
        } else {
          log.warning('ERROR adding user!  $errorCode');
          completer.completeError(UserLoginException('addUser', errorCode));
        }
      },
    );

    return completer.future;
  }

  /// Logs in the user given by [accountId].
  ///
  /// Takes in [serviceProviderHandle] which gets passed to the user shell.
  /// Returns a handle to the [ViewOwner] that the device shell should use
  /// to open a [ChildViewConnection] to display the user shell.
  InterfaceHandle<ViewOwner> login(String accountId,
      InterfaceHandle<ServiceProvider> serviceProviderHandle) {
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = UserControllerProxy();
    _userWatcherImpl?.close();
    _userWatcherImpl = UserWatcherImpl(onUserLogout: () {
      _userLogoutController.add(null);
    });

    UserShellInfo info = _userShellChooser.currentUserShell;
    final InterfacePair<ViewOwner> viewOwner = InterfacePair<ViewOwner>();
    final UserLoginParams params = UserLoginParams(
      accountId: accountId,
      viewOwner: viewOwner.passRequest(),
      services: serviceProviderHandle,
      userController: _userControllerProxy.ctrl.request(),
      userShellConfig: AppConfig(url: info.name),
    );

    _userProvider.login(params);

    _userControllerProxy.watch(_userWatcherImpl.getHandle());

    return viewOwner.passHandle();
  }

  Future<void> removeUser(String userId) {
    final completer = Completer<void>();

    _userProvider.removeUser(userId, (String errorCode) {
      if (errorCode != null && errorCode != '') {
        completer
            .completeError(UserLoginException('removing $userId', errorCode));
      }
      completer.complete();
    });

    return completer.future;
  }

  /// Gets the list of accounts already logged in.
  Future<Iterable<Account>> getPreviousUsers() {
    final completer = Completer<Iterable<Account>>();

    _userProvider.previousUsers(completer.complete);

    return completer.future;
  }

  void close() {
    _userControllerProxy.ctrl.close();
    _userLogoutController.close();
    _userWatcherImpl.close();
  }

  /// If a user is logged in, set the user shell to the current user shell,
  /// otherwise, do nothing.
  Future<void> setUserShell() {
    final completer = Completer<void>();

    _userControllerProxy?.swapUserShell(
        new AppConfig(url: _userShellChooser.currentUserShell.name),
        completer.complete);
    return completer.future;
  }
}

/// Exception thrown when performing user management operations.
class UserLoginException implements Exception {
  final String errorCode;
  final String operation;

  UserLoginException(this.operation, this.errorCode);

  @override
  String toString() {
    return 'Failed during $operation: $errorCode';
  }
}
