import 'package:flutter/material.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/screens/record_edit_screen.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

class CountScreen extends StatefulWidget {
  final Activity activity;
  final String? lastMemo;
  final int? lastCount;
  final DateTime? lastDate;

  const CountScreen({
    super.key,
    required this.activity,
    this.lastMemo,
    this.lastCount,
    this.lastDate,
  });

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  int _currentCount = 0;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';
  // 連続カウントのために、最後に認識したコマンドの数を覚えておく
  int _lastCommandCount = 0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(onStatus: (status) {
      // `notListening` は聞き取りが止まった時、`done` はタイムアウトなどで完全に終了した時に呼ばれる
      if ((status == 'notListening' || status == 'done') && mounted) {
        if (_isListening) {
          setState(() => _isListening = false);
        }
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _startListening() async {
    _lastCommandCount = 0; // 聞き取り開始時にリセット
    await _speech.listen(
      onResult: (result) {
        final recognized = result.recognizedWords;

        // 認識された言葉を小文字に変換してスペースで区切る
        final words = recognized.toLowerCase().split(' ');
        // 登録コマンドも小文字に変換してSetにすると効率的
        final lowerCaseCommands =
            widget.activity.voiceCommands.map((c) => c.toLowerCase()).toSet();

        int currentCommandCount = 0;
        for (final word in words) {
          if (lowerCaseCommands.contains(word)) {
            currentCommandCount++;
          }
        }

        int diff = 0;
        // 前に数えた数より増えてたら、その差分だけカウントアップ！
        if (currentCommandCount > _lastCommandCount) {
          diff = currentCommandCount - _lastCommandCount;
        }

        // 画面を更新
        if (mounted) {
          setState(() {
            _lastWords = recognized; // 表示する言葉は元のまま
            if (diff > 0) {
              _currentCount += diff;
            }
          });
        }

        // 最後に認識したコマンド数を更新
        _lastCommandCount = currentCommandCount;
      },
      localeId: 'ja_JP',
      listenMode: stt.ListenMode.dictation, // 連続して聞き取るためのモード
    );
    if (mounted) {
      setState(() {
        _isListening = true;
        _lastWords = ''; // 聞き取り開始時に前の言葉をクリア
      });
    }
  }

  void _incrementCount() {
    setState(() {
      _currentCount++;
    });
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    // ユーザーがボタンを押したことを即座にUIに反映させる！
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _finishCounting() async {
    // 他の画面に移動する前に、マイクがONなら必ずOFFにする
    if (_isListening) {
      await _stopListening();
    }
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => RecordEditScreen(
          activity: widget.activity,
          count: _currentCount,
        ),
      ),
    );
  }

  Widget _buildLastMemoCard(BuildContext context) {
    if (widget.lastMemo == null || widget.lastMemo!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最後のメモ📝',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(widget.lastMemo!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.name),
        actions: [
          TextButton(
            onPressed: _finishCounting,
            child: Text(
              '完了',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          )
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          _buildLastMemoCard(context),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.lastDate != null)
                    Text(
                      '前回実施日: ${DateFormat('yyyy/MM/dd(E) HH:mm', 'ja_JP').format(widget.lastDate!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (widget.lastCount != null)
                    Text(
                      '前回の回数: ${widget.lastCount} 回',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  // 前回情報と目標の間にスペースを入れる
                  if (widget.lastDate != null || widget.lastCount != null)
                    const SizedBox(height: 24),
                  Text('目標: ${widget.activity.targetCount} 回',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  Text(
                    '$_currentCount',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // 音声認識のステータスを表示
                  Text(
                    _isListening
                        ? '聞き取り中...'
                        : _speech.isAvailable
                            ? 'マイクボタンを押して話してね！'
                            : '音声認識が使えません',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  // 認識した言葉を表示
                  Container(
                    height: 50, // 高さを確保してガタつきを防ぐ
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.topCenter,
                    child: Text(
                      _lastWords.isNotEmpty
                          ? '「$_lastWords」'
                          : (_isListening ? '...' : ''),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 120), // ボタンのためのスペース
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 手動カウントボタン
            FloatingActionButton.large(
              heroTag: 'manual_increment',
              onPressed: _incrementCount,
              child: const Icon(Icons.add),
            ),
            // 音声認識ボタン
            FloatingActionButton.large(
              heroTag: 'voice_increment',
              onPressed: _isListening ? _stopListening : _startListening,
              backgroundColor: _isListening ? Colors.redAccent : Theme.of(context).colorScheme.secondary,
              child: Icon(_isListening ? Icons.mic_off : Icons.mic),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
