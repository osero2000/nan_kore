import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'tag.g.dart';

@HiveType(typeId: 0)
class Tag extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue; // 色はint型で保存すると楽ちん！

  Tag({required this.name, required this.colorValue}) {
    id = const Uuid().v4();
  }
}
