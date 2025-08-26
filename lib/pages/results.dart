import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final files = Hive.box(
      'db',
    ).get('pdfFiles', defaultValue: <String>[] as List<String>);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Результаты ЭКГ"),
        centerTitle: true,
      ),
      body: files.isEmpty
          ? const Center(
              child: Text("Нет сохранённых результатов"),
            )
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final path = files[index];
                final name = path.split('/').last;
                return ListTile(
                  title: Text(name),
                  subtitle: Text(path),
                  trailing: IconButton(
                    onPressed: () async {
                      await OpenFile.open(path);
                      Hive.box('db').put(
                        'lastPdfOpenTime',
                        DateTime.now().toIso8601String(),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                );
              },
            ),
    );
  }
}
