import 'package:flutter/material.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/screens/record_edit_screen.dart';
import 'package:intl/intl.dart';
import 'package:nan_kore/widgets/app_background.dart';
import 'package:nan_kore/widgets/glass_card.dart';
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
  Timer? _refreshTimer;
  bool _shouldRestart = false;
  Timer? _clearTextTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _shouldRestart = false;
    _refreshTimer?.cancel(); // タイマーをキャンセル
    _clearTextTimer?.cancel(); // テキストクリア用のタイマーもキャンセル
    _speech.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(onStatus: (status) {
      // `notListening` は聞き取りが止まった時、`done` はタイムアウトなどで完全に終了した時に呼ばれる
      if ((status == 'notListening' || status == 'done') && mounted) {
        final wasListening = _isListening;
        // 再起動が予定されている場合は、UIを「停止」状態にせず、すぐに再開する
        if (_shouldRestart && wasListening) {
          _shouldRestart = false;
          _startListening();
        } else if (wasListening) {
          // ユーザーによる手動停止など、予期せぬ停止の場合のみUIを更新
          setState(() => _isListening = false);
        }
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _startListening() async {
    _refreshTimer?.cancel(); // 念のため既存のタイマーをキャンセル
    _clearTextTimer?.cancel();
    _lastCommandCount = 0; // 聞き取り開始時にリセット
    await _speech.listen(
      onResult: (result) {
        final recognized = result.recognizedWords;
        
        // 認識された言葉を小文字に変換して、コマンドで区切ることで数を数える
        var tempText = recognized.toLowerCase();
        final lowerCaseCommands =
            widget.activity.voiceCommands.map((c) => c.toLowerCase());

        int currentCommandCount = 0;
        for (final command in lowerCaseCommands) {
          if (command.isEmpty) continue;
          // コマンドで文字列を分割し、その数-1がコマンドの出現回数になる
          currentCommandCount += tempText.split(command).length - 1;
          // カウントした部分はもう数えないように、適当な文字で埋める
          tempText = tempText.replaceAll(command, ' ');
        }

        int diff = 0;
        // 前に数えた数より増えてたら、その差分だけカウントアップ！
        if (currentCommandCount > _lastCommandCount) {
          diff = currentCommandCount - _lastCommandCount;
        }

        // 画面を更新
        if (mounted) {
          _clearTextTimer?.cancel();
          setState(() {
            _lastWords = recognized; // 表示する言葉は元のまま
            if (diff > 0) {
              _currentCount += diff;
            }
          });
        }

        // 最後に認識したコマンド数を更新
        if (mounted) _lastCommandCount = currentCommandCount;

        // 2単語以上認識したら、セッションをリフレッシュして精度を保つ
        if (currentCommandCount >= 2 && _isListening && mounted) {
          _shouldRestart = true;
          _speech.stop();
        }
      },
      localeId: 'ja_JP',
      listenMode: stt.ListenMode.dictation, // 連続して聞き取るためのモード
      partialResults: true, // 途中結果も取得する
    );
    if (mounted) {
      setState(() {
        _isListening = true;
        _lastWords = ''; // 聞き取り開始時に前の言葉をクリア
      });
    }

    // 10分後にリスニングをリフレッシュするタイマーを開始
    _refreshTimer = Timer(const Duration(minutes: 10), () {
      if (_isListening && mounted) {
        // リスニングを再起動して、認識精度が落ちるのを防ぐ
        _shouldRestart = true;
        _speech.stop();
      }
    });
  }

  void _incrementCount() {
    setState(() {
      _currentCount++;
    });
  }

  Future<void> _stopListening() async {
    _shouldRestart = false; // 手動停止なので再起動しない
    _refreshTimer?.cancel(); // 手動で停止した場合、タイマーもキャンセル
    _clearTextTimer?.cancel();
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
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.activity.name),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: _finishCounting,
                child: const Text('完了'),
              ),
            )
          ],
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
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
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
                            ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                backgroundColor: _isListening
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.secondary,
                child: Icon(_isListening ? Icons.mic_off : Icons.mic),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
