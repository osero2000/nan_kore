import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/record.dart';
import 'package:nan_kore/models/tag.dart';
import 'package:nan_kore/screens/activity_edit_screen.dart';
import 'package:nan_kore/screens/count_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('ダッシュボード'),
      ),
      body: ValueListenableBuilder<Box<Activity>>(
        valueListenable: Hive.box<Activity>('activities').listenable(),
        builder: (context, box, _) {
          final activities = box.values.toList().cast<Activity>();
          if (activities.isEmpty) {
            return const Center(
              child: Text('右下の＋ボタンから最初のアクティビティを追加しよう！✨'),
            );
          }
          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (ctx, index) {
              final activity = activities[index];
              return Dismissible(
                key: ValueKey(activity.key), // それぞれの項目を区別するための鍵！
                direction: DismissDirection.endToStart, // 右から左へのスワイプだけ許可
                onDismissed: (direction) async {
                  // 0. 削除するデータをコピーして一時的に保存
                  final activityToDelete = activity;
                  final activityName = activityToDelete.name;

                  // Activityのコピーを作成
                  final tagsBox = Hive.box<Tag>('tags');
                  final tagsCopy = HiveList<Tag>(tagsBox)..addAll(activityToDelete.tags);
                  final activityCopy = Activity(
                    name: activityToDelete.name,
                    targetCount: activityToDelete.targetCount,
                    tags: tagsCopy,
                    notificationEnabled: activityToDelete.notificationEnabled,
                    notificationDays: List<int>.from(activityToDelete.notificationDays),
                    notificationTime: activityToDelete.notificationTime,
                  )
                    ..id = activityToDelete.id
                    ..createdAt = activityToDelete.createdAt;

                  // 関連レコードのコピーを作成
                  final recordsBox = Hive.box<Record>('records');
                  final relatedRecords = recordsBox.values
                      .where((record) => record.activityId == activityToDelete.id)
                      .toList();
                  final recordCopies = relatedRecords.map((rec) => Record(
                    activityId: rec.activityId,
                    count: rec.count,
                    memo: rec.memo,
                    reaction: rec.reaction,
                  )
                    ..id = rec.id
                    ..date = rec.date).toList();

                  // 1. データを削除
                  final recordKeysToDelete = relatedRecords.map((rec) => rec.key as int).toList();
                  await recordsBox.deleteAll(recordKeysToDelete);
                  await activityToDelete.delete();

                  // 2. 元に戻すオプション付きのSnackBarを表示
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$activityName を削除しました'),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: '元に戻す',
                        onPressed: () async {
                          // データを復元
                          final activitiesBox = Hive.box<Activity>('activities');
                          await activitiesBox.add(activityCopy);
                          await recordsBox.addAll(recordCopies);
                        },
                      ),
                    ),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                child: ListTile(
                  title: Text(activity.name),
                  subtitle: Text('目標: ${activity.targetCount} 回'),
                  onTap: () {
                  // 最後に記録されたメモを探す
                  final recordsBox = Hive.box<Record>('records');
                  final activityRecords = recordsBox.values
                      .where((record) => record.activityId == activity.id)
                      .toList();
                  activityRecords.sort((a, b) => b.date.compareTo(a.date)); // 新しい順に並び替え

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
                    if (record.memo != null && record.memo!.isNotEmpty) {
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
                ),
              );
            },
          );
        },
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
    );
  }
}
