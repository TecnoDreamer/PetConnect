import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/consulta.dart';
import '../providers/consulta_providers.dart';

/// Formulário de agendar (RF27) ou editar (RF29) uma consulta veterinária.
class ConsultaFormScreen extends ConsumerStatefulWidget {
  const ConsultaFormScreen({super.key, required this.petId, this.consulta});

  final String petId;
  final Consulta? consulta;

  bool get isEditing => consulta != null;

  @override
  ConsumerState<ConsultaFormScreen> createState() => _ConsultaFormScreenState();
}

class _ConsultaFormScreenState extends ConsumerState<ConsultaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _dataController =
      TextEditingController(text: widget.consulta?.data ?? '');
  late final _horarioController =
      TextEditingController(text: widget.consulta?.horario ?? '');
  late final _veterinarioController =
      TextEditingController(text: widget.consulta?.veterinario ?? '');
  late final _motivoController =
      TextEditingController(text: widget.consulta?.motivo ?? '');

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    _horarioController.dispose();
    _veterinarioController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final initial = parseBrDate(_dataController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dataController.text = formatBrDate(picked);
    }
  }

  Future<void> _pickHorario() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _horarioController.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleSalvar() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final repository = ref.read(consultaRepositoryProvider);
    final existing = widget.consulta;

    try {
      if (existing == null) {
        await repository.createConsulta(
          widget.petId,
          Consulta(
            id: '',
            data: _dataController.text.trim(),
            horario: _horarioController.text.trim(),
            veterinario: _veterinarioController.text.trim(),
            motivo: _motivoController.text.trim(),
            status: ConsultaStatus.agendada,
          ),
        );
      } else {
        await repository.updateConsulta(
          widget.petId,
          existing.copyWith(
            data: _dataController.text.trim(),
            horario: _horarioController.text.trim(),
            veterinario: _veterinarioController.text.trim(),
            motivo: _motivoController.text.trim(),
          ),
        );
      }
      // A lista via API é uma emissão única — força o recarregamento.
      ref.invalidate(consultasProvider(widget.petId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível salvar a consulta. Tente novamente.');
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
        title: Text(
          widget.isEditing ? 'Editar consulta' : 'Agendar consulta',
          style: TextStyle(color: colors.textPrimary),
        ),
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
                  controller: _horarioController,
                  readOnly: true,
                  onTap: _pickHorario,
                  decoration: InputDecoration(
                    hintText: 'Horário (opcional):',
                    suffixIcon:
                        Icon(Icons.access_time, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _veterinarioController,
                  decoration:
                      const InputDecoration(hintText: 'Veterinário/clínica:'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o veterinário/clínica.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Motivo:'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o motivo da consulta.'
                      : null,
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
