// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import 'document/change.dart';
import 'document/document.dart';
import 'document/document_id.dart';
import 'document/uint8list_ops.dart';
import 'document/values/key_value.dart';
import 'ledger_helpers.dart';
import 'sledge.dart';
import 'storage/document_storage.dart';
import 'storage/schema_storage.dart';

typedef Modification = Future Function();

/// Runs a modification and tracks modified documents in order to write the
/// changes to Ledger.
class Transaction {
  // List of Documents modified during the transaction.
  final Set<Document> _documents = new Set<Document>();
  final Sledge _sledge;
  final ledger.PageProxy _pageProxy;
  final ledger.PageSnapshotProxy _pageSnapshotProxy;

  /// Default constructor.
  Transaction(this._sledge, this._pageProxy,
      LedgerPageSnapshotFactory pageSnapshotFactory)
      : _pageSnapshotProxy = pageSnapshotFactory.newInstance();

  /// Runs [modification].
  Future<bool> saveModification(Modification modification) async {
    // Start Ledger transaction.
    final startTransactionCompleter = new Completer<ledger.Status>();
    _pageProxy.startTransaction(startTransactionCompleter.complete);
    bool startTransactionOk =
        (await startTransactionCompleter.future) == ledger.Status.ok;
    if (!startTransactionOk) {
      return false;
    }

    // Obtain the snapshot.
    // All the read operations in |modification| will read from that snapshot.
    final snapshotCompleter = new Completer<ledger.Status>();
    _pageProxy.getSnapshot(
      _pageSnapshotProxy.ctrl.request(),
      new Uint8List(0),
      null,
      snapshotCompleter.complete,
    );
    bool getSnapshotOk = (await snapshotCompleter.future) == ledger.Status.ok;
    if (!getSnapshotOk) {
      return false;
    }

    // Execute the modifications.
    // The modifications may:
    // - obtain a handle to a document, which would trigger a call to |getDocument|.
    // - modify a document. This would result in |documentWasModified| being called.
    await modification();

    // Iterate through all the documents modified by this transaction and
    // forward the updates (puts and deletes) to Ledger.
    final updateLedgerFutures = <Future<ledger.Status>>[];
    for (final document in _documents) {
      updateLedgerFutures
        ..addAll(saveDocumentToPage(document, _pageProxy))
        ..add(saveSchemaToPage(document.documentId.schema, _pageProxy));
    }

    // Await until all updates have been succesfully executed.
    // If some updates have failed, rollback.
    final List<ledger.Status> statuses = await Future.wait(updateLedgerFutures);
    for (final status in statuses) {
      if (status != ledger.Status.ok) {
        await _rollbackModification();
        return false;
      }
    }

    // Finish the transaction by commiting. If the commit fails, rollback.
    final commitCompleter = new Completer<ledger.Status>();
    _pageProxy.commit(commitCompleter.complete);
    bool commitOk = (await commitCompleter.future) == ledger.Status.ok;
    if (!commitOk) {
      await _rollbackModification();
      return false;
    }

    // Notify the documents that the transaction has been completed.
    _documents
      ..forEach(Document.completeTransaction)
      ..clear();
    return true;
  }

  /// Notification that [document] was modified.
  void documentWasModified(Document document) {
    _documents.add(document);
  }

  /// Returns the document identified with [documentId].
  /// If the document does not exist, a new document is returned.
  Future<Document> getDocument(DocumentId documentId) async {
    final document = new Document(_sledge, documentId);
    Uint8List keyPrefix = documentId.prefix;
    List<KeyValue> kvs =
        await getEntriesFromSnapshotWithPrefix(_pageSnapshotProxy, keyPrefix);

    // Strip the document prefix from the KVs.
    for (int i = 0; i < kvs.length; i++) {
      kvs[i] = new KeyValue(
          getUint8ListSuffix(kvs[i].key, DocumentId.prefixLength),
          kvs[i].value);
    }

    if (kvs.isNotEmpty) {
      final change = new Change(kvs);
      Document.applyChange(document, change);
    }

    return document;
  }

  /// Rollback the documents that were modified during the transaction.
  Future _rollbackModification() async {
    _documents
      ..forEach(Document.rollbackChange)
      ..clear();
    final completer = new Completer<ledger.Status>();
    _pageProxy.rollback(completer.complete);
    bool commitOk = (await completer.future) == ledger.Status.ok;
    if (!commitOk) {
      throw new Exception('Transaction failed. Unable to rollback.');
    }
  }
}
