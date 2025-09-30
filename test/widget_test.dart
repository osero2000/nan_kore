// This is a basic Flutter widget test.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/record.dart';
import 'package:nan_kore/models/tag.dart';

import 'package:nan_kore/main.dart';

void main() {
  // テストが始まる前に、一回だけ実行されるセットアップ処理
  setUpAll(() async {
    // テスト用のHiveの初期化
    // テスト中に生成されるファイルがどこかに保存されるように、一時的なパスを指定する
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);

    // アプリで使っているAdapterをすべて登録する
    Hive.registerAdapter(TagAdapter());
    Hive.registerAdapter(ActivityAdapter());
    Hive.registerAdapter(RecordAdapter());

    // アプリで使っているBoxをすべて開ける
    await Hive.openBox<Activity>('activities');
    await Hive.openBox<Tag>('tags');
    await Hive.openBox<Record>('records');
  });

  // テストが終わった後に、一回だけ実行される後片付け処理
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('アプリ起動時にダッシュボードが表示されるかテスト', (WidgetTester tester) async {
    // MyAppウィジェットを描画する
    await tester.pumpWidget(const MyApp());

    // AppBarのタイトルが「ダッシュボード」であることを確認
    expect(find.text('ダッシュボード'), findsOneWidget);

    // 画面右下の「+」ボタン（FloatingActionButton）があることを確認
    await tester.tap(find.byIcon(Icons.add));
  });
}
