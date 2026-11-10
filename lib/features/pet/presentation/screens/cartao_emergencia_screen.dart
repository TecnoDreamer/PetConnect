import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/cartao_emergencia.dart';
import '../../domain/pet.dart';
import '../../domain/telefone_de_contato.dart';
import '../providers/abrir_link_provider.dart';
import '../providers/cartao_emergencia_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_avatar.dart';

/// Leitura do Cartão de Emergência (issue #41, RF-41-01/02/04/05/08).
///
/// Privado: só o dono chega aqui (rota protegida por `PetSituacaoGuard` e
/// regras do Firestore). Com o pet no Memorial, a tela é só leitura.
class CartaoEmergenciaScreen extends ConsumerWidget {
  const CartaoEmergenciaScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (!ref.watch(cartaoEmergenciaDisponivelProvider)) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Cartão de Emergência')),
        body: const _Mensagem(
          icone: Icons.info_outline,
          texto: 'O Cartão de Emergência ainda não está disponível nesta '
              'versão do app.',
        ),
      );
    }
    final pet = ref.watch(petProvider(petId)).valueOrNull;
    final leitura = ref.watch(cartaoEmergenciaProvider(petId));
    final podeEditar = pet != null && !pet.falecido;
    final atual = leitura.valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Cartão de Emergência'),
        actions: [
          if (podeEditar && atual != null && !_semBase(atual))
            IconButton(
              tooltip: 'Editar cartão',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editar(context, atual.cartao),
            ),
        ],
      ),
      body: SafeArea(
        child: pet == null
            ? const Center(child: CircularProgressIndicator())
            : leitura.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (erro, _) => _Mensagem(
                  icone: Icons.cloud_off_outlined,
                  texto: erro is CartaoSemPermissao
                      ? 'Você não tem acesso a este cartão.'
                      : 'Não foi possível carregar o cartão agora. '
                          'Tente de novo em instantes.',
                  acao: erro is CartaoSemPermissao ? null : 'Tentar de novo',
                  aoTocar: () =>
                      ref.invalidate(cartaoEmergenciaProvider(petId)),
                ),
                data: (leitura) {
                  if (_semBase(leitura)) {
                    return const _Mensagem(
                      icone: Icons.cloud_off_outlined,
                      texto: 'Sem conexão, e o cartão ainda não foi baixado '
                          'neste aparelho. Conecte-se para ver o cartão.',
                    );
                  }
                  if (leitura.cartao.semDados) {
                    return _Vazio(
                      pet: pet,
                      podeEditar: podeEditar,
                      aoPreencher: () => _editar(context, leitura.cartao),
                    );
                  }
                  return _Cartao(pet: pet, leitura: leitura);
                },
              ),
      ),
    );
  }

  /// Offline e sem documento no cache: não dá para saber se o cartão está
  /// vazio. Mostrar "Preencher cartão" aqui poderia levar o tutor a
  /// sobrescrever um cartão que existe.
  static bool _semBase(LeituraDoCartao l) => l.doCacheLocal && !l.existe;

  void _editar(BuildContext context, CartaoEmergencia cartao) {
    context.push('/pet/$petId/emergencia/editar', extra: cartao);
  }
}

class _Cartao extends ConsumerWidget {
  const _Cartao({required this.pet, required this.leitura});

  final Pet pet;
  final LeituraDoCartao leitura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cartao = leitura.cartao;
    final usuario = ref.watch(currentUsuarioProvider).valueOrNull;
    final telefoneDoTutor = cartao.mostrarContatoDoTutor && usuario != null
        ? telefoneE164(usuario.telefone)
        : null;
    final vet = cartao.veterinario;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Identificacao(pet: pet),
        if (leitura.doCacheLocal) ...[
          const SizedBox(height: 12),
          _Aviso(
            texto: 'Sem conexão: mostrando a última versão salva neste '
                'aparelho.',
            cor: colors.textMuted,
          ),
        ],
        const SizedBox(height: 16),
        _Secao(
          titulo: 'Alergias conhecidas',
          icone: Icons.warning_amber_rounded,
          destaque: cartao.situacaoAlergias == SituacaoDaLista.informada,
          situacao: cartao.situacaoAlergias,
          nenhuma: 'Nenhuma conhecida (declarado pelo tutor)',
          itens: [
            for (final a in cartao.alergias)
              _Item(
                titulo: a.substancia,
                linhas: [
                  if (a.reacao.isNotEmpty) 'Reação: ${a.reacao}',
                  if (a.observacao.isNotEmpty) a.observacao,
                ],
              ),
          ],
        ),
        _Secao(
          titulo: 'Medicamentos em uso',
          icone: Icons.medication_outlined,
          situacao: cartao.situacaoMedicamentos,
          nenhuma: 'Nenhum em uso (declarado pelo tutor)',
          itens: [
            for (final m in cartao.medicamentos)
              _Item(
                titulo: m.nome,
                linhas: [
                  if (m.dose.isNotEmpty) 'Dose: ${m.dose}',
                  if (m.frequencia.isNotEmpty) 'Frequência: ${m.frequencia}',
                  if (m.via.isNotEmpty) 'Via: ${m.via}',
                  if (m.observacao.isNotEmpty) m.observacao,
                ],
              ),
          ],
        ),
        _Secao(
          titulo: 'Condições clínicas relevantes',
          icone: Icons.monitor_heart_outlined,
          situacao: cartao.situacaoCondicoes,
          nenhuma: 'Nenhuma conhecida (declarado pelo tutor)',
          itens: [
            for (final c in cartao.condicoes)
              _Item(titulo: c, linhas: const []),
          ],
        ),
        _SecaoTexto(
          titulo: 'Tipo sanguíneo',
          icone: Icons.bloodtype_outlined,
          texto: cartao.tipoSanguineo,
          nota: cartao.tipoSanguineo.isEmpty
              ? null
              : 'Confirmado por exame ou veterinário, segundo o tutor',
        ),
        _SecaoTexto(
          titulo: 'Observações de emergência',
          icone: Icons.sticky_note_2_outlined,
          texto: cartao.observacoes,
        ),
        _SecaoContato(
          titulo: 'Veterinário de confiança',
          icone: Icons.local_hospital_outlined,
          linhas: [
            if (vet.nome.isNotEmpty) vet.nome,
            if (vet.clinica.isNotEmpty) vet.clinica,
          ],
          telefone: vet.telefone.isEmpty ? null : telefoneE164(vet.telefone),
          rotuloLigar: 'Ligar para o veterinário',
        ),
        if (cartao.mostrarContatoDoTutor)
          _SecaoContato(
            titulo: 'Contato do tutor',
            icone: Icons.person_outline,
            linhas: [
              if (usuario != null && usuario.nome.isNotEmpty) usuario.nome
            ],
            telefone: telefoneDoTutor,
            rotuloLigar: 'Ligar para o tutor',
            semTelefone: 'Telefone não informado no seu perfil',
          ),
        const SizedBox(height: 8),
        if (cartao.atualizadoEm != null)
          Text(
            'Atualizado em ${_dataHora(cartao.atualizadoEm!)}',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        const SizedBox(height: 4),
        Text(
          'Informações fornecidas pelo tutor; confirme com o veterinário.',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  static String _dataHora(DateTime data) =>
      DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(data.toLocal());
}

class _Identificacao extends StatelessWidget {
  const _Identificacao({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detalhes = [pet.especie, pet.raca, pet.cor]
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join(' · ');
    return Semantics(
      header: true,
      label: 'Cartão de emergência de ${pet.nome}. $detalhes',
      child: ExcludeSemantics(
        child: Row(
          children: [
            PetAvatar(fotoUrl: pet.foto, radius: 32, nomeDoPet: pet.nome),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.nome,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (detalhes.isNotEmpty)
                    Text(detalhes,
                        style:
                            TextStyle(color: colors.textMuted, fontSize: 15)),
                  if (pet.falecido)
                    Text('No Memorial: somente leitura',
                        style:
                            TextStyle(color: colors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Moldura extends StatelessWidget {
  const _Moldura({
    required this.titulo,
    required this.icone,
    required this.child,
    this.destaque = false,
  });

  final String titulo;
  final IconData icone;
  final Widget child;

  /// Alergias informadas ganham uma borda: é o que mais importa numa
  /// urgência. Sem tela vermelha.
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: destaque
              ? Border.all(
                  color: colors.error.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Row(
                children: [
                  Icon(icone,
                      size: 20,
                      color: destaque ? colors.error : colors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item({required this.titulo, required this.linhas});

  final String titulo;
  final List<String> linhas;
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.titulo,
    required this.icone,
    required this.situacao,
    required this.nenhuma,
    required this.itens,
    this.destaque = false,
  });

  final String titulo;
  final IconData icone;
  final SituacaoDaLista situacao;
  final String nenhuma;
  final List<_Item> itens;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Moldura(
      titulo: titulo,
      icone: icone,
      destaque: destaque,
      child: switch (situacao) {
        SituacaoDaLista.naoInformado => _NaoInformado(),
        SituacaoDaLista.nenhumaDeclarada => Text(nenhuma,
            style: TextStyle(color: colors.textPrimary, fontSize: 15)),
        SituacaoDaLista.informada => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titulo,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      for (final linha in item.linhas)
                        Text(linha,
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 14)),
                    ],
                  ),
                ),
            ],
          ),
      },
    );
  }
}

class _SecaoTexto extends StatelessWidget {
  const _SecaoTexto({
    required this.titulo,
    required this.icone,
    required this.texto,
    this.nota,
  });

  final String titulo;
  final IconData icone;
  final String texto;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Moldura(
      titulo: titulo,
      icone: icone,
      child: texto.isEmpty
          ? _NaoInformado()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15)),
                if (nota != null)
                  Text(nota!,
                      style: TextStyle(color: colors.textMuted, fontSize: 13)),
              ],
            ),
    );
  }
}

class _SecaoContato extends ConsumerWidget {
  const _SecaoContato({
    required this.titulo,
    required this.icone,
    required this.linhas,
    required this.telefone,
    required this.rotuloLigar,
    this.semTelefone,
  });

  final String titulo;
  final IconData icone;
  final List<String> linhas;

  /// Em E.164, já validado; nulo sem número válido.
  final String? telefone;
  final String rotuloLigar;
  final String? semTelefone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vazio = linhas.isEmpty && telefone == null;
    return _Moldura(
      titulo: titulo,
      icone: icone,
      child: vazio && semTelefone == null
          ? _NaoInformado()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in linhas)
                  Text(linha,
                      style:
                          TextStyle(color: colors.textPrimary, fontSize: 15)),
                if (telefone != null) ...[
                  SelectableText(formatarTelefone(telefone!),
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined),
                    label: Text(rotuloLigar),
                    onPressed: () => _ligar(context, ref, telefone!),
                  ),
                ] else if (semTelefone != null)
                  Text(semTelefone!,
                      style: TextStyle(color: colors.textMuted, fontSize: 14)),
              ],
            ),
    );
  }

  /// Abre o discador com o número; quem liga é a pessoa.
  Future<void> _ligar(BuildContext context, WidgetRef ref, String e164) async {
    final abriu =
        await ref.read(abrirLinkProvider)(Uri(scheme: 'tel', path: e164));
    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível abrir o discador. Número: '
              '${formatarTelefone(e164)}'),
        ),
      );
    }
  }
}

class _NaoInformado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Não informado',
      style: TextStyle(
        color: context.colors.textMuted,
        fontSize: 15,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: cor),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(color: cor))),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({
    required this.pet,
    required this.podeEditar,
    required this.aoPreencher,
  });

  final Pet pet;
  final bool podeEditar;
  final VoidCallback aoPreencher;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Identificacao(pet: pet),
        const SizedBox(height: 32),
        Icon(Icons.medical_information_outlined,
            size: 48, color: colors.textMuted),
        const SizedBox(height: 16),
        Text(
          podeEditar
              ? 'Deixe à mão o que um veterinário precisa saber numa urgência: '
                  'alergias, medicamentos, condições e o contato de quem cuida '
                  'de ${pet.nome}.'
              : 'O cartão de ${pet.nome} não foi preenchido.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textPrimary, fontSize: 16),
        ),
        if (podeEditar) ...[
          const SizedBox(height: 8),
          Text(
            'Fica só no seu app. Nada disso aparece na página do QR Code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: aoPreencher,
            child: const Text('Preencher cartão'),
          ),
        ],
      ],
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({
    required this.icone,
    required this.texto,
    this.acao,
    this.aoTocar,
  });

  final IconData icone;
  final String texto;
  final String? acao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 40, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(texto,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, fontSize: 15)),
            if (acao != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: aoTocar, child: Text(acao!)),
            ],
          ],
        ),
      ),
    );
  }
}
