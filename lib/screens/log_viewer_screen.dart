import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _logger = AppLogger();
  String _logContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final content = await _logger.getLogContent();
      setState(() {
        _logContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logContent = 'Erreur lors du chargement des logs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _logContent));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copiés dans le presse-papiers'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareLogs() async {
    final path = await _logger.getLogFilePath();
    if (path != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emplacement du fichier de log'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: path));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chemin copié dans le presse-papiers'),
                  ),
                );
              },
              child: const Text('Copier'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de l\'application'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copier',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: 'Partager',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                _logContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
