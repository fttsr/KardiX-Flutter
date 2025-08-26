import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kardix_flutter/pages/bluetooth_connection.dart';
import 'package:kardix_flutter/pages/results.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _formatAgo(DateTime? dateTime) {
    if (dateTime == null) return "Нет данных";
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return "только что";
    if (diff.inMinutes < 60)
      return "${diff.inMinutes} мин назад";
    if (diff.inMinutes > 60) return "${diff.inHours}ч назад";
    return "${diff.inDays}д назад";
  }

  @override
  Widget build(BuildContext context) {
    final userName = Hive.box('db').get('userName');
    final lastEcgTimeStr = Hive.box('db').get('lastEcgTime');
    final lastPdfOpenTimeStr = Hive.box(
      'db',
    ).get('lastPdfOpenTime');
    final lastEcgTime = lastEcgTimeStr != null
        ? DateTime.tryParse(lastEcgTimeStr)
        : null;
    final lastPdfOpenTime = lastPdfOpenTimeStr != null
        ? DateTime.tryParse(lastPdfOpenTimeStr)
        : null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя часть с приветствием
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName == null ||
                                userName
                                    .toString()
                                    .trim()
                                    .isEmpty
                            ? "Привет!"
                            : "Привет, $userName",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 28),
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) {
                          final controller =
                              TextEditingController(
                                text: userName ?? "",
                              );
                          return AlertDialog(
                            title: const Text("Изменить имя"),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: "Введите имя",
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Hive.box(
                                    'db',
                                  ).delete('userName');
                                  Navigator.of(context).pop('');
                                },
                                child: const Text("Сбросить"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pop(controller.text.trim());
                                },
                                child: const Text("Сохранить"),
                              ),
                            ],
                          );
                        },
                      );
                      if (result != null) {
                        if (result.isEmpty) {
                          Hive.box('db').delete('userName');
                        } else {
                          Hive.box('db').put('userName', result);
                        }
                        // Обновить экран
                        (context as Element).markNeedsBuild();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Готовы начать?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),
              _actionButton(
                context,
                title: 'Начать процедуру',
                icon: Icons.play_arrow,
                color: const Color.fromARGB(255, 64, 103, 245),
                textColor: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BluetoothConnectionScreen(),
                    ),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 32),

              _actionButton(
                context,
                title: "Предыдущие Результаты",
                icon: Icons.manage_history,
                color: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ResultsScreen(),
                    ),
                  );
                  setState(() {});
                },
                textColor: Colors.black,
              ),

              const SizedBox(height: 16),

              _actionButton(
                context,
                title: "Инструкция",
                icon: Icons.menu_book,
                color: Colors.white,
                onPressed: () {},
                textColor: Colors.black,
              ),

              const SizedBox(height: 120),

              // Недавняя активность
              const Text(
                "Недавняя активность",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  _activityItem(
                    icon: Icons.check_circle,
                    title: "Выполнение процедуры",
                    time: _formatAgo(lastEcgTime),
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _activityItem(
                    icon: Icons.bar_chart,
                    title: "Просмотр результатов",
                    time: _formatAgo(lastPdfOpenTime),
                    color: Color.fromARGB(255, 64, 103, 245),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required Color textColor,
  }) {
    return Center(
      child: SizedBox(
        height: 78,
        width: 350,

        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: textColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityItem({
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Container(
      height: 67,
      width: 350,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          // const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
