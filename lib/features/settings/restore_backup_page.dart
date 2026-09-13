import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/backup_service.dart';

class RestoreBackupPage extends StatefulWidget {
  const RestoreBackupPage({super.key});

  @override
  State<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends State<RestoreBackupPage> {
  bool _busy = false;
  String? _selectedName;
  String? _content;

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    if (!mounted) return;
    setState(() {
      _selectedName = result.files.single.name;
      _content = content;
    });
  }

  Future<void> _restore() async {
    if (_content == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text(
          'Os dados atuais serão substituídos pelos dados do backup selecionado. '
          'Essa ação não pode ser desfeita sem criar outro backup antes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('RESTAURAR')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await BackupService.instance.restoreJson(_content!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso.')),
      );
      setState(() {
        _selectedName = null;
        _content = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup inválido ou incompatível: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restaurar backup')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Selecionar arquivo JSON'),
            subtitle: Text(_selectedName ?? 'Nenhum arquivo selecionado'),
            onTap: _busy ? null : _selectFile,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy || _content == null ? null : _restore,
          icon: const Icon(Icons.restore),
          label: Text(_busy ? 'RESTAURANDO...' : 'RESTAURAR BACKUP'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Recomendação: antes de restaurar, crie um backup dos dados atuais.',
        ),
      ],
    ),
  );
}

