import 'package:hive/hive.dart';
import 'package:nan_kore/models/tag.dart';
import 'package:uuid/uuid.dart';

part 'activity.g.dart';

@HiveType(typeId: 1)
class Activity extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int targetCount;

  @HiveField(2)
  HiveList<Tag> tags;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool notificationEnabled;

  @HiveField(5)
  List<int> notificationDays;

  @HiveField(6)
  String? notificationTime;

  // これを追加！👇
  @HiveField(7)
  List<String> voiceCommands;

  @HiveField(100)
  String id;

  Activity({
    required this.name,
    required this.targetCount,
    required this.tags,
    this.notificationEnabled = false,
    this.notificationDays = const [],
    this.notificationTime,
    this.voiceCommands = const [], // これも追加！
  })  : id = const Uuid().v4(),
        createdAt = DateTime.now();
}
