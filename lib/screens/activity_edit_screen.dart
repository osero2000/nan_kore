import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/models/tag.dart';

class ActivityEditScreen extends StatefulWidget {
  final Activity? activity;

  const ActivityEditScreen({super.key, this.activity});

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetCountController;
  late final TextEditingController _voiceCommandsController;
  final List<Tag> _selectedTags = [];
  final _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    if (activity != null) {
      // 編集モード
      _nameController = TextEditingController(text: activity.name);
      _targetCountController =
          TextEditingController(text: activity.targetCount.toString());
      _voiceCommandsController =
          TextEditingController(text: activity.voiceCommands.join(', '));
      _selectedTags.addAll(activity.tags);
    } else {
      // 新規作成モード
      _nameController = TextEditingController();
      _targetCountController = TextEditingController(text: '10');
      _voiceCommandsController = TextEditingController();
    }
  }

  void _addNewTag() {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) {
      return;
    }
    final tagsBox = Hive.box<Tag>('tags');
    // 同じ名前のタグが既にないかチェック
    final alreadyExists = tagsBox.values.any((tag) => tag.name == tagName);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('タグ「$tagName」は既に存在します')),
      );
      return;
    }

    // とりあえずランダムな色を割り当てる！
    final newTag = Tag(
      name: tagName,
      colorValue: (Colors.primaries.toList()..shuffle()).first.value,
    );
    // Hiveに保存するだけ！setStateは呼ばないのがポイント！
    tagsBox.add(newTag);
    _newTagController.clear();
  }

  void _saveForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();

    final commandList = _voiceCommandsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (widget.activity != null) {
      // 更新
      final activityToUpdate = widget.activity!;
      activityToUpdate.name = _nameController.text;
      activityToUpdate.targetCount = int.parse(_targetCountController.text);
      activityToUpdate.voiceCommands = commandList;
      activityToUpdate.tags.clear();
      activityToUpdate.tags.addAll(_selectedTags);
      await activityToUpdate.save();
    } else {
      // 新規作成
      final activitiesBox = Hive.box<Activity>('activities');
      final tagsBox = Hive.box<Tag>('tags');
      final activityTags = HiveList<Tag>(tagsBox);
      activityTags.addAll(_selectedTags);

      final newActivity = Activity(
        name: _nameController.text,
        targetCount: int.parse(_targetCountController.text),
        tags: activityTags,
        voiceCommands: commandList,
      );
      await activitiesBox.add(newActivity);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetCountController.dispose();
    _voiceCommandsController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.activity == null ? 'アクティビティの追加' : 'アクティビティの編集'),
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'アクティビティ名'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '名前を入力してください';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _targetCountController,
                  decoration: const InputDecoration(labelText: '目標回数'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '目標回数を入力してください';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return '1以上の数値を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _voiceCommandsController,
                  decoration: const InputDecoration(
                    labelText: '音声コマンド',
                    hintText: '「プラス,追加,いっこ」のようにカンマ区切りで入力',
                  ),
                ),
                const SizedBox(height: 24),
                Text('タグ', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                // 新しいタグを追加するUI
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTagController,
                        decoration: const InputDecoration(labelText: '新しいタグを追加'),
                        onSubmitted: (_) => _addNewTag(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addNewTag,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 既存のタグを選択するUI
                ValueListenableBuilder<Box<Tag>>(
                  valueListenable: Hive.box<Tag>('tags').listenable(),
                  builder: (context, box, _) {
                    final allTags = box.values.toList();
                    if (allTags.isEmpty) {
                      return const Text('まだタグがありません。');
                    }
                    return Wrap(
                      spacing: 8.0,
                      children: allTags.map((tag) {
                        final isSelected =
                            _selectedTags.any((selected) => selected.key == tag.key);
                        return FilterChip(
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.removeWhere((t) => t.key == tag.key);
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
        ),
      ),
    );
  }
}
