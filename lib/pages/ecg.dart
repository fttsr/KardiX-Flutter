import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive/hive.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

import 'package:printing/printing.dart';

class EcgScreen extends StatefulWidget {
  final BluetoothDevice device;

  const EcgScreen({super.key, required this.device});

  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  StreamSubscription? _deviceStateSubscription;

  bool _isFinished = false;

  final GlobalKey _ecgGraphKey = GlobalKey();

  List<double> ecgData = [];
  int? heartRate;
  bool isRecording = true;

  Timer? _ecgTimer;
  final Stopwatch _recordingTimer = Stopwatch();
  final ScrollController _scrollController = ScrollController();
  final Random _rand = Random();
  double _timeCounter = 0.0;

  int _remainingSeconds = 60;
  Timer? _countdownTimer;

  List<int> heartRateHistory = [];

  Future<Uint8List> _captureEcgImage() async {
    try {
      final RenderRepaintBoundary boundary =
          _ecgGraphKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Ошибка захвата изображения: $e');
      return Uint8List(0);
    }
  }

  @override
  void initState() {
    super.initState();

    // Подписываемся на состояние устройства
    _deviceStateSubscription = widget.device.state.listen(
      (dynamic state) {
        debugPrint('[ECG] device.state -> $state');

        final s = state.toString().toLowerCase();
        if (s.contains('disconnected')) {
          if (!_isFinished) {
            _isFinished = true;

            _ecgTimer?.cancel();
            _countdownTimer?.cancel();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Устройство отсоединено'),
                ),
              );

              Future.microtask(() {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
            }
          }
        }
      },
      onError: (e) => debugPrint('[ECG] device.state error: $e'),
    );

    _startEcgMonitoring();
    _startCountdown();
  }

  void _startCountdown() {
    _remainingSeconds = 60;
    heartRateHistory.clear();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
          heartRateHistory.add(heartRate ?? 0);
        } else {
          timer.cancel();
          setState(() {
            isRecording = false;
          });
          _ecgTimer?.cancel();
          await _saveEcgToPdf();
          if (mounted) Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _startEcgMonitoring() async {
    _ecgTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (timer) {
        _addDemoData();
      },
    );
  }

  int _lastHeartRateUpdate = 0;

  void _addDemoData() {
    _timeCounter += 0.02;

    // Рандом ЧСС
    int ms = DateTime.now().millisecondsSinceEpoch;
    if (ms - _lastHeartRateUpdate > 4000 + _rand.nextInt(1000)) {
      int delta = (_rand.nextDouble() * 6 - 3).round(); // -3..+3
      heartRate = ((heartRate ?? 75) + delta).clamp(50, 120);
      _lastHeartRateUpdate = ms;
    }

    // Шум
    double amplitude = 1.0 + (_rand.nextDouble() - 0.5) * 0.15;
    double value =
        amplitude * _generateEcgValue(_timeCounter) +
        (_rand.nextDouble() - 0.5) * 0.02;

    while (ecgData.length > 0 && !ecgData.first.isFinite) {
      ecgData.removeAt(0);
    }

    setState(() {
      ecgData.add(value);
      if (ecgData.length > 800) ecgData.removeAt(0);

      // Автоскролл
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  double _generateEcgValue(double timeSec) {
    final hr = (heartRate ?? 75).toDouble();
    final cycleLength = 60.0 / hr;
    final tInCycle = timeSec % cycleLength;
    final normalizedT = tInCycle / cycleLength; // 0..1

    // Гауссовы импульсы для имитации P, Q, R, S, T
    double gaussian(double x, double mu, double sigma) {
      final z = (x - mu) / sigma;
      return exp(-0.5 * z * z);
    }

    double value = 0.0;

    // P — Начало
    value += 0.12 * gaussian(normalizedT, 0.12, 0.03);

    // Q — Перед пиком
    value += -0.18 * gaussian(normalizedT, 0.28, 0.008);

    // R — Основной пик
    value += 1.0 * gaussian(normalizedT, 0.30, 0.006);

    // S — После R
    value += -0.22 * gaussian(normalizedT, 0.335, 0.01);

    // T — В конце
    value += 0.30 * gaussian(normalizedT, 0.6, 0.06);

    // Шум
    value += (_rand.nextDouble() - 0.5) * 0.01;

    return value;
  }

  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
      if (isRecording) {
        _recordingTimer.start();
        _timeCounter = 0.0;

        _ecgTimer = Timer.periodic(
          const Duration(milliseconds: 40),
          (timer) {
            _addDemoData();
          },
        );

        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) async {
            if (_remainingSeconds > 0) {
              setState(() {
                _remainingSeconds--;
              });
              heartRateHistory.add(heartRate ?? 0);
            } else {
              timer.cancel();
              setState(() {
                isRecording = false;
                _isFinished = true;
              });
              _ecgTimer?.cancel();
              await _saveEcgToPdf();
              if (mounted) Navigator.pop(context);
            }
          },
        );
      } else {
        // Пауза — вставляем визуальный разрыв
        _recordingTimer.stop();
        _insertPauseGap(gapLength: 80);
        _ecgTimer?.cancel();
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _saveEcgToPdf() async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final dateStr =
        "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final fileName = 'heart_rate_table_$dateStr$timeStr.pdf';

    final ecgImageBytes = await _captureEcgImage();

    // Проверяем, что изображение было успешно захвачено
    if (ecgImageBytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ошибка: не удалось захватить изображение ЭКГ',
            ),
          ),
        );
      }
      return;
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'Second',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'Heart Rate',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ];

    for (int i = 0; i < heartRateHistory.length; i++) {
      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('${i + 1}'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('${heartRateHistory[i]}'),
            ),
          ],
        ),
      );
    }

    // Добавляем страницу с таблицей и графиком ЭКГ
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ECG Results by $dateStr at $timeStr',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Heart Rate Table:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(),
                children: tableRows,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'ECG Graph',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Image(
                pw.MemoryImage(ecgImageBytes),
                width: 500,
                height: 200,
                fit: pw.BoxFit.fitWidth,
              ),
            ],
          );
        },
      ),
    );

    Hive.box('db').put('lastEcgTime', now.toIso8601String());

    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/$fileName');
      try {
        await file.writeAsBytes(await pdf.save());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF сохранён: ${file.path}')),
        );
        Hive.box('db').put('lastPdfPath', file.path);
        final files =
            Hive.box(
                  'db',
                ).get('pdfFiles', defaultValue: <String>[])
                as List<String>;
        files.add(file.path);
        Hive.box('db').put('pdfFiles', files);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } else {
      // Для iOS и других платформ
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF сохранён: ${file.path}')),
      );
      Hive.box('db').put('lastPdfPath', file.path);
      final files =
          Hive.box(
                'db',
              ).get('pdfFiles', defaultValue: <String>[])
              as List<String>;
      files.add(file.path);
      Hive.box('db').put('pdfFiles', files);
    }

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );

    setState(() {
      _isFinished = true;
    });

    await widget.device.disconnect();

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _saveResults() async {
    _ecgTimer?.cancel();
    _countdownTimer?.cancel();
    await _saveEcgToPdf();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(seconds ~/ 60);
    final secs = twoDigits(seconds % 60);
    return "$minutes:$secs";
  }

  @override
  void dispose() {
    _ecgTimer?.cancel();
    _countdownTimer?.cancel();
    _deviceStateSubscription?.cancel();

    if (!_isFinished) {
      try {
        widget.device.disconnect();
      } catch (e) {
        debugPrint('Ошибка отключения от кардиографа $e');
      }
    }

    super.dispose();
  }

  Future<bool> _onPop() async {
    if (_isFinished) return true;

    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Прервать запись?"),
            content: const Text(
              "Вы уверены, что хотите прервать запись? Данные не будут сохранены.",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false),
                child: const Text("Отмена"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Прервать"),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      _ecgTimer?.cancel();
      _countdownTimer?.cancel();

      await widget.device.disconnect();

      _isFinished = true;

      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingTime = _formatDuration(_remainingSeconds);

    return WillPopScope(
      onWillPop: _onPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Мониторинг ЭКГ",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectionStatus(),
              const SizedBox(height: 20),
              _buildHeartRateSection(),
              const SizedBox(height: 20),
              _buildEcgGraph(),
              const SizedBox(height: 20),
              _buildControls(recordingTime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.bluetooth_connected,
          color: Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          "Подключено к ${widget.device.platformName}",
          style: const TextStyle(color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildHeartRateSection() {
    return Column(
      children: [
        Text(
          "ТЕКУЩИЙ ПУЛЬС",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          heartRate?.toString() ?? "--",
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "ЧСС",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEcgGraph() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "ЭКГ",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ecgData.isEmpty
                  ? const Center(
                      child: Text("Ожидание данных..."),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: RepaintBoundary(
                        key: _ecgGraphKey,
                        child: CustomPaint(
                          size: Size(ecgData.length * 4.0, 200),
                          painter: _EcgLinePainter(
                            data: ecgData,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertPauseGap({int gapLength = 80}) {
    setState(() {
      for (int i = 0; i < gapLength; i++) {
        ecgData.add(0.0);
      }
      while (ecgData.length > 800) ecgData.removeAt(0);
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent,
      );
    }
  }

  Widget _buildControls(String recordingTime) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "ТАЙМЕР",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recordingTime,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  isRecording ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(isRecording ? "ПАУЗА" : "ДАЛЕЕ"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording
                      ? Colors.orange
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: _toggleRecording,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("СОХРАНИТЬ"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: _saveResults,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EcgLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _EcgLinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += 25) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final baselinePaint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 1.0;
    final double baselineY = size.height / 2;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    final ecgPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final double xStep = data.length > 1
        ? size.width / (data.length - 1)
        : size.width;
    final double yScale = size.height / 2.5;

    bool started = false;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      if (d == null || !d.isFinite) {
        // разрыв: не продолжаем путь
        started = false;
        continue;
      }

      final double x = i * xStep;
      final double y = baselineY - d * yScale;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (started) {
      canvas.drawPath(path, ecgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true;
}
