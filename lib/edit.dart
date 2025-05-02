import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:banglabridge/model.dart';
import 'package:banglabridge/db_helper.dart';
import 'package:flutter/material.dart';

class EditScreen extends StatefulWidget {
  final Note? note;
  const EditScreen({this.note});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _titleFormFieldKey = GlobalKey<FormFieldState>();
  final _contentFormFieldKey = GlobalKey<FormFieldState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final PlayerController _playerController = PlayerController();
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

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedColor = Color(int.parse(widget.note!.color));

      if (widget.note!.audioPath != null &&
          widget.note!.audioPath!.isNotEmpty) {
        _playerController.preparePlayer(
          path: widget.note!.audioPath!,
          shouldExtractWaveform: true,
        );
        _playerController.setFinishMode(finishMode: FinishMode.pause);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _saveNote();
      },
      child: Scaffold(
        backgroundColor: _selectedColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text('Edit Recording'),
          actions: [
            IconButton(
              onPressed: () => _showDeleteNoteDialog(context),
              icon: Icon(Icons.delete, color: Colors.black),
            ),
          ],
        ),
        body: Form(
          child: Column(
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
                padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                child: TextFormField(
                  key: _titleFormFieldKey,
                  controller: _titleController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Title",
                  ),
                  style: TextStyle(fontSize: 22),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter a title";
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    AudioFileWaveforms(
                      playerController: _playerController,
                      size: Size(MediaQuery.of(context).size.width - 40, 70),
                      playerWaveStyle: const PlayerWaveStyle(
                        liveWaveColor: Colors.redAccent,
                        fixedWaveColor: Colors.black26,
                        seekLineColor: Colors.black,
                        scaleFactor: 100,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.play_arrow),
                          onPressed: () {
                            _playerController.startPlayer();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.pause),
                          onPressed: () {
                            _playerController.pausePlayer();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.stop),
                          onPressed: () async {
                            await _playerController.pausePlayer();
                            await _playerController.seekTo(0);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 40,
                  ),
                  child: TextFormField(
                    key: _contentFormFieldKey,
                    controller: _contentController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Type Here..",
                    ),
                    style: TextStyle(fontSize: 18),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please type something in the note";
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    // if both fields are empty, skip
    if (_titleFormFieldKey.currentState!.validate() ||
        _contentFormFieldKey.currentState!.validate()) {
      final note = Note(
        id: widget.note?.id,
        title: _titleController.text,
        content: _contentController.text,
        color: _selectedColor.toARGB32().toString(),
        dateTime: DateTime.now().toString(),
        audioPath: widget.note?.audioPath,
      );

      await _databaseHelper.updateNote(note);
    }
  }

  Future<void> _showDeleteNoteDialog(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Recording',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure to delete this recording?',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent, fontSize: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Delete audio file if it exists
      final path = widget.note?.audioPath;
      if (path != null && path.isNotEmpty) {
        final audioFile = File(path);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      await _databaseHelper.deleteNote(widget.note!.id!);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }
}
