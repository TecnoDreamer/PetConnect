import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/settings_menu_tile.dart';
import '../../../avisos/presentation/avisos_do_pet_secao.dart';
import '../../../usuario/domain/usuario.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/compartilhamento_publico.dart';
import '../../domain/pet.dart';
import '../../domain/telefone_de_contato.dart';
import '../providers/pet_providers.dart';

/// Configurações do pet > Compartilhamento via QR Code (issue #35).
///
/// O tutor escolhe, campo a campo, o que aparece para quem escanear o QR e
/// marca o consentimento ao publicar. Nenhuma caixa vem marcada numa página
/// nova, e a caixa de consentimento vem desmarcada toda vez que a tela abre:
/// cada publicação é um consentimento novo. O telefone de contato é só da
/// página: editar aqui não muda o telefone do perfil.
class CompartilhamentoQrScreen extends ConsumerWidget {
  const CompartilhamentoQrScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final petAsync = ref.watch(petProvider(petId));
    final repo = ref.watch(compartilhamentoRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Compartilhamento via QR Code')),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Mensagem('Não foi possível carregar este pet.',
              cor: colors.error),
          data: (pet) {
            if (pet == null) return const _Mensagem('Pet não encontrado.');
            if (repo == null) {
              return const _Mensagem(
                  'A página pública do QR precisa do servidor do PetConnect, '
                  'que não está configurado nesta versão do app.');
            }
            return _Formulario(pet: pet, repo: repo);
          },
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem(this.texto, {this.cor});

  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: cor ?? context.colors.textMuted)),
        ),
      );
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.pet, required this.repo});

  final Pet pet;
  final CompartilhamentoRepository repo;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  CompartilhamentoPublico? _salvo;
  String? _erroAoCarregar;
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  String? _aviso;

  final _campos = <CampoPublico>{};
  bool _consentiu = false;
  final _nomeTutor = TextEditingController();
  final _telefone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nomeTutor.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroAoCarregar = null;
    });
    try {
      // O perfil sugere o nome e o telefone; sem ele, os campos vêm vazios.
      final perfil = ref
          .read(currentUsuarioProvider.future)
          .timeout(const Duration(seconds: 3))
          .then<Usuario?>((u) => u, onError: (_) => null);
      final salvo = await widget.repo.buscar(widget.pet);
      final usuario = await perfil;
      if (!mounted) return;
      setState(() {
        _salvo = salvo;
        _campos
          ..clear()
          ..addAll(salvo.ativo ? salvo.campos : const {});
        _nomeTutor.text = salvo.nomeTutor ?? usuario?.nome.trim() ?? '';
        final telefone = salvo.telefone ?? usuario?.telefone ?? '';
        final e164 = telefoneE164(telefone);
        _telefone.text = e164 != null ? formatarTelefone(e164) : telefone;
        _carregando = false;
      });
    } on CompartilhamentoException catch (e) {
      if (mounted) {
        setState(() {
          _erroAoCarregar = e.mensagem;
          _carregando = false;
        });
      }
    }
  }

  String? get _erroNomeTutor {
    if (!_campos.contains(CampoPublico.nomeTutor)) return null;
    final nome = _nomeTutor.text.trim();
    if (nome.isEmpty) return 'Informe como seu nome vai aparecer.';
    if (nome.length > 60) return 'Use até 60 caracteres.';
    return null;
  }

  String? get _erroTelefone {
    if (!_campos.contains(CampoPublico.telefone)) return null;
    return telefoneE164(_telefone.text) == null
        ? 'Telefone inválido. Use DDD e número, por exemplo (19) 99999-0000.'
        : null;
  }

  bool get _podePublicar =>
      !_salvando &&
      _consentiu &&
      _campos.isNotEmpty &&
      _erroNomeTutor == null &&
      _erroTelefone == null;

  Future<void> _publicar() async {
    final ativoAntes = _salvo?.ativo ?? false;
    setState(() {
      _salvando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      final salvo = await widget.repo.publicar(
        widget.pet,
        PedidoDeCompartilhamento(
          campos: Set.of(_campos),
          nomeTutor: _nomeTutor.text.trim(),
          telefone: telefoneE164(_telefone.text),
        ),
      );
      if (!mounted) return;
      setState(() {
        _salvo = salvo;
        _consentiu = false;
        _aviso = ativoAntes
            ? 'Alterações salvas. A página já mostra os dados novos.'
            : 'Página pública ativada.';
      });
    } on CompartilhamentoException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _desativar() async {
    final colors = context.colors;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar página pública'),
        content: const Text(
            'Quem escanear o QR vai ver só que o pet está cadastrado e poderá '
            'avisar você pelo formulário. O telefone e o nome salvos para a '
            'página serão apagados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Desativar', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() {
      _salvando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      final salvo = await widget.repo.revogar(widget.pet);
      if (!mounted) return;
      setState(() {
        _salvo = salvo;
        _campos.clear();
        _consentiu = false;
        _aviso = 'Página pública desativada.';
      });
    } on CompartilhamentoException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erroAoCarregar != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erroAoCarregar!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _carregar, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    final salvo = _salvo!;
    final pet = widget.pet;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Situacao(salvo: salvo),
        const SettingsSectionHeader(title: 'O que aparece na página'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            'Marque só o que ajuda a devolver o pet. O que não estiver '
            'marcado não sai do PetConnect.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ),
        for (final campo in CampoPublico.values) ...[
          CheckboxListTile(
            key: ValueKey('campo-${campo.api}'),
            value: _campos.contains(campo),
            title: Text(campo.rotulo),
            subtitle: _detalheDo(campo, pet),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _salvando
                ? null
                : (marcado) => setState(() {
                      marcado == true
                          ? _campos.add(campo)
                          : _campos.remove(campo);
                    }),
          ),
          if (campo == CampoPublico.nomeTutor &&
              _campos.contains(CampoPublico.nomeTutor))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                key: const ValueKey('nome-tutor'),
                controller: _nomeTutor,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Como seu nome aparece',
                  errorText: _erroNomeTutor,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (campo == CampoPublico.telefone &&
              _campos.contains(CampoPublico.telefone))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('telefone'),
                    controller: _telefone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      hintText: '(19) 99999-0000',
                      errorText: _erroTelefone,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quem abrir a página vai ver este número. Ele vale só '
                    'para a página e não muda o telefone do seu perfil.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
        const SettingsSectionHeader(title: 'Prévia para quem escanear'),
        _Previa(
          pet: pet,
          campos: _campos,
          nomeTutor: _nomeTutor.text.trim(),
          telefone: telefoneE164(_telefone.text),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('consentimento'),
          value: _consentiu,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(textoDoConsentimento(pet.nome),
              style: const TextStyle(fontSize: 14)),
          onChanged: _salvando
              ? null
              : (marcado) => setState(() => _consentiu = marcado == true),
        ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(_erro!,
                style: TextStyle(color: colors.error, fontSize: 13)),
          ),
        if (_aviso != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(_aviso!,
                style: TextStyle(color: colors.success, fontSize: 13)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: FilledButton.icon(
            key: const ValueKey('publicar'),
            onPressed: _podePublicar ? _publicar : null,
            icon: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.public),
            label: Text(salvo.ativo ? 'Salvar alterações' : 'Publicar'),
          ),
        ),
        if (!_consentiu && _campos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text('Marque o consentimento para publicar.',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ),
        if (salvo.ativado)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: OutlinedButton.icon(
              key: const ValueKey('desativar'),
              onPressed: _salvando ? null : _desativar,
              icon: Icon(Icons.public_off, color: colors.error),
              label: Text('Desativar página pública',
                  style: TextStyle(color: colors.error)),
            ),
          ),
        AvisosDoPetSecao(petId: pet.id),
      ],
    );
  }

  Widget? _detalheDo(CampoPublico campo, Pet pet) {
    final texto = switch (campo) {
      CampoPublico.nomePet => pet.nome,
      CampoPublico.especie => pet.especie,
      CampoPublico.raca => pet.raca,
      CampoPublico.cor => pet.cor,
      CampoPublico.fotoPerfil =>
        (pet.foto ?? '').isEmpty ? 'Este pet ainda não tem foto' : null,
      CampoPublico.nomeTutor || CampoPublico.telefone => null,
    };
    if (texto == null) return null;
    return Text(texto.isEmpty ? 'Não preenchido no perfil' : texto);
  }
}

/// Se a página está mostrando dados agora e desde quando.
class _Situacao extends StatelessWidget {
  const _Situacao({required this.salvo});

  final CompartilhamentoPublico salvo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formato = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
    final String titulo;
    final String detalhe;
    if (salvo.ativo) {
      titulo = 'Página pública ativa';
      detalhe = salvo.consentidoEm == null
          ? 'Quem escanear o QR vê os dados marcados abaixo.'
          : 'Consentimento dado em ${formato.format(salvo.consentidoEm!)}.';
    } else if (salvo.ativado) {
      titulo = 'Página pública pausada';
      detalhe = 'O texto do consentimento mudou. Revise e publique de novo.';
    } else {
      titulo = 'Página pública desativada';
      detalhe = 'Quem escanear o QR vê só que o pet está cadastrado e pode '
          'avisar você pelo formulário da página.';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salvo.ativo ? Icons.public : Icons.public_off,
              color: salvo.ativo ? colors.success : colors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(detalhe,
                    style: TextStyle(color: colors.textMuted, fontSize: 13)),
                if (!salvo.ativo && salvo.revogadoEm != null) ...[
                  const SizedBox(height: 4),
                  Text('Desativada em ${formato.format(salvo.revogadoEm!)}.',
                      style: TextStyle(color: colors.textMuted, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// O que a página vai mostrar com as caixas marcadas agora.
class _Previa extends StatelessWidget {
  const _Previa({
    required this.pet,
    required this.campos,
    required this.nomeTutor,
    required this.telefone,
  });

  final Pet pet;
  final Set<CampoPublico> campos;
  final String nomeTutor;
  final String? telefone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linhas = <String>[
      if (campos.contains(CampoPublico.nomePet) && pet.nome.isNotEmpty)
        pet.nome,
      for (final (campo, valor) in [
        (CampoPublico.especie, pet.especie),
        (CampoPublico.raca, pet.raca),
        (CampoPublico.cor, pet.cor),
      ])
        if (campos.contains(campo) && valor.isNotEmpty)
          '${campo.rotulo}: $valor',
      if (campos.contains(CampoPublico.nomeTutor) && nomeTutor.isNotEmpty)
        'Tutor: $nomeTutor',
      if (campos.contains(CampoPublico.telefone) && telefone != null)
        'Contato: ${formatarTelefone(telefone!)}',
    ];
    final foto =
        campos.contains(CampoPublico.fotoPerfil) && (pet.foto ?? '').isNotEmpty
            ? pet.foto
            : null;

    return Container(
      key: const ValueKey('previa'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: linhas.isEmpty && foto == null
          ? Text(
              'Este pet está cadastrado no PetConnect.\n'
              'Formulário para avisar o tutor.',
              style: TextStyle(color: colors.textMuted),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (foto != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      foto,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 64, height: 64),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final linha in linhas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(linha,
                              style: TextStyle(color: colors.textPrimary)),
                        ),
                      Text('Formulário para avisar o tutor.',
                          style:
                              TextStyle(color: colors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
