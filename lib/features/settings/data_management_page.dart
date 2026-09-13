import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/backup_service.dart';
import '../../services/export_service.dart';
import 'restore_backup_page.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _busy = false;

  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final json = await BackupService.instance.createJson();
      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'Backup Xarleta Finanças'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCsv() async {
    setState(() => _busy = true);
    try {
      final csv = await ExportService.instance.transactionsCsv();
      await SharePlus.instance.share(
        ShareParams(text: csv, subject: 'Exportação Xarleta Finanças CSV'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dados e backup')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Criar backup'),
            subtitle: const Text('Gera um backup JSON dos dados locais'),
            trailing: const Icon(Icons.share_outlined),
            onTap: _busy ? null : _shareBackup,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurar backup'),
            subtitle: const Text('Selecionar arquivo JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestoreBackupPage(),
                      ),
                    ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar CSV'),
            subtitle: const Text('Exporta seus ganhos e gastos'),
            trailing: const Icon(Icons.share_outlined),
            onTap: _busy ? null : _shareCsv,
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}

