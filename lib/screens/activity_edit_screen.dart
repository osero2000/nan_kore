import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/tag.dart';

class ActivityEditScreen extends StatefulWidget {
  const ActivityEditScreen({super.key});

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _targetCount = 10;

  void _saveForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();

    final activitiesBox = Hive.box<Activity>('activities');
    // 今はまだタグ機能がないから、空っぽのリストを渡しておく！
    final tagsBox = Hive.box<Tag>('tags');
    final emptyTagsList = HiveList<Tag>(tagsBox);

    final newActivity = Activity(
      name: _name,
      targetCount: _targetCount,
      tags: emptyTagsList,
    );
    await activitiesBox.add(newActivity);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アクティビティの追加'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'アクティビティ名'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: '目標回数'),
                keyboardType: TextInputType.number,
                initialValue: _targetCount.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '目標回数を入力してください';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '1以上の数値を入力してください';
                  }
                  return null;
                },
                onSaved: (value) {
                  _targetCount = int.parse(value!);
                },
              ),
              // TODO: タグ選択UIを追加する
            ],
          ),
        ),
      ),
    );
  }
}
