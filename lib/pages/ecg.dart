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

class EcgScreen extends StatefulWidget {
  final BluetoothDevice device;

  const EcgScreen({super.key, required this.device});

  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
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

  static const double _ecgFrequency = 0.2;

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
    _timeCounter += 0.04;

    double baseFreq =
        _ecgFrequency + (_rand.nextDouble() - 0.5) * 0.05;
    double amplitude = 1.0 + (_rand.nextDouble() - 0.5) * 0.2;
    double value =
        amplitude * _generateEcgValue(_timeCounter * baseFreq) +
        (_rand.nextDouble() - 0.5) * 0.15; // Дополнительный шум

    setState(() {
      ecgData.add(value);
      if (ecgData.length > 200) ecgData.removeAt(0);

      int ms = DateTime.now().millisecondsSinceEpoch;
      if (ms - _lastHeartRateUpdate >
          1000 + _rand.nextInt(1000)) {
        int delta = (_rand.nextDouble() * 6 - 3)
            .round(); // -3..+3
        heartRate = ((heartRate ?? 80) + delta).clamp(60, 120);
        _lastHeartRateUpdate = ms;
      }

      // Автоскролл
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  double _generateEcgValue(double time) {
    double cycleLength = 60.0 / (heartRate ?? 70);
    double t = time % cycleLength;

    double p = t < 0.12
        ? 0.15 * exp(-pow((t - 0.06) * 20, 2))
        : 0.0;
    double q = (t >= 0.16 && t < 0.18)
        ? -0.25 * exp(-pow((t - 0.17) * 100, 2))
        : 0.0;
    double rAmplitude = 0.9 + (_rand.nextDouble() * 0.2);
    double r = (t >= 0.18 && t < 0.20)
        ? rAmplitude * exp(-pow((t - 0.19) * 100, 2))
        : 0.0;
    double s = (t >= 0.20 && t < 0.22)
        ? -0.35 * exp(-pow((t - 0.21) * 100, 2))
        : 0.0;
    double tWave = (t >= 0.28 && t < 0.40)
        ? 0.25 * exp(-pow((t - 0.34) * 20, 2))
        : 0.0;

    double noise = (_rand.nextDouble() - 0.5) * 0.05;
    return p + q + r + s + tWave + noise;
  }

  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
      if (isRecording) {
        _recordingTimer.start();
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
        _recordingTimer.stop();
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

    await widget.device.disconnect();

    setState(() {
      _isFinished = true;
    });
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

    if (!_isFinished) {
      widget.device.disconnect();
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
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final xStep = size.width / data.length;

    double yScale = size.height / 3;

    // Начальная точка
    path.moveTo(0, size.height / 2 - data[0] * yScale);

    for (int i = 1; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height / 2 - data[i] * yScale;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true;
}
