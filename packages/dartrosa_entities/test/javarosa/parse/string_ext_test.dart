// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (StringExtTest), Copyright University of Washington,
//  Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.entities.javarosa.parse.StringExtTest.
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

void main() {
  test('#isV4UUID is false for version 1 UUIDs', () {
    expect(isV4Uuid('6b5ea8de-9565-11e8-9eb6-529269fb1459'), isFalse);
  });

  test('#isV4UUID is false for version 2 UUIDs', () {
    expect(isV4Uuid('00000000-0000-2000-8000-000000000000'), isFalse);
  });

  test('#isV4UUID is false for version 3 UUIDs', () {
    // UUID.nameUUIDFromBytes("blah".toByteArray())
    expect(isV4Uuid('6f1ed002-ab5d-3595-859f-1fd5a5ab4d6d'), isFalse);
  });

  test('#isV4UUID is true for version 4 UUIDs', () {
    expect(isV4Uuid('3d9c6b1e-5f1a-4b8e-9c2d-7a6f5e4d3c2b'), isTrue);
  });

  test('#isV4UUID is false for invalid UUID string', () {
    expect(isV4Uuid('not-a-uuid'), isFalse);
    expect(isV4Uuid(null), isFalse);
    expect(isV4Uuid(''), isFalse);
  });

  // Added: Java's UUID.fromString is lenient about group lengths.
  test('#isV4UUID follows Java parsing of short groups', () {
    expect(isV4Uuid('1-1-4000-1-1'), isTrue);
    expect(isV4Uuid('1-1-1-1-1'), isFalse);
    expect(isV4Uuid('1-1-4000-1'), isFalse);
  });

  test('#toUri adds single query param to uri', () {
    expect(
      toUriWithParams('https://example.com', [('id', '123')]).toString(),
      'https://example.com?id=123',
    );
  });

  test('#toUri preserves existing query parameters', () {
    expect(
      toUriWithParams('https://example.com?foo=bar', [
        ('id', '123'),
      ]).toString(),
      'https://example.com?foo=bar&id=123',
    );
  });

  test('#toUri sets null value as query param', () {
    expect(
      toUriWithParams('https://example.com', [('id', null)]).toString(),
      'https://example.com?id=null',
    );
  });

  test('#toUri does not change uri path', () {
    expect(
      toUriWithParams('https://example.com/path/subpath', [
        ('id', '123'),
      ]).toString(),
      'https://example.com/path/subpath?id=123',
    );
  });
}
