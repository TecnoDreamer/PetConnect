import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/pet/domain/consulta.dart';
import '../features/pet/domain/historico_medico.dart';
import '../features/pet/domain/pet.dart';
import '../features/pet/domain/vacina.dart';
import '../features/pet/presentation/screens/cartaz_editor_screen.dart';
import '../features/pet/presentation/screens/cartaz_previa_screen.dart';
import '../features/pet/presentation/screens/consulta_form_screen.dart';
import '../features/pet/presentation/screens/consulta_list_screen.dart';
import '../features/pet/presentation/screens/galeria_screen.dart';
import '../features/pet/presentation/screens/historico_form_screen.dart';
import '../features/pet/presentation/screens/historico_list_screen.dart';
import '../features/pet/presentation/screens/localizacao_form_screen.dart';
import '../features/pet/presentation/screens/localizacao_list_screen.dart';
import '../features/pet/presentation/screens/memorial_list_screen.dart';
import '../features/pet/presentation/screens/memorial_screen.dart';
import '../features/pet/presentation/screens/memorial_settings_screen.dart';
import '../features/pet/presentation/screens/pet_detail_screen.dart';
import '../features/pet/presentation/screens/pet_form_screen.dart';
import '../features/pet/presentation/screens/pet_settings_screen.dart';
import '../features/pet/presentation/screens/registrar_falecimento_screen.dart';
import '../features/pet/presentation/screens/vacina_form_screen.dart';
import '../features/pet/presentation/screens/vacina_list_screen.dart';
import '../features/pet/presentation/widgets/pet_situacao_guard.dart';

/// Rotas de pet: perfil e recursos operacionais (só para pets ativos) e o
/// Memorial (só para pets falecidos). A proteção fica aqui, na rota — vale
/// para links diretos e antigos, não só para os botões da interface (ver
/// docs/features/memorial-pet.md).
List<GoRoute> buildPetRoutes() => [
      GoRoute(
        path: '/pet/novo',
        builder: (context, state) => const PetFormScreen(),
      ),
      GoRoute(
        path: '/pet/:id',
        builder: (context, state) => _soPetAtivo(
          state,
          PetDetailScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/editar',
        builder: (context, state) => _soPetAtivo(
          state,
          PetFormScreen(pet: state.extra as Pet?),
        ),
      ),
      GoRoute(
        path: '/pet/:id/configuracoes',
        builder: (context, state) => _soPetAtivo(
          state,
          PetSettingsScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/vacinas',
        builder: (context, state) => _soPetAtivo(
          state,
          VacinaListScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/vacinas/nova',
        builder: (context, state) => _soPetAtivo(
          state,
          VacinaFormScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/vacinas/:vacinaId/editar',
        builder: (context, state) => _soPetAtivo(
          state,
          VacinaFormScreen(
            petId: state.pathParameters['id']!,
            vacina: state.extra as Vacina?,
          ),
        ),
      ),
      GoRoute(
        path: '/pet/:id/historico',
        builder: (context, state) => _soPetAtivo(
          state,
          HistoricoListScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/historico/novo',
        builder: (context, state) => _soPetAtivo(
          state,
          HistoricoFormScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/historico/:historicoId/editar',
        builder: (context, state) => _soPetAtivo(
          state,
          HistoricoFormScreen(
            petId: state.pathParameters['id']!,
            historico: state.extra as HistoricoMedico?,
          ),
        ),
      ),
      GoRoute(
        path: '/pet/:id/consultas',
        builder: (context, state) => _soPetAtivo(
          state,
          ConsultaListScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/consultas/nova',
        builder: (context, state) => _soPetAtivo(
          state,
          ConsultaFormScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/consultas/:consultaId/editar',
        builder: (context, state) => _soPetAtivo(
          state,
          ConsultaFormScreen(
            petId: state.pathParameters['id']!,
            consulta: state.extra as Consulta?,
          ),
        ),
      ),
      GoRoute(
        path: '/pet/:id/localizacao',
        builder: (context, state) => _soPetAtivo(
          state,
          LocalizacaoListScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/localizacao/nova',
        builder: (context, state) => _soPetAtivo(
          state,
          LocalizacaoFormScreen(petId: state.pathParameters['id']!),
        ),
      ),
      // Galeria de fotos: pet ativo ou no Memorial, só do dono.
      GoRoute(
        path: '/pet/:id/fotos',
        builder: (context, state) => PetSituacaoGuard(
          petId: state.pathParameters['id']!,
          exige: null,
          child: GaleriaScreen(petId: state.pathParameters['id']!),
        ),
      ),
      // Cartaz de pet desaparecido: só pet ativo, só do dono.
      GoRoute(
        path: '/pet/:id/cartaz',
        builder: (context, state) => _soPetAtivo(
          state,
          CartazEditorScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/cartaz/previa',
        builder: (context, state) => _soPetAtivo(
          state,
          CartazPreviaScreen(petId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/pet/:id/falecimento',
        builder: (context, state) => _soPetAtivo(
          state,
          RegistrarFalecimentoScreen(petId: state.pathParameters['id']!),
        ),
      ),
      // Aninhadas (mesmos caminhos): um `go` para o memorial de um pet
      // monta a pilha lista → memorial, então o Voltar passa pela lista em
      // vez de esvaziar a pilha e fechar o app. A lista, na base, volta
      // para a Home (VoltarParaHome).
      GoRoute(
        path: '/memorial',
        builder: (context, state) => const MemorialListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => _soPetFalecido(
              state,
              MemorialScreen(petId: state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'configuracoes',
                builder: (context, state) => _soPetFalecido(
                  state,
                  MemorialSettingsScreen(petId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ];

/// Rotas operacionais de um pet (perfil, vacinas, consultas, histórico,
/// localização, edição, configurações) só abrem para pets ativos — também
/// por link direto, não só pelos botões (Memorial do Pet).
Widget _soPetAtivo(GoRouterState state, Widget tela) => PetSituacaoGuard(
      petId: state.pathParameters['id']!,
      exige: SituacaoPet.ativo,
      child: tela,
    );

Widget _soPetFalecido(GoRouterState state, Widget tela) => PetSituacaoGuard(
      petId: state.pathParameters['id']!,
      exige: SituacaoPet.falecido,
      child: tela,
    );
