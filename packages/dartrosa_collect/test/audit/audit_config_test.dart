// Port of Collect's AuditConfigTest.
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

AuditConfig _config(String? mode, String? minInterval, String? maxAge,
        {bool trackChanges = false}) =>
    AuditConfig(
      mode: mode,
      locationMinInterval: minInterval,
      locationMaxAge: maxAge,
      isTrackingChangesEnabled: trackChanges,
    );

void main() {
  test('testParameters', () {
    var auditConfig = _config('high-accuracy', '10', '60', trackChanges: true);
    expect(auditConfig.isTrackingChangesEnabled, isTrue);
    expect(auditConfig.isLocationEnabled, isTrue);
    expect(auditConfig.locationPriority, LocationPriority.highAccuracy);
    expect(auditConfig.locationMinInterval, 10000);
    expect(auditConfig.locationMaxAge, 60000);

    auditConfig = _config('high-accuracy', '0', '60');
    expect(auditConfig.isTrackingChangesEnabled, isFalse);
    expect(auditConfig.isLocationEnabled, isTrue);
    expect(auditConfig.locationPriority, LocationPriority.highAccuracy);
    expect(auditConfig.locationMinInterval, 1000);
    expect(auditConfig.locationMaxAge, 60000);
  });

  test('logLocationCoordinatesOnlyIfAllParametersAreSet', () {
    expect(_config('high-accuracy', '10', '60').isLocationEnabled, isTrue);
    expect(_config(null, '10', '60').isLocationEnabled, isFalse);
    expect(_config(null, null, '60').isLocationEnabled, isFalse);
    expect(_config(null, null, null).isLocationEnabled, isFalse);
    expect(_config('balanced', null, null).isLocationEnabled, isFalse);
    expect(_config('balanced', '10', null).isLocationEnabled, isFalse);
    expect(_config('balanced', null, '60').isLocationEnabled, isFalse);
    expect(_config(null, null, '60').isLocationEnabled, isFalse);
  });

  test('testPriorities', () {
    const expectations = {
      'high_accuracy': LocationPriority.highAccuracy,
      'high-accuracy': LocationPriority.highAccuracy,
      'HIGH_ACCURACY': LocationPriority.highAccuracy,
      'balanced': LocationPriority.balancedPowerAccuracy,
      'BALANCED': LocationPriority.balancedPowerAccuracy,
      'low_power': LocationPriority.lowPower,
      'low-power': LocationPriority.lowPower,
      'low_POWER': LocationPriority.lowPower,
      'no_power': LocationPriority.noPower,
      'no-power': LocationPriority.noPower,
      'NO_power': LocationPriority.noPower,
      'qwerty': LocationPriority.highAccuracy,
      '': LocationPriority.highAccuracy,
    };
    expectations.forEach((mode, priority) {
      expect(_config(mode, null, null).locationPriority, priority,
          reason: mode);
    });
    expect(_config(null, null, null).locationPriority, isNull);
  });

  test('non-integer intervals throw like Long.parseLong', () {
    expect(() => _config('balanced', '1.5', '60'), throwsFormatException);
    expect(() => _config('balanced', '10', ' 60'), throwsFormatException);
  });
}
