import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'tag.dart'; // さっき作ったTagをインポート

part 'activity.g.dart';

@HiveType(typeId: 1)
class Activity extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int targetCount;

  @HiveField(3)
  HiveList<Tag> tags; // タグをリストで持てるようにする！

  @HiveField(4)
  bool notificationEnabled;

  @HiveField(5)
  List<int> notificationDays; // 月曜=1, 火曜=2...みたいに数字で曜日を保存

  @HiveField(6)
  String notificationTime; // "21:00" みたいな文字列で時間を保存

  @HiveField(7)
  DateTime createdAt;

  Activity({
    required this.name,
    required this.targetCount,
    required this.tags,
    this.notificationEnabled = false,
    this.notificationDays = const [],
    this.notificationTime = '09:00',
  }) : createdAt = DateTime.now() {
    id = const Uuid().v4();
  }
}
