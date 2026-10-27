import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/consulta_alerta.dart';
import '../../domain/pet.dart';
import '../../domain/vacina_alerta.dart';
import '../providers/consulta_providers.dart';
import '../providers/vacina_providers.dart';
import 'pet_feature_card.dart';
import 'pet_qr_sheet.dart';

/// As 4 ações principais do perfil do pet, em grade 2x2 (RF15 + RF20-23 +
/// RF27-30 + RF16). Reaproveita a mesma lógica de alerta que já existia nos
/// botões antigos de vacina/consulta — só muda a apresentação, não a regra.
///
/// O card de QR abre, num bottom sheet, o [PetQrSheet]: o QR atual e a
/// opção de gerar um novo (RF19).
class PetFeatureGrid extends ConsumerWidget {
  const PetFeatureGrid({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacinasAsync = ref.watch(vacinasProvider(pet.id));
    final consultasAsync = ref.watch(consultasProvider(pet.id));
    final colors = context.colors;

    final vacinaAlerta = vacinasAsync.valueOrNull
            ?.any((vacina) => calcularAlerta(vacina) != VacinaAlerta.nenhum) ??
        false;
    final consultaAlerta = consultasAsync.valueOrNull
            ?.any((consulta) => consultaEstaProxima(consulta)) ??
        false;

    final vacinasCard = PetFeatureCard(
      icon:
          vacinaAlerta ? Icons.warning_amber_rounded : Icons.vaccines_outlined,
      title: 'Carteira de Vacinas',
      description: 'Consulte as vacinas aplicadas e próximas doses.',
      background: colors.petCardBackgrounds[0],
      accent: colors.petCardAccents[0],
      badge: vacinaAlerta,
      onTap: () => context.push('/pet/${pet.id}/vacinas'),
    );

    final consultasCard = PetFeatureCard(
      icon: consultaAlerta
          ? Icons.warning_amber_rounded
          : Icons.event_available_outlined,
      title: 'Agenda de Consultas',
      description: 'Veja e agende consultas do seu pet.',
      background: colors.petCardBackgrounds[1],
      accent: colors.petCardAccents[1],
      badge: consultaAlerta,
      onTap: () => context.push('/pet/${pet.id}/consultas'),
    );

    final historicoCard = PetFeatureCard(
      icon: Icons.medical_information_outlined,
      title: 'Histórico Médico',
      description: 'Acesse diagnósticos e tratamentos anteriores.',
      background: colors.petCardBackgrounds[2],
      accent: colors.petCardAccents[2],
      onTap: () => context.push('/pet/${pet.id}/historico'),
    );

    final qrCard = PetFeatureCard(
      icon: Icons.qr_code_2,
      title: 'QR Code do Pet',
      description: 'Acesse e compartilhe o perfil público do seu pet.',
      background: colors.petCardBackgrounds[3],
      accent: colors.petCardAccents[3],
      onTap: () => _abrirQrCode(context),
    );

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: vacinasCard),
              const SizedBox(width: 12),
              Expanded(child: consultasCard),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: historicoCard),
              const SizedBox(width: 12),
              Expanded(child: qrCard),
            ],
          ),
        ),
      ],
    );
  }

  void _abrirQrCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Com fonte ampliada o QR + ações passam da altura padrão do sheet;
      // o PetQrSheet rola por dentro.
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PetQrSheet(pet: pet),
        ),
      ),
    );
  }
}
