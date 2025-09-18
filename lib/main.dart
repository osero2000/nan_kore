import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/record.dart';
import 'package:nan_kore/models/tag.dart';
import 'package:nan_kore/screens/activity_edit_screen.dart';
import 'package:nan_kore/screens/count_screen.dart';

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
              return ListTile(
                title: Text(activity.name),
                subtitle: Text('目標: ${activity.targetCount} 回'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => CountScreen(activity: activity),
                    ),
                  );
                },
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
