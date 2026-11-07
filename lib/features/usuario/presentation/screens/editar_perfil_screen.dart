import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../../../core/utils/foto_enviada.dart';
import '../../../../core/utils/upload_error.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../../../pet/presentation/providers/anexo_providers.dart';
import '../../domain/usuario.dart';
import '../providers/auth_providers.dart';

const _tamanhoMaximoFoto = 5 * 1024 * 1024; // 5MB — ver docs/seguranca.md.
const _generos = ['Homem', 'Mulher', 'Outro'];

/// Edição dos dados do tutor (RF08): nome, sobrenome, telefone, data de
/// nascimento, gênero e foto.
class EditarPerfilScreen extends ConsumerStatefulWidget {
  const EditarPerfilScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.usuario.nome);
  late final _sobrenomeController =
      TextEditingController(text: widget.usuario.sobrenome);
  late final _telefoneController =
      TextEditingController(text: widget.usuario.telefone);
  late final _nascimentoController =
      TextEditingController(text: widget.usuario.dataNascimento);
  late String? _genero =
      widget.usuario.genero.isNotEmpty ? widget.usuario.genero : null;
  late String? _foto = widget.usuario.foto;

  bool _enviandoFoto = false;
  Uint8List? _fotoLocal;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    _nascimentoController.dispose();
    super.dispose();
  }

  Future<void> _pickNascimento() async {
    final initial = parseBrDate(_nascimentoController.text) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _nascimentoController.text = formatBrDate(picked);
    }
  }

  Future<void> _escolherFoto() async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: ladoMaximoDaFoto,
      maxHeight: ladoMaximoDaFoto,
    );
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    if (bytes.length > _tamanhoMaximoFoto) {
      setState(() => _error = 'A foto excede o tamanho máximo de 5MB.');
      return;
    }

    // A foto escolhida aparece na hora; o envio segue por baixo.
    setState(() {
      _error = null;
      _fotoLocal = bytes;
      _enviandoFoto = true;
    });

    try {
      final path =
          'usuarios/${widget.usuario.id}/foto-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await ref
          .read(anexoRepositoryProvider)
          .upload(path: path, bytes: bytes, contentType: 'image/jpeg');
      await guardarFotoEnviadaNoCache(url, bytes);
      if (mounted) setState(() => _foto = url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fotoLocal = null;
          _error = describirErroUpload(e, item: 'a foto');
        });
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _handleSalvar() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    try {
      await ref.read(usuarioRepositoryProvider).updateUsuario(
            nome: _nomeController.text.trim(),
            sobrenome: _sobrenomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
            dataNascimento: _nascimentoController.text.trim(),
            genero: _genero ?? '',
            foto: _foto,
          );
      // Recarrega o perfil (a fonte via API é uma emissão única).
      ref.invalidate(currentUsuarioProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
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
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AvatarPicker(
                    fotoUrl: _foto,
                    fotoLocal: _fotoLocal,
                    enviando: _enviandoFoto,
                    placeholderIcon: Icons.person,
                    onTap: _escolherFoto,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(hintText: 'Nome:'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe seu nome.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sobrenomeController,
                  decoration: const InputDecoration(hintText: 'Sobrenome:'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Telefone:'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nascimentoController,
                  readOnly: true,
                  onTap: _pickNascimento,
                  decoration: InputDecoration(
                    hintText: 'Data de nascimento:',
                    suffixIcon:
                        Icon(Icons.calendar_today, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _genero,
                  decoration: const InputDecoration(hintText: 'Gênero:'),
                  items: _generos
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (value) => setState(() => _genero = value),
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
