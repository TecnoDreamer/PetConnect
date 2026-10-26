import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/vacina.dart';
import '../providers/vacina_providers.dart';

/// Formulário de registrar (RF20) ou editar (RF22) uma vacina de um pet.
class VacinaFormScreen extends ConsumerStatefulWidget {
  const VacinaFormScreen({super.key, required this.petId, this.vacina});

  final String petId;
  final Vacina? vacina;

  bool get isEditing => vacina != null;

  @override
  ConsumerState<VacinaFormScreen> createState() => _VacinaFormScreenState();
}

class _VacinaFormScreenState extends ConsumerState<VacinaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController =
      TextEditingController(text: widget.vacina?.nome ?? '');
  late final _dataAplicacaoController =
      TextEditingController(text: widget.vacina?.dataAplicacao ?? '');
  late final _proximaDoseController =
      TextEditingController(text: widget.vacina?.proximaDose ?? '');
  late final _veterinarioController =
      TextEditingController(text: widget.vacina?.veterinario ?? '');
  late final _observacoesController =
      TextEditingController(text: widget.vacina?.observacoes ?? '');

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _dataAplicacaoController.dispose();
    _proximaDoseController.dispose();
    _veterinarioController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _pickData(TextEditingController controller) async {
    final initial = parseBrDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = formatBrDate(picked);
    }
  }

  Future<void> _handleSalvar() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final repository = ref.read(vacinaRepositoryProvider);
    final existing = widget.vacina;

    try {
      if (existing == null) {
        await repository.createVacina(
          widget.petId,
          Vacina(
            id: '',
            nome: _nomeController.text.trim(),
            dataAplicacao: _dataAplicacaoController.text.trim(),
            proximaDose: _proximaDoseController.text.trim(),
            veterinario: _veterinarioController.text.trim(),
            observacoes: _observacoesController.text.trim(),
          ),
        );
      } else {
        await repository.updateVacina(
          widget.petId,
          existing.copyWith(
            nome: _nomeController.text.trim(),
            dataAplicacao: _dataAplicacaoController.text.trim(),
            proximaDose: _proximaDoseController.text.trim(),
            veterinario: _veterinarioController.text.trim(),
            observacoes: _observacoesController.text.trim(),
          ),
        );
      }
      // A lista via API é uma emissão única — força o recarregamento.
      ref.invalidate(vacinasProvider(widget.petId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível salvar a vacina. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Editar vacina' : 'Registrar vacina',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
                  controller: _nomeController,
                  decoration:
                      const InputDecoration(hintText: 'Nome da vacina:'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o nome da vacina.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dataAplicacaoController,
                  readOnly: true,
                  onTap: () => _pickData(_dataAplicacaoController),
                  decoration: const InputDecoration(
                    hintText: 'Data de aplicação:',
                    suffixIcon:
                        Icon(Icons.calendar_today, color: AppColors.textMuted),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe a data de aplicação.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _proximaDoseController,
                  readOnly: true,
                  onTap: () => _pickData(_proximaDoseController),
                  decoration: const InputDecoration(
                    hintText: 'Próxima dose (opcional):',
                    suffixIcon:
                        Icon(Icons.calendar_today, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _veterinarioController,
                  decoration: const InputDecoration(
                      hintText: 'Veterinário/clínica (opcional):'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _observacoesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Observações (opcional):'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _handleSalvar,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnBrand,
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
