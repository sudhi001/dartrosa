// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (InMemEntitiesRepositoryTest), Copyright University
//  of Washington, Nafundi and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of org.odk.collect.android.entities.InMemEntitiesRepositoryTest.
import 'package:dartrosa_entities/dartrosa_entities.dart';

import '../support/entities_repository_contract.dart';

void main() {
  entitiesRepositoryContract(
    ({clock}) => InMemEntitiesRepository(clock: clock),
  );
}
