import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;


class YamnetLabels {
  YamnetLabels._(this.indexToLabel, this.categoryToIndices);

  final Map<int, String> indexToLabel;
  final Map<String, List<int>> categoryToIndices;

  static const _assetPath = 'assets/models/yamnet_class_map.csv';

  static const _tipeteKeywords = [
    'Scream',
    'Yell',
    'Shriek',
    'Screech',
  ];

  static const _aglomeratieKeywords = [
    'Crowd',
    'Chatter',
    'Babble',
    'Busy street',
  ];

  static const _spargereKeywords = [
    'Glass',
    'Breaking glass',
    'Smash',
    'Crash',
  ];

  static Future<YamnetLabels> load() async {
    final csvRaw = await rootBundle.loadString(_assetPath);
    final lines = csvRaw.split('\n');

    final Map<int, String> indexToLabel = {};
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _splitCsvLine(line);
      if (parts.length < 3) continue;

      final index = int.tryParse(parts[0]);
      final displayName = parts[2].replaceAll('"', '');
      if (index != null) {
        indexToLabel[index] = displayName;
      }
    }

    final Map<String, List<int>> categoryToIndices = {
      'tipete': _findIndices(indexToLabel, _tipeteKeywords),
      'aglomeratie': _findIndices(indexToLabel, _aglomeratieKeywords),
      'spargere': _findIndices(indexToLabel, _spargereKeywords),
    };

    categoryToIndices.forEach((category, indices) {
      developer.log('Categoria $category -> $indices', name: 'YamnetLabels');
    });

    debugPrint('Yamnet: încărcate ${indexToLabel.length} etichete');
    return YamnetLabels._(indexToLabel, categoryToIndices);
  }

  static List<String> _splitCsvLine(String line) {
    final List<String> parts = [];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if (char == ',' && !inQuotes) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  static List<int> _findIndices(
    Map<int, String> indexToLabel,
    List<String> keywords,
  ) {
    final matches = <int>[];

    indexLoop:
    for (final entry in indexToLabel.entries) {
      for (final keyword in keywords) {
        if (entry.value.toLowerCase().contains(keyword.toLowerCase())) {
          matches.add(entry.key);
          continue indexLoop;
        }
      }
    }

    return matches;
  }
}
 

