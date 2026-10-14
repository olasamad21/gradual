import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/concept_model.dart';
import '../../core/services/speech_service.dart';
import '../../core/services/read_aloud_text.dart';

class ReadAloudState {
  final String? conceptId;
  final ReadSectionKind? section;
  final int? wordStart;
  final int? wordEnd;
  final double speed;

  ReadAloudState({
    this.conceptId,
    this.section,
    this.wordStart,
    this.wordEnd,
    this.speed = 1.0,
  });

  ReadAloudState copyWith({
    String? conceptId,
    ReadSectionKind? section,
    int? wordStart,
    int? wordEnd,
    double? speed,
    bool clearRange = false,
    bool clearConcept = false,
  }) {
    return ReadAloudState(
      conceptId: clearConcept ? null : (conceptId ?? this.conceptId),
      section: clearConcept ? null : (section ?? this.section),
      wordStart: clearRange ? null : (wordStart ?? this.wordStart),
      wordEnd: clearRange ? null : (wordEnd ?? this.wordEnd),
      speed: speed ?? this.speed,
    );
  }
}

class ReadAloudController extends Notifier<ReadAloudState> {
  StreamSubscription<SpeechProgress>? _progressSubscription;
  int _generation = 0;
  Concept? _currentConcept;

  @override
  ReadAloudState build() {
    final speechService = ref.watch(speechServiceProvider);
    
    _progressSubscription = speechService.onProgress.listen((progress) {
      if (state.conceptId == null || state.section == null || _currentConcept == null) return;
      
      final sections = buildReadAloudSections(_currentConcept!);
      final currentSec = sections.firstWhere((s) => s.kind == state.section, orElse: () => ReadSection(kind: ReadSectionKind.term, displayText: '', spokenPrefix: ''));
      
      final range = wordRangeInDisplayed(
        prefixLength: currentSec.spokenPrefix.length,
        start: progress.start,
        end: progress.end,
        displayLength: currentSec.displayText.length,
      );
      
      if (range != null) {
        state = state.copyWith(wordStart: range.start, wordEnd: range.end, clearRange: false);
      } else {
        state = state.copyWith(clearRange: true);
      }
    });

    ref.onDispose(() {
      _progressSubscription?.cancel();
    });

    SharedPreferences.getInstance().then((prefs) {
      final speed = prefs.getDouble('read_aloud_speed') ?? 1.0;
      if (speed != state.speed) {
        state = state.copyWith(speed: speed);
        final rate = speed <= 0.75 ? kSpeechRateSlow : (speed >= 1.25 ? kSpeechRateFast : kSpeechRateNormal);
        speechService.setRate(rate);
      }
    });

    return ReadAloudState();
  }

  void _setIdle() {
    state = ReadAloudState(speed: state.speed);
    _currentConcept = null;
  }

  Future<bool> toggle(Concept concept, {bool fromBackFace = false}) async {
    final speechService = ref.read(speechServiceProvider);

    if (state.conceptId == concept.id) {
      _generation++;
      await speechService.stop();
      _setIdle();
      return true;
    }

    _generation++;
    await speechService.stop();
    _currentConcept = concept;

    int startIndex = 0;
    if (fromBackFace) {
      final sections = buildReadAloudSections(concept);
      final backIdx = sections.indexWhere((s) => s.kind.onBackFace);
      if (backIdx != -1) {
        startIndex = backIdx;
      }
    }
    
    return _speakConcept(concept, startingSectionIndex: startIndex);
  }

  Future<bool> _speakConcept(Concept concept, {required int startingSectionIndex}) async {
    final speechService = ref.read(speechServiceProvider);
    final myGen = _generation;
    final sections = buildReadAloudSections(concept);
    
    state = state.copyWith(conceptId: concept.id, clearRange: true);

    for (int i = startingSectionIndex; i < sections.length; i++) {
      final section = sections[i];
      state = state.copyWith(section: section.kind, clearRange: true);
      
      final success = await speechService.speak(section.spokenPrefix + section.displayText);
      
      if (myGen != _generation) {
        return true; 
      }

      if (!success) {
        _setIdle();
        return false;
      }

      if (i < sections.length - 1) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (myGen != _generation) return true;
      }
    }

    _setIdle();
    return true;
  }

  Future<void> setSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('read_aloud_speed', speed);
    
    state = state.copyWith(speed: speed);
    final rate = speed <= 0.75 ? kSpeechRateSlow : (speed >= 1.25 ? kSpeechRateFast : kSpeechRateNormal);
    
    final speechService = ref.read(speechServiceProvider);
    await speechService.setRate(rate);

    if (state.conceptId != null && state.section != null && _currentConcept != null) {
      _generation++;
      final myGen = _generation;
      await speechService.stop();
      
      if (myGen == _generation) {
        final sections = buildReadAloudSections(_currentConcept!);
        final idx = sections.indexWhere((s) => s.kind == state.section);
        if (idx != -1) {
          _speakConcept(_currentConcept!, startingSectionIndex: idx);
        }
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    final speechService = ref.read(speechServiceProvider);
    await speechService.stop();
    _setIdle();
  }
}

final readAloudControllerProvider = NotifierProvider<ReadAloudController, ReadAloudState>(() {
  return ReadAloudController();
});
