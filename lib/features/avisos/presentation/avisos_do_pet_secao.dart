import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/settings_menu_tile.dart';
import '../domain/aviso_do_qr.dart';
import 'avisos_providers.dart';

/// "Avisos no celular" da tela Compartilhamento via QR Code (issue #36): o
/// tutor liga e desliga o aviso de acesso e o de avistamento deste pet, e vê
/// se o Android está deixando o app mostrar notificações.
///
/// Vale com ou sem página publicada: sem consentimento, a página mostra o
/// mínimo neutro, mas quem achar o pet ainda consegue relatar.
class AvisosDoPetSecao extends ConsumerStatefulWidget {
  const AvisosDoPetSecao({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<AvisosDoPetSecao> createState() => _AvisosDoPetSecaoState();
}

class _AvisosDoPetSecaoState extends ConsumerState<AvisosDoPetSecao> {
  PreferenciasDeAviso? _editando;
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar(PreferenciasDeAviso nova) async {
    final repo = ref.read(avisosRepositoryProvider);
    if (repo == null) return;
    final anterior = _editando;
    setState(() {
      _editando = nova;
      _salvando = true;
      _erro = null;
    });
    try {
      final salva = await repo.salvarPreferencias(widget.petId, nova);
      if (mounted) setState(() => _editando = salva);
    } catch (_) {
      if (mounted) {
        setState(() {
          _editando = anterior;
          _erro = 'Não foi possível salvar agora. Tente de novo.';
        });
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(avisosRepositoryProvider) == null) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final preferenciasAsync =
        ref.watch(preferenciasDeAvisoProvider(widget.petId));
    final permissao = ref.watch(permissaoDeAvisoProvider).valueOrNull;

    final conteudo = preferenciasAsync.when<List<Widget>>(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: LinearProgressIndicator(),
        ),
      ],
      error: (_, __) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Não foi possível carregar os avisos.',
                    style: TextStyle(color: colors.error, fontSize: 13)),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(preferenciasDeAvisoProvider(widget.petId)),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ],
      data: (carregadas) {
        final p = _editando ?? carregadas;
        if (p == null) return const [];
        return [
          SwitchListTile(
            key: const ValueKey('avisar-acesso'),
            value: p.avisarAcesso,
            title: const Text('Quando a página do QR for aberta'),
            subtitle: const Text(
                'Um aviso a cada abertura da página. Abrir a página não confirma que alguém viu o pet.'),
            onChanged:
                _salvando ? null : (v) => _salvar(p.copyWith(avisarAcesso: v)),
          ),
          SwitchListTile(
            key: const ValueKey('avisar-avistamento'),
            value: p.avisarAvistamento,
            title: const Text('Quando alguém enviar um relato'),
            subtitle: const Text('Com ou sem a localização de quem encontrou.'),
            onChanged: _salvando
                ? null
                : (v) => _salvar(p.copyWith(avisarAvistamento: v)),
          ),
        ];
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Avisos no celular'),
        if (permissao == PermissaoDeAviso.negada)
          Padding(
            key: const ValueKey('notificacoes-negadas'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'As notificações do PetConnect estão desativadas neste aparelho. '
              'Para receber os avisos, ative em Configurações do Android > Apps > PetConnect > Notificações.',
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
        ...conteudo,
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(_erro!,
                style: TextStyle(color: colors.error, fontSize: 13)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'O aviso depende da internet e das configurações do celular e pode atrasar.',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
