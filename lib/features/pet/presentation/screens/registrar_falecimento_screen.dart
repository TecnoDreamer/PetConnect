import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/alteracao_situacao.dart';
import '../../domain/pet.dart';
import '../providers/pet_providers.dart';

/// Registro de falecimento (Memorial do Pet, ver
/// docs/features/memorial-pet.md). Acessível só pelas Configurações do Pet
/// — nunca pela Home —, explica o que acontece e pede confirmação
/// explícita antes de gravar.
class RegistrarFalecimentoScreen extends ConsumerStatefulWidget {
  const RegistrarFalecimentoScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<RegistrarFalecimentoScreen> createState() =>
      _RegistrarFalecimentoScreenState();
}

class _RegistrarFalecimentoScreenState
    extends ConsumerState<RegistrarFalecimentoScreen> {
  final _dataController = TextEditingController();
  final _homenagemController = TextEditingController();
  bool _salvando = false;

  static const limiteHomenagem = 280;

  @override
  void dispose() {
    _dataController.dispose();
    _homenagemController.dispose();
    super.dispose();
  }

  Future<void> _escolherData(Pet pet) async {
    final hoje = DateTime.now();
    final nascimento = parseBrDate(pet.dataNascimento);
    final escolhida = await showDatePicker(
      context: context,
      initialDate: parseBrDate(_dataController.text) ?? hoje,
      firstDate: nascimento ?? DateTime(hoje.year - 40),
      lastDate: hoje,
      helpText: 'Data do falecimento',
    );
    if (escolhida != null) {
      setState(() => _dataController.text = formatBrDate(escolhida));
    }
  }

  Future<void> _confirmar(Pet pet) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar registro'),
        content: Text(
          'Registrar o falecimento de ${pet.nome}? O perfil passa para o '
          'Memorial. Nenhum dado será apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmou != true || _salvando || !mounted) return;

    final atorId = ref.read(currentUsuarioProvider).valueOrNull?.id;
    if (atorId == null) return;

    // O guard da rota troca esta tela assim que o pet vira falecido, então
    // a navegação não pode depender de `mounted` depois do await.
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _salvando = true);
    try {
      await container.read(petRepositoryProvider).alterarSituacao(
            pet.id,
            AlteracaoDeSituacao.registrarFalecimento(
              dataFalecimento: _dataController.text,
              homenagem: _homenagemController.text,
            ),
            atorId: atorId,
          );
      container.invalidate(petsProvider);
      container.invalidate(petProvider(pet.id));
      router.go('/memorial/${pet.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível registrar agora. Nada foi alterado. Tente '
                  'novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = ref.watch(petProvider(widget.petId)).valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Registrar falecimento')),
      body: SafeArea(
        child: pet == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Sentimos muito por ${pet.nome}.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ao registrar o falecimento, o perfil de ${pet.nome} vira '
                    'um memorial privado, visível só para você, com as fotos '
                    'e as informações básicas.\n\n'
                    'A carteira de vacinas, as consultas, o histórico médico e '
                    'as demais ações deixam de aparecer. Nenhum dado é apagado: '
                    'se o registro for feito por engano, dá para corrigir '
                    'depois e tudo volta como estava.',
                    style: TextStyle(color: colors.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _dataController,
                    readOnly: true,
                    onTap: () => _escolherData(pet),
                    decoration: InputDecoration(
                      labelText: 'Data do falecimento (opcional)',
                      suffixIcon: _dataController.text.isEmpty
                          ? const Icon(Icons.calendar_today_outlined)
                          : IconButton(
                              tooltip: 'Limpar data',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_dataController.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _homenagemController,
                    maxLines: 4,
                    maxLength: limiteHomenagem,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Homenagem (opcional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _salvando ? null : () => _confirmar(pet),
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrar falecimento'),
                  ),
                ],
              ),
      ),
    );
  }
}
