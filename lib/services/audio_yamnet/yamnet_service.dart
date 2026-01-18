import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:safety_app/services/audio_yamnet/yamnet_labels.dart';

class SoundAlertResult {
  const SoundAlertResult({
    required this.tipeteScore,
    required this.aglomeratieScore,
    required this.spargereScore,
    required this.isScream,
    required this.isCrowd,
    required this.isGlass,
  });

  final double tipeteScore;
  final double aglomeratieScore;
  final double spargereScore;

  final bool isScream;
  final bool isCrowd;
  final bool isGlass;

  bool get hasAlert => isScream || isCrowd || isGlass;
}

class YamnetService {
  YamnetService._internal();

  static final YamnetService instance = YamnetService._internal();

  Interpreter? _interpreter;
  YamnetLabels? _labels;
  bool _initialized = false;

  List<int> _inputShape = const [];
  List<int> _outputShape = const [];

  int screamCounter = 0;
  int crowdCounter = 0;
  int glassCounter = 0;

  Future<void> init() async {
    if (_initialized) return;

    _interpreter = await Interpreter.fromAsset('assets/models/1.tflite');
    _interpreter!.allocateTensors();

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    _inputShape = List<int>.from(inputTensor.shape);
    _outputShape = List<int>.from(outputTensor.shape);

    debugPrint('YAMNet input shape: $_inputShape');
    debugPrint('YAMNet output shape: $_outputShape');

    _labels = await YamnetLabels.load();

    _initialized = true;
  }

  int get _requiredSamples => _inputShape.isEmpty ? 15600 : _inputShape.last;

  Future<Map<String, double>> classify(List<double> audioSamples) async {
    if (!_initialized) {
      throw StateError('YamnetService not initialized. Call init() first.');
    }

    final interpreter = _interpreter!;
    final Float32List inputBuffer = Float32List(_requiredSamples);
    final int copyLen = min(audioSamples.length, _requiredSamples);

    for (int i = 0; i < copyLen; i++) {
      inputBuffer[i] = audioSamples[i];
    }

    final Object modelInput =
        _inputShape.length == 1 ? inputBuffer : [inputBuffer];

    final int numClasses = _outputShape.isEmpty ? 521 : _outputShape.last;
    final List<List<double>> modelOutput = [
      List<double>.filled(numClasses, 0.0),
    ];

    interpreter.run(modelInput, modelOutput);
    final scores = modelOutput[0];

    double maxScore = -1.0;
    int maxIndex = -1;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    debugPrint(
      "YAMNet: maxScore=$maxScore | index=$maxIndex | label=${_labels?.indexToLabel[maxIndex]}",
    );

    return _aggregateCategoryScores(scores);
  }

  Future<SoundAlertResult> analyzeFrame(List<double> audioSamples) async {
    final categoryScores = await classify(audioSamples);
    final tipeteScore = categoryScores['tipete'] ?? 0.0;
    final aglomeratieScore = categoryScores['aglomeratie'] ?? 0.0;
    final spargereScore = categoryScores['spargere'] ?? 0.0;

    final bool screamHit = tipeteScore > 0.6;
    final bool crowdHit = aglomeratieScore > 0.6;
    final bool glassHit = spargereScore > 0.7;

    screamCounter = screamHit ? screamCounter + 1 : 0;
    crowdCounter = crowdHit ? crowdCounter + 1 : 0;
    glassCounter = glassHit ? glassCounter + 1 : 0;

    final bool isScream = screamCounter >= 3;
    final bool isCrowd = crowdCounter >= 3;
    final bool isGlass = glassCounter >= 1;

    if (isGlass) {
      glassCounter = 0;
    }

    return SoundAlertResult(
      tipeteScore: tipeteScore,
      aglomeratieScore: aglomeratieScore,
      spargereScore: spargereScore,
      isScream: isScream,
      isCrowd: isCrowd,
      isGlass: isGlass,
    );
  }

  Map<String, double> _aggregateCategoryScores(List<double> scores) {
    final labels = _labels;
    if (labels == null) {
      return const {
        'tipete': 0.0,
        'aglomeratie': 0.0,
        'spargere': 0.0,
      };
    }

    final Map<String, double> categoryScores = {};
    labels.categoryToIndices.forEach((category, indices) {
      double maxScore = 0.0;
      for (final index in indices) {
        if (index >= 0 && index < scores.length) {
          maxScore = max(maxScore, scores[index]);
        }
      }
      categoryScores[category] = maxScore;
    });
    return categoryScores;
  }
}
 

