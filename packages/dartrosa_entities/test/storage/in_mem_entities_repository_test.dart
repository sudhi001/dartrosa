// Port of org.odk.collect.android.entities.InMemEntitiesRepositoryTest.
import 'package:dartrosa_entities/dartrosa_entities.dart';

import '../support/entities_repository_contract.dart';

void main() {
  entitiesRepositoryContract(
    ({clock}) => InMemEntitiesRepository(clock: clock),
  );
}
