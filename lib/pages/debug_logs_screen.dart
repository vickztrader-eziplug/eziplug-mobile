// lib/pages/debug_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cashpoint/services/debug_logger.dart';

class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  String _fileLogs = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFileLogs();
  }

  Future<void> _loadFileLogs() async {
    final logs = await debugLogger.readLogsFromFile();
    setState(() {
      _fileLogs = logs;
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    await debugLogger.clearLogs();
    setState(() {
      _fileLogs = 'Logs cleared';
    });
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _fileLogs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFileLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Memory logs section
                  Text(
                    'Memory Logs (${debugLogger.logs.length} entries)',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      debugLogger.logs.isEmpty
                          ? 'No logs in memory'
                          : debugLogger.logs.reversed.take(50).join('\n'),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // File logs section
                  const Text(
                    'File Logs',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fileLogs,
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
