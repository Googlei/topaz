// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_cobalt/fidl.dart';
import 'package:fidl_fuchsia_netstack/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.device_shell/netstack_model.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';

import 'authentication_context_impl.dart';
import 'user_picker_device_shell_model.dart';
import 'user_picker_device_shell_screen.dart';
import 'user_setup.dart';
import 'user_setup_model.dart';

const double _kMousePointerElevation = 800.0;
const double _kIndicatorElevation = _kMousePointerElevation - 1.0;

const int _kCobaltProjectId = 103;

/// The main device shell widget.
DeviceShellWidget<UserPickerDeviceShellModel> _deviceShellWidget;

void main() {
  setupLogger(name: 'userpicker_device_shell');
  trace('starting');
  StartupContext startupContext = new StartupContext.fromStartupInfo();

  // Connect to Cobalt
  CobaltEncoderProxy encoder = new CobaltEncoderProxy();

  CobaltEncoderFactoryProxy encoderFactory = new CobaltEncoderFactoryProxy();
  connectToService(startupContext.environmentServices, encoderFactory.ctrl);
  encoderFactory.getEncoder(_kCobaltProjectId, encoder.ctrl.request());
  encoderFactory.ctrl.close();

  NetstackProxy netstackProxy = new NetstackProxy();
  connectToService(startupContext.environmentServices, netstackProxy.ctrl);

  NetstackModel netstackModel = new NetstackModel(netstack: netstackProxy)
    ..start();

  UserSetupModel userSetupModel = new UserSetupModel(
      startupContext, netstackModel, _cancelAuthenticationFlow);

  _OverlayModel wifiInfoOverlayModel = new _OverlayModel();

  UserPickerDeviceShellModel userPickerDeviceShellModel =
      new UserPickerDeviceShellModel(
    onDeviceShellStopped: () {
      netstackProxy.ctrl.close();
      netstackModel.dispose();
    },
    onLogin: () {
      wifiInfoOverlayModel.showing = false;
    },
    onWifiTapped: () {
      wifiInfoOverlayModel.showing = !wifiInfoOverlayModel.showing;
    },
    onSetup: userSetupModel.start,
    encoder: encoder,
  );

  Widget mainWidget = new Stack(
    fit: StackFit.passthrough,
    children: <Widget>[
      new UserPickerDeviceShellScreen(
        launcher: startupContext.launcher,
      ),
      new ScopedModel<UserSetupModel>(
          model: userSetupModel, child: const UserSetup()),
    ],
  );

  Widget app = mainWidget;

  List<OverlayEntry> overlays = <OverlayEntry>[
    new OverlayEntry(
      builder: (BuildContext context) => new MediaQuery(
            data: const MediaQueryData(),
            child: new FocusScope(
              node: new FocusScopeNode(),
              autofocus: true,
              child: app,
            ),
          ),
    ),
    new OverlayEntry(
      builder: (BuildContext context) => new ScopedModel<_OverlayModel>(
            model: wifiInfoOverlayModel,
            child: new _WifiInfo(
              wifiWidget: new ApplicationWidget(
                url: 'wifi_settings',
                launcher: startupContext.launcher,
              ),
            ),
          ),
    ),
  ];

  _deviceShellWidget = new DeviceShellWidget<UserPickerDeviceShellModel>(
    startupContext: startupContext,
    deviceShellModel: userPickerDeviceShellModel,
    authenticationContext: new AuthenticationContextImpl(
        onStartOverlay: userSetupModel.authModel.onStartOverlay,
        onStopOverlay: userSetupModel.endAuthFlow),
    child: new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          (constraints.biggest == Size.zero)
              ? const Offstage()
              : new ScopedModel<NetstackModel>(
                  model: netstackModel,
                  child: new Overlay(initialEntries: overlays),
                ),
    ),
  );

  runApp(_deviceShellWidget);

  _deviceShellWidget.advertise();
  trace('started');
}

/// Cancels any ongoing authorization flows in the device shell.
void _cancelAuthenticationFlow() {
  _deviceShellWidget.cancelAuthenticationFlow();
}

class _WifiInfo extends StatelessWidget {
  final Widget wifiWidget;

  const _WifiInfo({@required this.wifiWidget}) : assert(wifiWidget != null);

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<_OverlayModel>(
        builder: (
          BuildContext context,
          Widget child,
          _OverlayModel model,
        ) =>
            new Offstage(
              offstage: !model.showing,
              child: new Stack(
                children: <Widget>[
                  new Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (PointerDownEvent event) {
                      model.showing = false;
                    },
                  ),
                  new Center(
                    child: new FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: new Container(
                        margin: const EdgeInsets.all(8.0),
                        child: new PhysicalModel(
                          color: Colors.grey[900],
                          elevation: _kIndicatorElevation,
                          borderRadius: new BorderRadius.circular(8.0),
                          child: wifiWidget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
}

class _OverlayModel extends Model {
  bool _showing = false;

  set showing(bool showing) {
    if (_showing != showing) {
      _showing = showing;
      notifyListeners();
    }
  }

  bool get showing => _showing;
}
