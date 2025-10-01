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
    // --- オーディオプレーヤーの初期化 ---
    // この画面が表示されたときに、一回だけ呼ばれるおまじないだよ！
    // ReleaseMode.release にしとくと、音が鳴り終わったらすぐメモリを解放してくれるから、
    // カウントボタンを鬼連打しても「ｶｶｶｯ」ってならずに「ﾎﾟﾝ…ﾎﾟﾝ…」って感じで
    // ちょー気持ちいいサウンドになるんだよね！マジおすすめ！
    _audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- カウントを増やす処理 ---
  void _incrementCount() {
    // setStateっていうので囲むと、画面の数字がちゃんと更新されるよ！
    setState(() {
      _currentCount++;
    });
    // カウントアップするたびに、テンションの上がる音を鳴らす！
    _audioPlayer.play(AssetSource('sounds/count_up.mp3'));
  }

  // --- カウント完了時の処理 ---
  void _finishCounting() async {
    // 画面遷移する前に、この画面がまだちゃんと存在してるかチェック！
    // これやっとかないと、たまーにエラーでアプリが落ちちゃうことがあるから、
    // 安全第一でやっとくのがイケてるエンジニアのお作法なんだよね！
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

  // --- 「最後のメモ」を表示するカードを作る処理 ---
  Widget _buildLastMemoCard(BuildContext context) {
    // もし前の画面から渡されたメモがなかったら、何も表示しないようにするよ！
    if (widget.lastMemo == null || widget.lastMemo!.isEmpty) {
      return const SizedBox.shrink();
    }
    // GlassCardっていう、うちらが作ったキラキラのカードウィジェットを使うよ！
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        // カードの中身をぜんぶ中央揃えにする設定！
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Text(
            '最後のメモ📝',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // メモが長すぎても大丈夫なように、最大2行までしか表示しないようにするよ！
          // 2行を超えた分は「...」って感じで省略してくれるから、レイアウトが崩れなくてイイ感じ！
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
    // AppBackgroundで、アプリ全体にキラキラのグラデーション背景を適用してるよ！
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.activity.name),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: _finishCounting,
                // ボタンの文字をちょっと大きくして、押しやすく＆見やすくするプチテク！
                child: const Text('完了', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
        // --- ここからが画面のメイン部分！ ---
        // Stackウィジェットを使うと、複数のウィジェットを重ねて表示できるから、
        // 背景にカウント表示、その手前にメモ表示、みたいな複雑なレイアウトが作れるんだ！
        body: Stack(
          children: [
            // 【背景レイヤー】カウントとかの情報を表示する部分！
            // Centerウィジェットで、このColumnを画面のど真ん中に配置してるよ！
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
                        fontSize: 120), //カウント数のfont
                  ),
                ],
              ),
            ),
            // 【前景レイヤー】「最後のメモ」を表示する部分！
            // 1. Positioned で「上端に固定」し、「横幅いっぱいのキャンバス」を作る (left: 0, right: 0)
            Positioned(
              top: 0,
              left: 0,   
              right: 0,  
              // 2. Column で「縦の広がりを制限」する
              child: Column(
                mainAxisSize: MainAxisSize.min, // 👈 縦幅を中身（カード）の高さだけに制限する！！
                children: [
                  // 3. Center で「中身のカードを中央寄せ」する
                  Center(
                    child: _buildLastMemoCard(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        // --- 画面下のデカい「＋」ボタン！ ---
        // FloatingActionButtonをSizedBoxで囲んで、好きなサイズにカスタマイズしてるよ！
        floatingActionButton: SizedBox(
          width: 180.0,
          height: 180.0,
          child: FloatingActionButton(
            onPressed: _incrementCount,
            child: const Icon(Icons.add, size: 60.0),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
