import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechProgress {
  final int start;
  final int end;
  SpeechProgress(this.start, this.end);
}

const double kSpeechRateSlow = 0.25;
const double kSpeechRateNormal = 0.35;
const double kSpeechRateFast = 0.5;

abstract class SpeechService {
  Future<bool> speak(String text);
  Future<void> stop();
  Stream<void> get onFinished;
  Stream<SpeechProgress> get onProgress;
  Future<void> setRate(double rate);
}

class FlutterTtsSpeechService implements SpeechService {
  FlutterTts? _tts;
  final _onFinishedController = StreamController<void>.broadcast();
  final _onProgressController = StreamController<SpeechProgress>.broadcast();
  double _currentRate = kSpeechRateNormal;

  @override
  Stream<void> get onFinished => _onFinishedController.stream;

  @override
  Stream<SpeechProgress> get onProgress => _onProgressController.stream;

  Future<void> _initTts() async {
    if (_tts != null) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage('en-US');
    } catch (_) {
      // Ignore failure
    }
    
    try {
      await _tts!.setSpeechRate(_currentRate);
      await _tts!.setPitch(1.0);
      await _tts!.awaitSpeakCompletion(true);
      
      _tts!.setCompletionHandler(() {
        _onFinishedController.add(null);
      });
      _tts!.setErrorHandler((msg) {
        _onFinishedController.add(null);
      });
      _tts!.setProgressHandler((text, start, end, word) {
        _onProgressController.add(SpeechProgress(start, end));
      });
    } catch (_) {
      // Ignore initial setup exceptions
    }
  }

  @override
  Future<void> setRate(double rate) async {
    _currentRate = rate;
    try {
      if (_tts != null) {
        await _tts!.setSpeechRate(rate);
      }
    } catch (_) {}
  }

  @override
  Future<bool> speak(String text) async {
    try {
      await _initTts();
      final result = await _tts!.speak(text);
      if (result == 1) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (_tts != null) {
        await _tts!.stop();
      }
    } catch (_) {}
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterTtsSpeechService();
  ref.onDispose(() {
    service.stop();
  });
  return service;
});
