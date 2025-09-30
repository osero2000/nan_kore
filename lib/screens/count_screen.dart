import 'package:flutter/material.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/screens/record_edit_screen.dart';
import 'package:intl/intl.dart';
import 'package:nan_kore/widgets/app_background.dart';
import 'package:nan_kore/widgets/glass_card.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // 音を鳴らす準備
    // ReleaseMode.release にすると、再生が終わったリソースをすぐ解放するから
    // 連打したときに音が重ならず、気持ちいいサウンドになるよ！
    _audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _incrementCount() {
    setState(() {
      _currentCount++;
    });
    // 音を鳴らす！
    _audioPlayer.play(AssetSource('sounds/count_up.mp3'));
  }

  void _finishCounting() async {
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
          // メモは2行まで表示して、超えたら「...」で省略するよ！
          Text(
            widget.lastMemo!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
                child: const Text('完了', style: TextStyle(fontSize: 16)), // 文字を大きくしてボタンを押しやすくする
              ),
            )
          ],
        ),
        // 再びStackを使うよ！Positionedでメモの位置を固定すれば、
        // カウント表示は常に画面中央に配置されるし、UIの重なりも防げる！
        body: Stack(
          children: [
            // カウント表示部分は常に中央に配置
            Center(
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
                        fontSize: 160),
                  ),
                ],
              ),
            ),
            // Positionedでメモカードを画面上部に固定する
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildLastMemoCard(context),
            ),
          ],
        ),
        // SizedBoxで囲んで、好きなサイズを指定しちゃお！
        floatingActionButton: SizedBox(
          width: 200.0,
          height: 200.0,
          child: FloatingActionButton(
            onPressed: _incrementCount,
            // ボタンに合わせてアイコンも大きくするとイイ感じ！
            child: const Icon(Icons.add, size: 60.0),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
