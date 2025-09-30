import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nan_kore/models/record.dart';
import 'package:nan_kore/models/activity.dart';
import 'package:nan_kore/widgets/app_background.dart';
import 'package:nan_kore/widgets/glass_card.dart';

// グラフの期間を管理するためのenum
enum StatsPeriod { weekly, monthly, quarterly, yearly }

// グラフの計算方法を管理するためのenum
enum StatsCalcType { perDay, perSession }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<BarChartGroupData> _chartData = [];
  double _maxY = 10; // グラフのY軸の最大値
  final today = DateTime.now();
  List<Activity> _activities = [];
  Activity? _selectedActivity; // nullは「すべて」を表す
  StatsPeriod _selectedPeriod = StatsPeriod.weekly;
  StatsCalcType _selectedCalcType = StatsCalcType.perDay;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependenciesは複数回呼ばれる可能性があるので、
    // データロードは一度だけ実行するようにフラグで管理する
    if (!_isInitialized) {
      _loadActivities();
      _loadChartData();
      _isInitialized = true;
    }
  }

  void _loadActivities() {
    final activitiesBox = Hive.box<Activity>('activities');
    setState(() {
      _activities = activitiesBox.values.toList();
    });
  }

  void _loadChartData() {
    switch (_selectedPeriod) {
      case StatsPeriod.weekly:
        _loadWeeklyData();
        break;
      case StatsPeriod.monthly:
        _loadMonthlyData();
        break;
      case StatsPeriod.quarterly:
        _loadQuarterlyData();
        break;
      case StatsPeriod.yearly:
        _loadYearlyData();
        break;
    }
  }

  // 指定された期間とアクティビティでレコードを絞り込むヘルパー関数
  Iterable<Record> _getRelevantRecords(DateTime startDate, DateTime endDate) {
    final recordsBox = Hive.box<Record>('records');
    // 該当するレコードをフィルタリングして集計
    var relevantRecords = recordsBox.values.where((record) =>
        !record.date.isBefore(startDate) && record.date.isBefore(endDate));

    // もし特定のアクティビティが選択されていたら、それでさらに絞り込む
    if (_selectedActivity != null) {
      relevantRecords = relevantRecords
          .where((record) => record.activityId == _selectedActivity!.id);
    }
    return relevantRecords;
  }

  // 週間データをロード
  void _loadWeeklyData() {
    final weekAgo = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final tomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    final relevantRecords = _getRelevantRecords(weekAgo, tomorrow);

    final Map<int, double> dailyTotals = {};
    final Map<int, int> dailyRecordCounts = {};
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final key = int.parse(DateFormat('yyyyMMdd').format(date));
      dailyTotals[key] = 0.0;
      dailyRecordCounts[key] = 0;
    }

    for (final record in relevantRecords) {
      final key = int.parse(DateFormat('yyyyMMdd').format(record.date));
      if (dailyTotals.containsKey(key)) {
        dailyTotals[key] = dailyTotals[key]! + record.count;
        dailyRecordCounts[key] = dailyRecordCounts[key]! + 1;
      }
    }

    final List<BarChartGroupData> barGroups = [];
    double maxVal = 0;
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = int.parse(DateFormat('yyyyMMdd').format(date));
      
      double value = 0;
      if (_selectedCalcType == StatsCalcType.perDay) {
        value = dailyTotals[key] ?? 0.0;
      } else { // perSession
        final total = dailyTotals[key] ?? 0.0;
        final count = dailyRecordCounts[key] ?? 0;
        value = count > 0 ? total / count : 0.0;
      }

      if (value > maxVal) {
        maxVal = value;
      }

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: Theme.of(context).colorScheme.primary,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      _chartData = barGroups;
      // Y軸の最大値を、実際の最大値より少し大きめに設定して見やすくする
      _maxY = (maxVal / 10).ceil() * 10.0;
      if (_maxY < 10) _maxY = 10;
    });
  }

  // 月間データをロード
  void _loadMonthlyData() {
    final firstDayOfMonth = DateTime(today.year, today.month, 1);
    final lastDayOfMonth = DateTime(today.year, today.month + 1, 0);
    final relevantRecords = _getRelevantRecords(firstDayOfMonth, lastDayOfMonth.add(const Duration(days: 1)));

    final Map<int, double> dailyTotals = {};
    final Map<int, int> dailyRecordCounts = {};
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      dailyTotals[i] = 0.0;
      dailyRecordCounts[i] = 0;
    }

    for (final record in relevantRecords) {
      final day = record.date.day;
      dailyTotals[day] = dailyTotals[day]! + record.count;
      dailyRecordCounts[day] = dailyRecordCounts[day]! + 1;
    }

    final List<BarChartGroupData> barGroups = [];
    double maxVal = 0;
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      double value = 0;
      if (_selectedCalcType == StatsCalcType.perDay) {
        value = dailyTotals[i]!;
      } else { // perSession
        final total = dailyTotals[i]!;
        final count = dailyRecordCounts[i]!;
        value = count > 0 ? total / count : 0.0;
      }

      if (value > maxVal) {
        maxVal = value;
      }

      barGroups.add(
        BarChartGroupData(
          x: i - 1,
          barRods: [
            BarChartRodData(
              toY: value,
              color: Theme.of(context).colorScheme.primary,
              width: 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      _chartData = barGroups;
      _maxY = (maxVal / 10).ceil() * 10.0;
      if (_maxY < 10) _maxY = 10;
    });
  }

  // 3ヶ月（週平均）データをロード
  void _loadQuarterlyData() {
    const weekCount = 13;
    final startDate = DateTime(today.year, today.month, today.day).subtract(const Duration(days: weekCount * 7 - 1));
    final tomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    final relevantRecords = _getRelevantRecords(startDate, tomorrow);

    final weeklyTotals = List.generate(weekCount, (_) => 0.0); // 週ごとの合計回数
    final weeklyRecordCounts = List.generate(weekCount, (_) => 0); // 週ごとのレコード数
    final weeklySessionDays = List.generate(weekCount, (_) => <int>{}); // 週ごとの実施日数
    for (final record in relevantRecords) {
      final daysAgo = tomorrow.difference(record.date).inDays;
      final weekIndex = (daysAgo -1) ~/ 7;
      if (weekIndex >= 0 && weekIndex < weekCount) {
        weeklyTotals[weekIndex] += record.count;
        weeklyRecordCounts[weekIndex]++;
        weeklySessionDays[weekIndex].add(int.parse(DateFormat('yyyyMMdd').format(record.date)));
      }
    }

    List<double> values;
    if (_selectedCalcType == StatsCalcType.perSession) {
      values = List.generate(weekCount, (i) {
        return weeklyRecordCounts[i] > 0 ? weeklyTotals[i] / weeklyRecordCounts[i] : 0.0;
      }).reversed.toList();
    } else { // perDay
      values = List.generate(weekCount, (i) {
        final sessionDaysCount = weeklySessionDays[i].length;
        return sessionDaysCount > 0 ? weeklyTotals[i] / sessionDaysCount : 0.0;
      }).reversed.toList();
    }

    double maxVal = 0;
    for (final val in values) {
      if (val > maxVal) maxVal = val;
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < weekCount; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: Theme.of(context).colorScheme.primary,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      _chartData = barGroups;
      _maxY = (maxVal / 10).ceil() * 10.0;
      if (_maxY < 10) _maxY = 10;
    });
  }

  // 年間（月平均）データをロード
  void _loadYearlyData() {
    final firstDayOfYear = DateTime(today.year, 1, 1);
    final nextYear = DateTime(today.year + 1, 1, 1);
    final relevantRecords = _getRelevantRecords(firstDayOfYear, nextYear);

    final monthlyTotals = List.generate(12, (_) => 0.0); // 月ごとの合計回数
    final monthlyRecordCounts = List.generate(12, (_) => 0); // 月ごとのレコード数
    final monthlySessionDays = List.generate(12, (_) => <int>{}); // 月ごとの実施日数
    for (final record in relevantRecords) {
      final monthIndex = record.date.month - 1;
      monthlyTotals[monthIndex] += record.count;
      monthlyRecordCounts[monthIndex]++;
      monthlySessionDays[monthIndex].add(int.parse(DateFormat('yyyyMMdd').format(record.date)));
    }

    List<double> values;
    if (_selectedCalcType == StatsCalcType.perSession) {
      values = List.generate(12, (i) {
        return monthlyRecordCounts[i] > 0 ? monthlyTotals[i] / monthlyRecordCounts[i] : 0.0;
      });
    } else { // perDay
      values = List.generate(12, (i) {
        final sessionDaysCount = monthlySessionDays[i].length;
        return sessionDaysCount > 0 ? monthlyTotals[i] / sessionDaysCount : 0.0;
      });
    }

    double maxVal = 0;
    for (final val in values) {
      if (val > maxVal) maxVal = val;
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 12; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: Theme.of(context).colorScheme.primary,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      _chartData = barGroups;
      _maxY = (maxVal / 10).ceil() * 10.0;
      if (_maxY < 10) _maxY = 10;
    });
  }

  Widget getTitles(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Colors.grey.shade600,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text = '';
    switch (_selectedPeriod) {
      case StatsPeriod.weekly:
        final day = today.subtract(Duration(days: 6 - value.toInt()));
        text = DateFormat('E', 'ja_JP').format(day);
        break;
      case StatsPeriod.monthly:
        final day = value.toInt() + 1;
        if (day % 5 == 0 || day == 1) {
          text = day.toString();
        }
        break;
      case StatsPeriod.quarterly:
        final weeksAgo = 12 - value.toInt();
        if (weeksAgo == 0) {
          text = '今週';
        } else if (weeksAgo % 4 == 0) {
          text = '$weeksAgo週前';
        }
        break;
      case StatsPeriod.yearly:
        text = '${value.toInt() + 1}月';
        break;
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(text, style: style),
    );
  }

  String _getChartTitle() {
    if (_selectedCalcType == StatsCalcType.perSession) {
      return '1回あたり平均';
    }

    // perDay is selected
    switch (_selectedPeriod) {
      case StatsPeriod.weekly:
      case StatsPeriod.monthly:
        return '日別合計';
      case StatsPeriod.quarterly:
        return '週合計の日あたり平均';
      case StatsPeriod.yearly:
        return '月合計の日あたり平均';
    }
  }

  String _getPeriodName() {
    switch (_selectedPeriod) {
      case StatsPeriod.weekly:
        return '過去7日間';
      case StatsPeriod.monthly:
        return '今月';
      case StatsPeriod.quarterly:
        return '過去3ヶ月';
      case StatsPeriod.yearly:
        return '今年';
    }
  }

  String _getTooltipValue(double value) {
    if (_selectedCalcType == StatsCalcType.perDay && (_selectedPeriod == StatsPeriod.weekly || _selectedPeriod == StatsPeriod.monthly)) {
      return '${value.toInt()} 回';
    }
    return '${value.toStringAsFixed(1)} 回';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('アクティビティグラフ'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // 横幅をいっぱいにする
              children: [
                GlassCard(
                  margin: const EdgeInsets.all(0),
                  child: Column(
                    children: [
                      // 期間選択ボタン
                      SegmentedButton<StatsPeriod>(
                        segments: const <ButtonSegment<StatsPeriod>>[
                          ButtonSegment(value: StatsPeriod.weekly, label: Text('週間')),
                          ButtonSegment(value: StatsPeriod.monthly, label: Text('月間')),
                          ButtonSegment(value: StatsPeriod.quarterly, label: Text('3ヶ月')),
                          ButtonSegment(value: StatsPeriod.yearly, label: Text('年間')),
                        ],
                        selected: {_selectedPeriod},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedPeriod = newSelection.first;
                          });
                          _loadChartData();
                        },
                      ),
                      const SizedBox(height: 16),
                      // 計算方法選択ボタン
                      SegmentedButton<StatsCalcType>(
                        segments: const <ButtonSegment<StatsCalcType>>[
                          ButtonSegment(value: StatsCalcType.perDay, label: Text('合計/日あたり')),
                          ButtonSegment(value: StatsCalcType.perSession, label: Text('1回あたり')),
                        ],
                        selected: {_selectedCalcType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedCalcType = newSelection.first;
                          });
                          _loadChartData();
                        },
                      ),
                      const SizedBox(height: 8),
                      // アクティビティ選択のドロップダウン
                      DropdownButton<Activity?>(
                        value: _selectedActivity,
                        hint: const Text('すべてのアクティビティ'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<Activity?>(
                            value: null,
                            child: Text('💪 すべてのアクティビティ'),
                          ),
                          // スプレッド演算子(...)を使うときは、.toList()は要らないよ！
                          ..._activities.map((activity) {
                            return DropdownMenuItem<Activity?>(
                              value: activity,
                              child: Text(activity.name),
                            );
                          }),
                        ],
                        onChanged: (activity) {
                          setState(() {
                            _selectedActivity = activity;
                          });
                          _loadChartData();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  margin: const EdgeInsets.all(0),
                  child: Column(
                    children: [
                      Text(
                        '${_getPeriodName()}の${_getChartTitle()}',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1.5,
                        child: BarChart(
                          BarChartData(
                            // タッチした時の挙動を設定
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    _getTooltipValue(rod.toY),
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            maxY: _maxY,
                            barGroups: _chartData,
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: getTitles, reservedSize: 38)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
