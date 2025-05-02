// lib/screens/add.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import 'package:banglabridge/model.dart';
import 'package:banglabridge/db_helper.dart';
import 'package:banglabridge/stt_service.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  String? _titleGenerated;
  String? _filePath;
  final _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Color _selectedColor = Color(0xFFE5E5E5); // light grey
  final List<Color> _colors = [
    Color(0xFFE5E5E5), // light grey
    Color(0xFFCCE5FF), // light blue
    Color(0xFFD7F9E9), // pale green
    Color(0xFFFFF9C4), // pale yellow
    Color(0xFFF5E6CC), // beige
    Color(0xFFFFD6D6), // light pink
    Color(0xFFD1C4E9), // pale orange
  ];

  SttServiceResponse? _sttServiceResponse;
  StreamSubscription? _sttStreamSubscription;
  SttService? _sttService;
  var _sttIsVoiceThreshold = SttService.kVadPIsVoiceThreshold;

  // --- ADD ScrollController for VAD ListView ---
  final ScrollController _vadScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<String> getSilerovadModelPath(
    String modelFilenameWithExtension,
  ) async {
    if (kIsWeb) {
      return 'assets/models/sileroVad/$modelFilenameWithExtension';
    }
    final assetCacheDirectory =
        await path_provider.getApplicationSupportDirectory();
    final modelPath = path.join(
      assetCacheDirectory.path,
      modelFilenameWithExtension,
    );

    File file = File(modelPath);
    bool fileExists = await file.exists();
    final fileLength = fileExists ? await file.length() : 0;

    // Do not use path package / path.join for paths.
    // After testing on Windows, it appears that asset paths are _always_ Unix style, i.e.
    // use /, but path.join uses \ on Windows.
    final assetPath =
        'assets/models/sileroVad/${path.basename(modelFilenameWithExtension)}';
    final assetByteData = await rootBundle.load(assetPath);
    final assetLength = assetByteData.lengthInBytes;
    final fileSameSize = fileLength == assetLength;
    if (!fileExists || !fileSameSize) {
      debugPrint(
        'Copying model to $modelPath. Why? Either the file does not exist (${!fileExists}), '
        'or it does exist but is not the same size as the one in the assets '
        'directory. (${!fileSameSize})',
      );
      debugPrint('About to get byte data for $modelPath');

      List<int> bytes = assetByteData.buffer.asUint8List(
        assetByteData.offsetInBytes,
        assetByteData.lengthInBytes,
      );
      debugPrint('About to copy model to $modelPath');
      try {
        if (!fileExists) {
          await file.create(recursive: true);
        }
        await file.writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint('Error writing bytes to $modelPath: $e');
        rethrow;
      }
      debugPrint('Copied model to $modelPath');
    }

    return modelPath;
  }

  Future<String> getWhisperModelPath(String modelFilenameWithExtension) async {
    if (kIsWeb) {
      return 'assets/models/whisper/$modelFilenameWithExtension';
    }
    final assetCacheDirectory =
        await path_provider.getApplicationSupportDirectory();
    final modelPath = path.join(
      assetCacheDirectory.path,
      modelFilenameWithExtension,
    );

    File file = File(modelPath);
    bool fileExists = await file.exists();
    final fileLength = fileExists ? await file.length() : 0;

    // Do not use path package / path.join for paths.
    // After testing on Windows, it appears that asset paths are _always_ Unix style, i.e.
    // use /, but path.join uses \ on Windows.
    final assetPath =
        'assets/models/whisper/${path.basename(modelFilenameWithExtension)}';
    final assetByteData = await rootBundle.load(assetPath);
    final assetLength = assetByteData.lengthInBytes;
    final fileSameSize = fileLength == assetLength;
    if (!fileExists || !fileSameSize) {
      debugPrint(
        'Copying model to $modelPath. Why? Either the file does not exist (${!fileExists}), '
        'or it does exist but is not the same size as the one in the assets '
        'directory. (${!fileSameSize})',
      );
      debugPrint('About to get byte data for $modelPath');

      List<int> bytes = assetByteData.buffer.asUint8List(
        assetByteData.offsetInBytes,
        assetByteData.lengthInBytes,
      );
      debugPrint('About to copy model to $modelPath');
      try {
        if (!fileExists) {
          await file.create(recursive: true);
        }
        await file.writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint('Error writing bytes to $modelPath: $e');
        rethrow;
      }
      debugPrint('Copied model to $modelPath');
    }

    return modelPath;
  }

  Future<void> _startRecording() async {
    final vadModelPath = await getSilerovadModelPath('silero_vad.onnx');
    final whisperModelPath = await getWhisperModelPath('whisper_base-bn.onnx');
    final service = SttService(
      vadModelPath: vadModelPath,
      whisperModelPath: whisperModelPath,
      voiceThreshold: _sttIsVoiceThreshold,
      maxDuration: const Duration(seconds: 10),
    );
    _sttService = service;
    final subscription = service.transcribe().listen((event) {
      if (mounted) {
        setState(() {
          _sttServiceResponse = event;
          // updates with the latest transcription text
          _contentController.text = _sttServiceResponse!.transcription;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

          // vad scrolls
          if (_vadScrollController.hasClients) {
            _vadScrollController.animateTo(
              _vadScrollController.position.maxScrollExtent,
              duration: const Duration(
                milliseconds: 100,
              ), // Adjust duration for smoothness
              curve: Curves.linear, // Use linear for constant slide speed feel
            );
          }
        });
      }
    });
    _sttStreamSubscription = subscription;
    subscription.onDone(() async {
      // stop recording and save
      if (!mounted) return;
      // updates with the latest transcription text
      _contentController.text = _sttServiceResponse!.transcription;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      // timestamp
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

      _titleGenerated = 'rec_$timestamp';

      // get audio from service and save wav file
      final dir = await path_provider.getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/rec_$timestamp.wav';
      final wav = _sttService!.getWavBytes();
      await File(_filePath!).writeAsBytes(wav, flush: true);

      setState(() {
        _sttStreamSubscription?.cancel();
        _sttStreamSubscription = null;
        _sttService?.stop();
        _sttService = null;
      });

      // db insert
      final note = Note(
        title: _titleGenerated!,
        content: _contentController.text,
        color: _selectedColor.toARGB32().toString(),
        dateTime: DateTime.now().toString(),
        audioPath: _filePath,
      );

      await _databaseHelper.insertNote(note);

      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastVoiceFrameIndex = _sttServiceResponse?.audioFrames.lastIndexWhere(
      (element) {
        final threshold = element?.vadP;
        if (threshold == null) {
          return false;
        }
        return threshold > _sttIsVoiceThreshold;
      },
    );
    return PopScope(
      canPop: (_sttService == null),
      onPopInvokedWithResult: (didPop, result) async {
        if (_sttService != null) {
          _sttService?.stop();
        }
      },
      child: Scaffold(
        backgroundColor: _selectedColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text('New Recording'),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              width: double.infinity,
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _colors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        height: 34,
                        width: 34,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? Colors.white
                                : Colors.transparent,
                            width: 6,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 40,
              ),
              child: TextField(
                readOnly: true,
                controller: _contentController,
                scrollController: _scrollController,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _sttService == null
                      ? 'Start Recording'
                      : 'Transcribing..',
                ),
                style: TextStyle(fontSize: 18),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (lastVoiceFrameIndex != null &&
                    lastVoiceFrameIndex >= 0) ...[
                  Text(
                    _formatMs(lastVoiceFrameIndex * SttService.kMaxVadFrameMs),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
                  ),
                ] else ...[
                  Text(
                    '00:00:000',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            if (_sttService != null && _sttService!.stopped) ...[
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.black),
                    SizedBox(height: 12),
                    Text(
                      "Finalizing Transcription...",
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ] else if (_sttServiceResponse != null) ...[
              SizedBox(
                height: 80,
                width: MediaQuery.of(context).size.width - 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: ClipRRect(
                    // Ensure children are clipped to the bounds
                    borderRadius: BorderRadius.circular(4),
                    child: ListView.builder(
                      controller: _vadScrollController, // Assign controller
                      scrollDirection: Axis.horizontal, // Set direction
                      itemCount: _sttServiceResponse?.audioFrames.length ?? 0,
                      // Provide an estimated item extent for performance optimization
                      // Calculate based on fixed width + margin
                      // itemExtent: 3.0 + 1.0, // width + horizontal margin
                      addAutomaticKeepAlives: false, // Optimization
                      addRepaintBoundaries: false, // Optimization
                      itemBuilder: (context, index) {
                        final frame = _sttServiceResponse?.audioFrames[index];
                        final Color color;
                        double heightFactor = 0.05; // Minimum height

                        if (frame?.vadP == null) {
                          color = Colors.grey.shade300;
                        } else {
                          heightFactor = frame!.vadP!;
                          if (frame.vadP! > _sttIsVoiceThreshold) {
                            color = Colors.redAccent; // Slightly lighter?
                          } else {
                            color = Colors.black; // Slightly lighter?
                          }
                        }
                        heightFactor = heightFactor.clamp(
                          0.05,
                          1.0,
                        ); // Ensure min/max height

                        // --- Bar Widget ---
                        return Align(
                          // Align bar to bottom
                          alignment: Alignment.center,
                          child: Container(
                            width: 4.0, // *** FIXED WIDTH for each bar ***
                            height: (80 - 10) *
                                heightFactor, // Calculate height based on parent SizedBox height minus padding
                            color: color,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ), // Spacing between bars
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: (_sttService != null && _sttService!.stopped)
            ? null
            : FloatingActionButton(
                onPressed: () async {
                  if (_sttService == null) {
                    await _startRecording();
                  } else {
                    _sttService?.stop();
                  }
                },
                backgroundColor:
                    _sttService == null ? Colors.redAccent : Colors.white,
                child: Icon(
                  _sttService == null
                      ? Icons.radio_button_checked
                      : Icons.stop_circle,
                  color: _sttService == null ? Colors.white : Colors.black,
                  size: 40,
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  String _formatMs(int durationInt) {
    final duration = Duration(milliseconds: durationInt);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds =
        duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds:$milliseconds';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
