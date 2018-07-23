// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'src/dashboard.dart';
import 'src/system_info_model.dart';

void main() => runApp(SystemDashboard());

/// System Dashboard display the following information to the user
///
/// - CPU Utilization
/// - CPU Temperature
/// - Core Frequency & Voltage
/// - Fan Speed

class SystemDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ScopedModel<SystemInfoModel>(
        model: SystemInfoModel(),
        child: Dashboard(),
      ),
    );
  }
}
