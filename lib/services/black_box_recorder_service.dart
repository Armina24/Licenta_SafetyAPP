import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class BlackBoxRecorderService {
  BlackBoxRecorderService._internal();
  static final BlackBoxRecorderService instance =
      BlackBoxRecorderService._internal();

  static const String _cloudUploadUrl =
      'https://your-backend.com/api/blackbox/upload';
  static const String _recordingsDirName = '.blackbox_recordings';

  late Directory _recordingsDirectory;

  CameraController? _frontCameraController;
  CameraController? _rearCameraController;
  CameraDescription? _frontCamera;
  CameraDescription? _rearCamera;

  bool _isInitialized = false;
  bool _isRecording = false;

  List<File> _capturedSnapshots = [];

  ValueNotifier<BlackBoxRecordingState> recordingState =
      ValueNotifier<BlackBoxRecordingState>(
        BlackBoxRecordingState(
          isRecording: false,
          frontSnapshots: 0,
          rearSnapshots: 0,
          uploadInProgress: false,
        ),
      );

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _recordingsDirectory = Directory('${appDir.path}/$_recordingsDirName');

      if (!_recordingsDirectory.existsSync()) {
        await _recordingsDirectory.create(recursive: true);
      }

      await _initializeCameras();

      _isInitialized = true;
      debugPrint('[BlackBoxRecorder] Service initialized');
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Initialization error: $e');
    }
  }

  Future<void> _initializeCameras() async {
    try {
      final cameras = await availableCameras();

      try {
        _frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } catch (_) {
        _frontCamera = cameras.isNotEmpty ? cameras.first : null;
      }

      try {
        _rearCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
      } catch (_) {
        _rearCamera = cameras.length > 1 ? cameras.last : null;
      }

      debugPrint(
        '[BlackBoxRecorder] Cameras found: ${cameras.length}. Front=${_frontCamera?.name}, Rear=${_rearCamera?.name}',
      );
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Camera initialization error: $e');
    }
  }

  Future<void> startRecording({
    Duration recordingDuration = const Duration(minutes: 5),
    Duration snapshotInterval = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) {
      debugPrint('[BlackBoxRecorder] Service not initialized');
      return;
    }

    if (_isRecording) {
      debugPrint('[BlackBoxRecorder] Already recording');
      return;
    }

    _isRecording = true;
    _capturedSnapshots = [];
    _updateRecordingState(isRecording: true);

    unawaited(
      _captureSnapshots(recordingDuration, snapshotInterval)
          .then((_) async {
            await _cleanupRecording();
            _isRecording = false;
            _updateRecordingState(isRecording: false);

            unawaited(_attemptCloudUpload());
          })
          .catchError((e) {
            debugPrint('[BlackBoxRecorder] Recording error: $e');
            _isRecording = false;
            _updateRecordingState(isRecording: false);
          }),
    );
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    debugPrint('[BlackBoxRecorder] Stopping recording...');
    await _cleanupRecording();
    _isRecording = false;
    _updateRecordingState(isRecording: false);
  }

  Future<void> _captureSnapshots(Duration duration, Duration interval) async {
    final stopTime = DateTime.now().add(duration);
    int frontCount = 0;
    int rearCount = 0;

    final frontAvailable = _frontCamera != null;
    final rearAvailable = _rearCamera != null;

    if (!frontAvailable && !rearAvailable) {
      debugPrint('[BlackBoxRecorder] No cameras available for snapshots');
      return;
    }

    bool captureFrontNext = rearAvailable ? false : true;

    while (DateTime.now().isBefore(stopTime) && _isRecording) {
      final useFront = frontAvailable && (captureFrontNext || !rearAvailable);

      final camera = useFront ? _frontCamera : _rearCamera;
      final label = useFront ? 'front' : 'rear';

      try {
        if (camera != null) {
          final snapshot = await _captureFromCamera(
            camera: camera,
            label: label,
            isFront: useFront,
          );

          if (snapshot != null) {
            _capturedSnapshots.add(snapshot);
            if (useFront) {
              frontCount++;
              debugPrint(
                '[BlackBoxRecorder] Front camera snapshot #$frontCount captured',
              );
            } else {
              rearCount++;
              debugPrint(
                '[BlackBoxRecorder] Rear camera snapshot #$rearCount captured',
              );
            }
          } else {
            debugPrint(
              '[BlackBoxRecorder] ${useFront ? 'Front' : 'Rear'} camera returned null (camera busy or unavailable)',
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[BlackBoxRecorder] ${useFront ? 'Front' : 'Rear'} camera error: $e',
        );
      }

      if (frontAvailable && rearAvailable) {
        captureFrontNext = !captureFrontNext;
      }

      _updateRecordingState(
        frontSnapshots: frontCount,
        rearSnapshots: rearCount,
      );

      await Future.delayed(interval);
    }

    debugPrint(
      '[BlackBoxRecorder] Snapshot capture completed. Front: $frontCount, Rear: $rearCount',
    );
  }

  Future<File?> _captureFromCamera({
    required CameraDescription camera,
    required String label,
    required bool isFront,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File(
        '${_recordingsDirectory.path}/snapshot_${label}_$timestamp.jpg',
      );

      if (isFront && _frontCameraController == null) {
        _frontCameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _frontCameraController!.initialize();
      } else if (!isFront && _rearCameraController == null) {
        _rearCameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _rearCameraController!.initialize();
      }

      final controller = isFront
          ? _frontCameraController
          : _rearCameraController;

      if (controller != null && controller.value.isInitialized) {
        final xFile = await controller.takePicture();
        await xFile.saveTo(outputFile.path);

        debugPrint(
          '[BlackBoxRecorder] Captured $label snapshot: ${outputFile.path}',
        );
        return outputFile;
      }

      return null;
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Camera capture error for $label: $e');
      return null;
    }
  }

  Future<void> _cleanupRecording() async {
    try {
      _isRecording = false;

      await _frontCameraController?.dispose();
      await _rearCameraController?.dispose();

      _frontCameraController = null;
      _rearCameraController = null;

      debugPrint('[BlackBoxRecorder] Cleanup completed');
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Cleanup error: $e');
    }
  }

  Future<void> _attemptCloudUpload() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();

      final noInternet =
          results.isEmpty || results.contains(ConnectivityResult.none);

      if (noInternet) {
        debugPrint(
          '[BlackBoxRecorder] No internet connection. Skipping upload.',
        );
        return;
      }

      _updateRecordingState(uploadInProgress: true);

      final timestamp = DateTime.now().toIso8601String();
      final filesToUpload = [
        ..._capturedSnapshots.where((f) => f.existsSync()),
      ];

      if (filesToUpload.isEmpty) {
        debugPrint('[BlackBoxRecorder] No files to upload');
        _updateRecordingState(uploadInProgress: false);
        return;
      }

      debugPrint(
        '[BlackBoxRecorder] Starting cloud upload of ${filesToUpload.length} files',
      );

      try {
        final request =
            http.MultipartRequest('POST', Uri.parse(_cloudUploadUrl))
              ..fields['timestamp'] = timestamp
              ..fields['deviceId'] = _getDeviceId();

        for (final file in filesToUpload) {
          request.files.add(
            await http.MultipartFile.fromPath('files', file.path),
          );
        }

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('[BlackBoxRecorder] Cloud upload successful');

          for (final file in filesToUpload) {
            try {
              await file.delete();
            } catch (_) {}
          }
          _capturedSnapshots.clear();
        } else {
          debugPrint(
            '[BlackBoxRecorder] Cloud upload failed: ${response.statusCode}',
          );
        }
      } on TimeoutException {
        debugPrint('[BlackBoxRecorder] Cloud upload timeout');
      }

      _updateRecordingState(uploadInProgress: false);
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Upload error: $e');
      _updateRecordingState(uploadInProgress: false);
    }
  }

  String _getDeviceId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _updateRecordingState({
    bool? isRecording,
    int? frontSnapshots,
    int? rearSnapshots,
    bool? uploadInProgress,
  }) {
    final current = recordingState.value;
    recordingState.value = BlackBoxRecordingState(
      isRecording: isRecording ?? current.isRecording,
      frontSnapshots: frontSnapshots ?? current.frontSnapshots,
      rearSnapshots: rearSnapshots ?? current.rearSnapshots,
      uploadInProgress: uploadInProgress ?? current.uploadInProgress,
    );
  }

  String get recordingsDirectoryPath => _recordingsDirectory.path;

  List<File> getRecordedFiles() {
    if (!_recordingsDirectory.existsSync()) return [];
    final files = _recordingsDirectory.listSync().whereType<File>().toList();
    return files;
  }

  Future<void> clearOldRecordings({
    Duration olderThan = const Duration(days: 7),
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(olderThan);
      final files = getRecordedFiles();

      for (final file in files) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffTime)) {
          await file.delete();
          debugPrint('[BlackBoxRecorder] Deleted old file: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('[BlackBoxRecorder] Error clearing old files: $e');
    }
  }

  Future<void> dispose() async {
    await _frontCameraController?.dispose();
    await _rearCameraController?.dispose();
    _isInitialized = false;
  }
}

class BlackBoxRecordingState {
  final bool isRecording;
  final int frontSnapshots;
  final int rearSnapshots;
  final bool uploadInProgress;

  BlackBoxRecordingState({
    required this.isRecording,
    required this.frontSnapshots,
    required this.rearSnapshots,
    required this.uploadInProgress,
  });

  int get totalSnapshots => frontSnapshots + rearSnapshots;

  @override
  String toString() {
    return 'BlackBoxRecordingState(recording=$isRecording, '
        'snapshots=$totalSnapshots, uploading=$uploadInProgress)';
  }
}
