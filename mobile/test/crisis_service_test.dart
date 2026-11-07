import 'package:test/test.dart';
import '../lib/core/safety/crisis_service.dart';

void main() {
  group('CrisisService Tests', () {
    test('containsCrisisMarkers detects overt distress phrases', () {
      expect(CrisisService.containsCrisisMarkers('I really want to kill myself tonight'), isTrue);
      expect(CrisisService.containsCrisisMarkers('I want to die, nothing matters'), isTrue);
      expect(CrisisService.containsCrisisMarkers('I feel like I want to end my life'), isTrue);
    });

    test('containsCrisisMarkers returns false for benign stressful reflections', () {
      expect(CrisisService.containsCrisisMarkers('I had a stressful deadline today at work'), isFalse);
      expect(CrisisService.containsCrisisMarkers('My sleep was terrible last night'), isFalse);
      expect(CrisisService.containsCrisisMarkers(''), isFalse);
    });

    test('helplines list includes Tele-MANAS and KIRAN', () {
      final numbers = CrisisService.helplines.map((h) => h.phoneNumber).toList();
      expect(numbers, contains('14416'));
      expect(numbers, contains('1800-599-0019'));
    });
  });
}

