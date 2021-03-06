// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl.dart';
import 'package:lib.ledger.dart/ledger.dart';
import 'package:zircon/zircon.dart' show ZX, ReadResult;

import 'document/change.dart';
import 'document/values/key_value.dart';

// ignore_for_file: one_member_abstracts
/// Factory that creates PageSnapshotProxies.
abstract class LedgerPageSnapshotFactory {
  /// Returns a new PageSnapshotProxy.
  ledger.PageSnapshotProxy newInstance();
}

/// Real implementation of LedgerPageSnapshotFactory.
class LedgerPageSnapshotFactoryImpl implements LedgerPageSnapshotFactory {
  @override
  ledger.PageSnapshotProxy newInstance() {
    return new ledger.PageSnapshotProxy();
  }
}

/// Returns data stored in [buffer].
Uint8List readBuffer(Buffer buffer) {
  ReadResult readResult = buffer.vmo.read(buffer.size);
  if (readResult.status != ZX.OK) {
    throw new Exception('Unable to read from vmo: ${readResult.status}');
  }
  if (readResult.bytes.lengthInBytes != buffer.size) {
    throw new Exception('Unexpected count of bytes read.');
  }
  return new Uint8List.view(readResult.bytes.buffer);
}

/// Returns all the KV pairs stored in [pageSnapshotProxy] whose key start
/// with [keyPrefix].
/// The KV are ordered by key in ascending order.
Future<List<KeyValue>> getEntriesFromSnapshotWithPrefix(
    ledger.PageSnapshotProxy pageSnapshotProxy, Uint8List keyPrefix) async {
  final keyValues = <KeyValue>[];
  List<ledger.Entry> entries =
      await getFullEntries(pageSnapshotProxy, keyPrefix: keyPrefix);
  for (final entry in entries) {
    Uint8List k = entry.key;
    Uint8List v = readBuffer(entry.value);
    keyValues.add(new KeyValue(k, v));
  }
  print('Successfully read ${keyValues.length} entries');
  return keyValues;
}

/// Returns Change with the same content as a pageChange.
Change getChangeFromPageChange(ledger.PageChange pageChange) {
  return new Change(
      pageChange.changedEntries
          .map((ledger.Entry entry) =>
              new KeyValue(entry.key, readBuffer(entry.value)))
          .toList(),
      pageChange.deletedKeys);
}
