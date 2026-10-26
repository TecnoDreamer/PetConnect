import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/br_date.dart';
import '../../../../core/utils/upload_error.dart';
import '../../domain/historico_medico.dart';
import '../providers/anexo_providers.dart';
import '../providers/historico_medico_providers.dart';

const _tamanhoMaximoAnexo = 5 * 1024 * 1024; // 5MB — ver docs/seguranca.md.

/// Formulário de registrar (RF24) ou editar (RF26) uma entrada de histórico
/// médico, incluindo upload de anexos (fotos de exames, por exemplo) ao
/// Firebase Storage.
class HistoricoFormScreen extends ConsumerStatefulWidget {
  const HistoricoFormScreen({super.key, required this.petId, this.historico});

  final String petId;
  final HistoricoMedico? historico;

  bool get isEditing => historico != null;

  @override
  ConsumerState<HistoricoFormScreen> createState() =>
      _HistoricoFormScreenState();
}

class _HistoricoFormScreenState extends ConsumerState<HistoricoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _dataController =
      TextEditingController(text: widget.historico?.data ?? '');
  late final _descricaoController =
      TextEditingController(text: widget.historico?.descricao ?? '');
  late final _veterinarioController =
      TextEditingController(text: widget.historico?.veterinario ?? '');

  late final String _registroId = widget.historico?.id ??
      ref.read(historicoMedicoRepositoryProvider).novoId(widget.petId);
  late List<String> _anexos = List.of(widget.historico?.anexos ?? const []);

  bool _enviandoAnexo = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    _descricaoController.dispose();
    _veterinarioController.dispose();
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

  Future<void> _adicionarAnexo() async {
    final arquivo = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    if (bytes.length > _tamanhoMaximoAnexo) {
      setState(() => _error = 'O anexo excede o tamanho máximo de 5MB.');
      return;
    }

    setState(() {
      _error = null;
      _enviandoAnexo = true;
    });

    try {
      final path =
          'pets/${widget.petId}/historico-medico/$_registroId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await ref.read(anexoRepositoryProvider).upload(
            path: path,
            bytes: bytes,
            contentType: 'image/jpeg',
          );
      if (mounted) setState(() => _anexos = [..._anexos, url]);
    } catch (e) {
      if (mounted) {
        setState(() => _error = describirErroUpload(e, item: 'o anexo'));
      }
    } finally {
      if (mounted) setState(() => _enviandoAnexo = false);
    }
  }

  Future<void> _removerAnexo(String url) async {
    setState(() => _anexos = _anexos.where((anexo) => anexo != url).toList());
    try {
      await ref.read(anexoRepositoryProvider).delete(url);
    } catch (_) {
      // Anexo já foi removido da lista local; falha ao apagar do Storage
      // não impede o tutor de continuar (evita travar o formulário por um
      // problema de limpeza que pode ser tratado depois).
    }
  }

  Future<void> _handleSalvar() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final repository = ref.read(historicoMedicoRepositoryProvider);
    final registro = HistoricoMedico(
      id: _registroId,
      data: _dataController.text.trim(),
      descricao: _descricaoController.text.trim(),
      veterinario: _veterinarioController.text.trim(),
      anexos: _anexos,
    );

    try {
      if (widget.isEditing) {
        await repository.updateHistorico(widget.petId, registro);
      } else {
        await repository.createHistorico(widget.petId, registro);
      }
      // A lista via API é uma emissão única — força o recarregamento.
      ref.invalidate(historicoMedicoProvider(widget.petId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível salvar o histórico. Tente novamente.');
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
          widget.isEditing ? 'Editar histórico' : 'Novo registro',
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
                  controller: _dataController,
                  readOnly: true,
                  onTap: _pickData,
                  decoration: const InputDecoration(
                    hintText: 'Data:',
                    suffixIcon:
                        Icon(Icons.calendar_today, color: AppColors.textMuted),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe a data.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Descrição:'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe uma descrição.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _veterinarioController,
                  decoration: const InputDecoration(
                      hintText: 'Veterinário/clínica (opcional):'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Anexos (exames, fotos)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final anexo in _anexos)
                      _AnexoThumbnail(
                          url: anexo, onRemover: () => _removerAnexo(anexo)),
                    _AdicionarAnexoButton(
                        enviando: _enviandoAnexo, onTap: _adicionarAnexo),
                  ],
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

class _AnexoThumbnail extends StatelessWidget {
  const _AnexoThumbnail({required this.url, required this.onRemover});

  final String url;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.error),
            tooltip: 'Remover anexo',
            onPressed: onRemover,
          ),
        ),
      ],
    );
  }
}

class _AdicionarAnexoButton extends StatelessWidget {
  const _AdicionarAnexoButton({required this.enviando, required this.onTap});

  final bool enviando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enviando ? null : onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.4)),
        ),
        child: enviando
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.add_a_photo_outlined,
                color: AppColors.textMuted),
      ),
    );
  }
}
