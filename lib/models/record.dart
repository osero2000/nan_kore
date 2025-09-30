import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'record.g.dart';

@HiveType(typeId: 2)
class Record extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  String activityId; // どのアクティビティの記録か分かるようにIDを保存

  @HiveField(2)
  int count;

  @HiveField(3)
  String? memo; // メモはなくてもOKだから `?` をつける

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  int reaction; // 0:なし, 1:いいね, 2:ハート みたいに決めておく

  Record(
      {required this.activityId, required this.count, this.memo, this.reaction = 0}) : date = DateTime.now() {
    id = const Uuid().v4();
  }

  Record copyWith({
    String? id,
    String? activityId,
    int? count,
    String? memo,
    DateTime? date,
    int? reaction,
  }) {
    final newRecord = Record(
      activityId: activityId ?? this.activityId,
      count: count ?? this.count,
      memo: memo ?? this.memo,
      reaction: reaction ?? this.reaction,
    )
      ..id = id ?? this.id
      ..date = date ?? this.date;
    return newRecord;
  }
}
