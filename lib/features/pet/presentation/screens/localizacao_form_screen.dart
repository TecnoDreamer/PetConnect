import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/localizacao.dart';
import '../providers/localizacao_providers.dart';

/// Registrar um avistamento do pet (RF31/RF32). Nesta fase, só o próprio
/// tutor consegue chegar nesta tela (ex: recebeu um aviso por telefone) —
/// o fluxo de alguém estranho reportar direto pela página pública do QR
/// code depende de RF17-19, ainda pendente (ver README/roadmap).
class LocalizacaoFormScreen extends ConsumerStatefulWidget {
  const LocalizacaoFormScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<LocalizacaoFormScreen> createState() =>
      _LocalizacaoFormScreenState();
}

class _LocalizacaoFormScreenState extends ConsumerState<LocalizacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataController =
      TextEditingController(text: formatBrDate(DateTime.now()));
  final _descricaoController = TextEditingController();
  final _contatoController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    _descricaoController.dispose();
    _contatoController.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final initial = parseBrDate(_dataController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dataController.text = formatBrDate(picked);
    }
  }

  Future<void> _handleSalvar() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    try {
      await ref.read(localizacaoRepositoryProvider).createLocalizacao(
            widget.petId,
            Localizacao(
              id: '',
              data: _dataController.text.trim(),
              descricao: _descricaoController.text.trim(),
              contatoReportante: _contatoController.text.trim(),
            ),
          );
      // A lista via API é uma emissão única — força o recarregamento.
      ref.invalidate(localizacoesProvider(widget.petId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível salvar o registro. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Registrar avistamento',
            style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _dataController,
                  readOnly: true,
                  onTap: _pickData,
                  decoration: InputDecoration(
                    hintText: 'Data:',
                    suffixIcon:
                        Icon(Icons.calendar_today, color: colors.textMuted),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe a data.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Onde/como o pet foi visto (ex: Rua X, perto do mercado):',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Descreva o local.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contatoController,
                  decoration: const InputDecoration(
                      hintText: 'Contato de quem viu (opcional):'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: colors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _handleSalvar,
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textOnBrand,
                          ),
                        )
                      : const Text('SALVAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
