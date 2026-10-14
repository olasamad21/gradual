import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/services/speech_service.dart';
import 'package:gradual/core/services/read_aloud_text.dart';
import 'package:gradual/features/daily_word/read_aloud_controller.dart';

class FakeSpeechService implements SpeechService {
  final spokenStrings = <String>[];
  double currentRate = kSpeechRateNormal;
  Completer<bool>? nextSpeakCompleter;
  
  final _progressController = StreamController<SpeechProgress>.broadcast();
  final _finishedController = StreamController<void>.broadcast();

  @override
  Stream<SpeechProgress> get onProgress => _progressController.stream;

  @override
  Stream<void> get onFinished => _finishedController.stream;

  void emitProgress(int start, int end) {
    _progressController.add(SpeechProgress(start, end));
  }

  @override
  Future<void> setRate(double rate) async {
    currentRate = rate;
  }

  @override
  Future<bool> speak(String text) async {
    spokenStrings.add(text);
    nextSpeakCompleter = Completer<bool>();
    return nextSpeakCompleter!.future;
  }

  @override
  Future<void> stop() async {
    if (nextSpeakCompleter != null && !nextSpeakCompleter!.isCompleted) {
      nextSpeakCompleter!.complete(true); // Return true when aborted
    }
  }
}

void main() {
  final concept = Concept(
    id: 'test_id',
    term: 'Term',
    category: 'cat',
    level: 'lvl',
    definition: 'Def',
    analogy: 'Ana',
    realWorldExample: '',
    confusedWith: '',
    related: [],
    quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
  );

  test('ReadAloudController logic', () async {
    SharedPreferences.setMockInitialValues({'read_aloud_speed': 1.0});
    final fakeService = FakeSpeechService();
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    // Initial load
    await Future.microtask(() {});
    
    final controller = container.read(readAloudControllerProvider.notifier);
    
    // Toggle
    final toggleFuture = controller.toggle(concept);
    await Future.microtask(() {});
    
    expect(fakeService.spokenStrings, ['Term']);
    expect(container.read(readAloudControllerProvider).section, ReadSectionKind.term);

    // Progress event inside prefix (none for term, so let's emit normal)
    fakeService.emitProgress(0, 4);
    await Future.microtask(() {});
    expect(container.read(readAloudControllerProvider).wordStart, 0);
    expect(container.read(readAloudControllerProvider).wordEnd, 4);

    // Complete term
    fakeService.nextSpeakCompleter!.complete(true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    expect(fakeService.spokenStrings, ['Term', 'Def']);
    expect(container.read(readAloudControllerProvider).section, ReadSectionKind.definition);

    // Progress event past end
    fakeService.emitProgress(10, 15);
    await Future.microtask(() {});
    expect(container.read(readAloudControllerProvider).wordStart, isNull);

    // Complete def
    fakeService.nextSpeakCompleter!.complete(true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    expect(fakeService.spokenStrings, ['Term', 'Def', 'Analogy. Ana']);
    expect(container.read(readAloudControllerProvider).section, ReadSectionKind.analogy);

    // Progress inside prefix
    fakeService.emitProgress(0, 7);
    await Future.microtask(() {});
    expect(container.read(readAloudControllerProvider).wordStart, isNull);

    // Progress in display text
    fakeService.emitProgress(9, 12);
    await Future.microtask(() {});
    expect(container.read(readAloudControllerProvider).wordStart, 0);
    expect(container.read(readAloudControllerProvider).wordEnd, 3);

    // Complete analogy
    fakeService.nextSpeakCompleter!.complete(true);
    
    await toggleFuture;
    expect(container.read(readAloudControllerProvider).conceptId, isNull);
  });

  test('setSpeed restarts current section and chosen speed persists', () async {
    SharedPreferences.setMockInitialValues({'read_aloud_speed': 1.0});
    final fakeService = FakeSpeechService();
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await Future.microtask(() {});
    final controller = container.read(readAloudControllerProvider.notifier);
    
    controller.toggle(concept);
    await Future.microtask(() {});
    
    expect(fakeService.spokenStrings, ['Term']);
    
    await controller.setSpeed(0.75);
    await Future.microtask(() {});
    
    expect(fakeService.currentRate, kSpeechRateSlow);
    expect(container.read(readAloudControllerProvider).speed, 0.75);
    expect(fakeService.spokenStrings.last, 'Term'); // Restarted Term

    // Test persist to next container
    final fakeService2 = FakeSpeechService();
    final container2 = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService2),
      ],
    );
    addTearDown(container2.dispose);

    await Future.delayed(Duration.zero);
    // Force read to trigger initialization
    container2.read(readAloudControllerProvider);
    await Future.delayed(Duration.zero);

    expect(container2.read(readAloudControllerProvider).speed, 0.75);
    expect(fakeService2.currentRate, kSpeechRateSlow);
  });
  
  test('stop prevents later sections, speak returning false goes idle', () async {
    SharedPreferences.setMockInitialValues({'read_aloud_speed': 1.0});
    final fakeService = FakeSpeechService();
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await Future.microtask(() {});
    final controller = container.read(readAloudControllerProvider.notifier);
    
    controller.toggle(concept);
    await Future.microtask(() {});
    
    controller.stop();
    await Future.microtask(() {});
    expect(container.read(readAloudControllerProvider).conceptId, isNull);
    
    final toggle2 = controller.toggle(concept);
    await Future.microtask(() {});
    
    fakeService.nextSpeakCompleter!.complete(false);
    
    final res = await toggle2;
    expect(res, isFalse);
    expect(container.read(readAloudControllerProvider).conceptId, isNull);
  });

  test('toggle with fromBackFace: true starts speaking directly from analogy', () async {
    SharedPreferences.setMockInitialValues({'read_aloud_speed': 1.0});
    final fakeService = FakeSpeechService();
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await Future.microtask(() {});
    final controller = container.read(readAloudControllerProvider.notifier);

    controller.toggle(concept, fromBackFace: true);
    await Future.microtask(() {});

    expect(fakeService.spokenStrings, ['Analogy. Ana']);
    expect(container.read(readAloudControllerProvider).section, ReadSectionKind.analogy);
  });
}
