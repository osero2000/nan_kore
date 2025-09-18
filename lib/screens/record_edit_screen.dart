import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/record.dart';

class RecordEditScreen extends StatefulWidget {
  final Activity activity;
  final int count;

  const RecordEditScreen({
    super.key,
    required this.activity,
    required this.count,
  });

  @override
  State<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends State<RecordEditScreen> {
  final _memoController = TextEditingController();

  void _saveRecord() async {
    final recordsBox = Hive.box<Record>('records');
    final newRecord = Record(
      activityId: widget.activity.id,
      count: widget.count,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
    );
    await recordsBox.add(newRecord);

    if (!mounted) return;
    // ホーム画面まで一気に戻る！
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity.name} の記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRecord,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'おつかれさま！✨',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '結果: ${widget.count} 回',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '今日のメモ',
                hintText: '今日の感想や、次回の目標などを記録しよう！',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
