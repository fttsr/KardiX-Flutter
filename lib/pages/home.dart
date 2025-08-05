import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Hive.box('db').get('userName');
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
                      Center(
                        child: Text(
                          "Привет, $userName",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  "Готовы начать?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _actionButton(
                context,
                title: 'Начать процедуру',
                icon: Icons.play_arrow,
                color: const Color.fromARGB(255, 64, 103, 245),
                textColor: Colors.white,
                onPressed: () {},
              ),
              const SizedBox(height: 32),

              _actionButton(
                context,
                title: "Предыдущие Результаты",
                icon: Icons.manage_history,
                color: Colors.white,
                onPressed: () {},
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
                    time: "2ч назад",
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _activityItem(
                    icon: Icons.bar_chart,
                    title: "Просмотр результатов",
                    time: "1д назад",
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
                  fontSize: 20,
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
