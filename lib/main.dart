import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/record.dart';
import 'package:nan_kore/models/tag.dart';
import 'package:nan_kore/screens/activity_edit_screen.dart';
import 'package:nan_kore/screens/count_screen.dart';
import 'package:nan_kore/screens/stats_screen.dart';
import 'package:nan_kore/widgets/app_background.dart';
import 'package:nan_kore/widgets/glass_card.dart';
import 'package:intl/date_symbol_data_local.dart';

// カタカナをひらがなに変換するヘルパー関数
String _toHiragana(String text) {
  return text.split('').map((char) {
    final code = char.codeUnitAt(0);
    // カタカナの範囲 (U+30A1 to U+30F6)
    if (code >= 0x30A1 && code <= 0x30F6) {
      return String.fromCharCode(code - 0x60);
    }
    return char;
  }).join('');
}

Future<void> main() async {
  // Flutterの初期化を待つ！これ大事！
  WidgetsFlutterBinding.ensureInitialized();

  // Hive（データベース）の初期化
  await Hive.initFlutter();

  // うちらが作った設計図（Adapter）をHiveに教えてあげる
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(ActivityAdapter());
  Hive.registerAdapter(RecordAdapter());

  // データを保存する箱（Box）を開ける
  await Hive.openBox<Activity>('activities');
  await Hive.openBox<Tag>('tags');
  await Hive.openBox<Record>('records');

  // intlパッケージの日本語ロケールを初期化
  await initializeDateFormatting('ja_JP', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'なんでもカウンター',
      debugShowCheckedModeBanner: false, // これで右上の"DEBUG"が消えるよん！
      theme: ThemeData(
        brightness: Brightness.light, // 明るいテーマでかわいい雰囲気に！
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue, // 白っぽい水色をベースに
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent, // Scaffoldを透明にして背景が見えるように
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // AppBarも透明に
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// とりあえずのホーム画面！これからガチで作り込んでくよ！
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<Tag> _selectedFilterTags = {};
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      // 全体にグラデーション背景を適用
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ダッシュボード'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart, size: 40.0), // アイコンサイズを大きくする
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const StatsScreen()));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 検索とフィルタリングのUI
            GlassCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'アクティビティ名で検索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ) : null,
                    border: InputBorder.none, // GlassCardに馴染むように枠線を消す
                  ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<Box<Tag>>(
                    valueListenable: Hive.box<Tag>('tags').listenable(),
                    builder: (context, box, _) {
                      final allTags = box.values.toList();
                      if (allTags.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Wrap(
                        spacing: 8.0,
                        children: allTags.map((tag) {
                          final isSelected = _selectedFilterTags.any(
                              (selected) => selected.key == tag.key);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedFilterTags.add(tag);
                                } else {
                                  _selectedFilterTags
                                      .removeWhere((t) => t.key == tag.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            // アクティビティリスト
            Expanded(
              child: ValueListenableBuilder<Box<Activity>>(
                valueListenable: Hive.box<Activity>('activities').listenable(),
                builder: (context, box, _) {
                  final allActivities = box.values.toList().cast<Activity>();

                  // フィルタリングロジック
                  final filteredActivities = allActivities.where((activity) {
                    // 1. 名前での検索
                    final hiraganaQuery =
                        _toHiragana(_searchQuery.toLowerCase());
                    final hiraganaActivityName =
                        _toHiragana(activity.name.toLowerCase());
                    final nameMatch =
                        hiraganaActivityName.contains(hiraganaQuery);

                    // 2. タグでの絞り込み
                    final tagMatch = _selectedFilterTags.isEmpty ||
                        _selectedFilterTags.every((filterTag) => activity.tags
                            .any((activityTag) =>
                                activityTag.key == filterTag.key));

                    return nameMatch && tagMatch;
                  }).toList();

                  if (filteredActivities.isEmpty) {
                    // 登録済みアクティビティが0件の場合と、フィルタ結果が0件の場合でメッセージを出し分ける
                    if (allActivities.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            '右下の＋ボタンから、最初のアクティビティを登録してみよう！💪✨',
                            style: TextStyle(fontSize: 24),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          '条件に合うアクティビティが見つからないみたい…🤔',
                          style: TextStyle(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90), // FABと被らないように
                    itemCount: filteredActivities.length,
                    itemBuilder: (ctx, index) {
                      final activity = filteredActivities[index];
                      return Dismissible(
                        key: ValueKey(activity.key), // それぞれの項目を区別するための鍵！
                        direction: DismissDirection
                            .endToStart, // 右から左へのスワイプだけ許可
                        onDismissed: (direction) async {
                          // 0. 削除するデータをコピーして一時的に保存
                          final activityToDelete = activity;
                          final activityName = activityToDelete.name;

                          // 関連レコードのコピーを作成
                          final recordsBox = Hive.box<Record>('records');
                          final relatedRecords = recordsBox.values
                              .where((record) =>
                                  record.activityId == activityToDelete.id)
                              .toList();

                          // 1. データを削除
                          final recordKeysToDelete = relatedRecords
                              .map((rec) => rec.key as int)
                              .toList();
                          await recordsBox.deleteAll(recordKeysToDelete);
                          await activityToDelete.delete();

                          // SnackBarで使うcontextを、非同期処理の前に変数に保存しておくのが安全！
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          // 2. 元に戻すオプション付きのSnackBarを表示
                          // 非同期処理の後にcontextを使うときは、mountedチェックを入れるのがお作法！
                          if (!mounted) return;
                          scaffoldMessenger.removeCurrentSnackBar();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('$activityName を削除しました'),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: '元に戻す',
                                onPressed: () async {
                                  // データを復元
                                  final activitiesBox =
                                      Hive.box<Activity>('activities');
                                  // copyWith を使わない単純な再追加でOK
                                  // (delete()はオブジェクトをメモリから消すわけではないため)
                                  await activitiesBox.add(activityToDelete);
                                  await recordsBox.addAll(relatedRecords);
                                  // ここではmountedチェックは不要！
                                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('$activityName を元に戻しました')));
                                },
                              ),
                            ),
                          );
                        },
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(204),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        child: GlassCard(
                          onTap: () {
                            // 最後に記録されたメモを探す
                            final recordsBox = Hive.box<Record>('records');
                            final activityRecords = recordsBox.values
                                .where((record) =>
                                    record.activityId == activity.id)
                                .toList();
                            activityRecords.sort((a, b) => b.date
                                .compareTo(a.date)); // 新しい順に並び替え

                            int? lastCount;
                            DateTime? lastDate;
                            if (activityRecords.isNotEmpty) {
                              // 一番新しい記録がリストの最初に来る
                              lastCount = activityRecords.first.count;
                              lastDate = activityRecords.first.date;
                            }

                            String? lastMemo;
                            // 空じゃないメモが見つかるまで探す！
                            for (final record in activityRecords) {
                              if (record.memo != null &&
                                  record.memo!.isNotEmpty) {
                                lastMemo = record.memo;
                                break;
                              }
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => CountScreen(
                                  activity: activity,
                                  lastCount: lastCount,
                                  lastDate: lastDate,
                                  lastMemo: lastMemo,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activity.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    Text(
                                        '目標: ${activity.targetCount} 回',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    if (activity.tags.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6.0,
                                        runSpacing: 4.0,
                                        children: activity.tags.map((tag) {
                                          return Chip(
                                            label: Text(tag.name,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            backgroundColor: Color(tag.colorValue)
                                                .withAlpha(51),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4.0),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ActivityEditScreen(
                                          activity: activity),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const ActivityEditScreen(),
              ),
            );
          },
          tooltip: 'アクティビティを追加',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
