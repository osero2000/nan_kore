import 'package:flutter/material.dart';

class ActivityEditScreen extends StatefulWidget {
  const ActivityEditScreen({super.key});

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _targetCount = 10;

  void _saveForm() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();
    // TODO: Hiveに保存する処理をあとで書く！
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

