// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'conductor.dart';
import 'model.dart';
import 'default_scroll_configuration.dart';
import 'wrapper_builder.dart';

export 'wrapper_builder.dart' show WrapperBuilder;

const Color _kBackgroundOverlayColor = const Color(0xB0000000);
const String _kBackgroundImage = 'packages/armadillo/res/Background.jpg';
const double _kDeviceScreenInnerBezelRadius = 8.0;

/// [Armadillo] is the main Widget.  Its purpose is to set up [Model]s the rest
/// of the Widgets depend upon. It uses the [Conductor] to display the actual UI
/// Widgets.
class Armadillo extends StatelessWidget {
  /// [conductor] will be wrapped by all the [ScopedModel]s returned by these
  /// [scopedModelBuilders].
  final List<WrapperBuilder> scopedModelBuilders;

  /// The main child of [Armadillo].
  final Conductor conductor;

  /// Constructor.
  Armadillo({@required this.scopedModelBuilders, @required this.conductor});

  @override
  Widget build(BuildContext context) {
    Widget currentChild = new DefaultScrollConfiguration(child: conductor);

    scopedModelBuilders.forEach((WrapperBuilder scopedModelBuilder) {
      currentChild = scopedModelBuilder(context, currentChild);
      assert(currentChild is ScopedModel);
    });

    return new Container(
      decoration: new BoxDecoration(
        backgroundColor: Colors.black,
        backgroundImage: new BackgroundImage(
          image: new AssetImage(_kBackgroundImage),
          alignment: new FractionalOffset(0.4, 0.5),
          fit: BoxFit.cover,
          colorFilter: new ui.ColorFilter.mode(
            _kBackgroundOverlayColor,
            ui.BlendMode.srcATop,
          ),
        ),
      ),
      child: currentChild,
    );
  }
}
