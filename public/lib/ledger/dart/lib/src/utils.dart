// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show json, utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:collection/collection.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl.dart';
import 'package:quiver/core.dart' as quiver;
import 'package:zircon/zircon.dart' show ZX, ReadResult;

import 'helpers.dart';

// This file defines global functions that are useful for directly manipulating
// Ledger data.

/// Encodes the given value first into a JSON string and then encode in UTF8.
List<int> encodeLedgerValue(Object value) => utf8.encode(json.encode(value));

/// Decodes the given [Buffer] into a Dart Object. This assumes that
/// the data held in the given [Buffer] is encoded in JSON and UTF8.
///
/// This throws an exception when it fails to decode the given data.
dynamic decodeLedgerValue(Buffer value) {
  ReadResult readResult = value.vmo.read(value.size);
  if (readResult.status != ZX.OK) {
    throw new Exception('Unable to read from vmo: ${readResult.status}');
  }
  if (readResult.bytes.lengthInBytes != value.size) {
    throw new Exception('Unexpected count of bytes read.');
  }

  return json.decode(readResult.bytesAsUTF8String());
}

/// Gets the full list of [Entry] objects from a given [PageSnapshot].
///
/// This will continuously call the [PageSnapshot.getEntries] method in case the
/// returned status code is [Status.partialResult].
Future<List<Entry>> getFullEntries(
  PageSnapshot snapshot, {
  List<int> keyPrefix,
}) async {
  List<Entry> entries = <Entry>[];
  await _getFullEntriesRecursively(snapshot, entries, keyPrefix);
  return entries;
}

/// Helper method for the [getFullEntries] method.
Future<Null> _getFullEntriesRecursively(
  PageSnapshot snapshot,
  List<Entry> result,
  List<int> keyPrefix, {
  Token token,
}) async {
  Completer<Status> statusCompleter = new Completer<Status>();
  List<Entry> entries;
  Token nextToken;

  snapshot.getEntries(keyPrefix ?? new Uint8List(0), token,
      (Status status, List<Entry> entriesResult, Token nextTokenResult) {
    entries = entriesResult;
    nextToken = nextTokenResult;
    statusCompleter.complete(status);
  });

  Status status = await statusCompleter.future;

  if (status != Status.ok && status != Status.partialResult) {
    throw new Exception(
      'PageSnapshot::GetEntries() returned an error status: $status',
    );
  }

  result.addAll(entries.takeWhile((entry) => hasPrefix(entry.key, keyPrefix)));

  if (status == Status.partialResult &&
      hasPrefix(entries[entries.length - 1].key, keyPrefix)) {
    await _getFullEntriesRecursively(
      snapshot,
      result,
      keyPrefix,
      token: nextToken,
    );
  }
}

/// Returns a randomly generated id value. Each element in the returned [List]
/// is a byte value, and the length of it will be equal to [lengthInBytes].
List<int> generateRandomId(int lengthInBytes) {
  Random random = new Random(new DateTime.now().millisecondsSinceEpoch);
  Uint8List id = new Uint8List(lengthInBytes);
  for (int i = 0; i < id.lengthInBytes; ++i) {
    id[i] = random.nextInt(256);
  }
  return id;
}

/// Creates a new [Set] of Ledger IDs.
Set<List<int>> createLedgerIdSet() => new HashSet<List<int>>(
      equals: const ListEquality<int>().equals,
      hashCode: quiver.hashObjects,
      isValidKey: (Object key) => key is List<int>,
    );

/// Creates a new [Map] where the key is a Ledger ID.
Map<List<int>, T> createLedgerIdMap<T>() => new HashMap<List<int>, T>(
      equals: const ListEquality<int>().equals,
      hashCode: quiver.hashObjects,
      isValidKey: (Object key) => key is List<int>,
    );
