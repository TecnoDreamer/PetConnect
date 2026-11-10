// Testes de firestore.rules contra o Firestore Emulator (projeto demo,
// nunca o Firebase real). Rodar: `npm ci && npm test` nesta pasta (precisa
// de Java 21). No Windows deste projeto o emulador não sobe (loopback);
// o CI roda em Linux. Ver docs/security/firestore-isolamento-por-dono.md.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const ANA = 'ana-uid';
const BETO = 'beto-uid';
const SUBCOLECOES_CLINICAS = [
  'vacinas',
  'consultas',
  'historicoMedico',
  'localizacoes',
];
// Mesma lista que `subcolecoesApagadasComOPet`
// (lib/features/pet/data/exclusao_de_pet.dart), usada por deletePet e
// deleteAccount. `eventosSituacao` não está aqui: só sai no lote que apaga o
// pet. O Cartão de Emergência também não: é um documento só, apagado direto
// (`apagarCartaoDeEmergencia`), e as regras não deixam listar a subcoleção.
const SUBCOLECOES_LISTADAS_NA_EXCLUSAO = [...SUBCOLECOES_CLINICAS, 'fotos'];
// Tudo o que precisa sumir antes do pet.
const SUBCOLECOES_APAGADAS_COM_O_PET = [...SUBCOLECOES_LISTADAS_NA_EXCLUSAO, 'emergencia'];

// Mesma ordem que apagarSubcolecoesDoPet: cada subcoleção, um documento por
// vez; depois o Cartão de Emergência, sem listar.
async function apagarSubcolecoesComoOApp(db, petId) {
  for (const sub of SUBCOLECOES_LISTADAS_NA_EXCLUSAO) {
    const docs = await getDocs(collection(db, 'Pets', petId, sub));
    for (const d of docs.docs) {
      await deleteDoc(d.ref);
    }
  }
  await deleteDoc(doc(db, 'Pets', petId, 'emergencia', 'cartao'));
}

// Mesma ordem que FirebasePetRepository.deletePet: subcoleções, depois um
// lote com os eventos do Memorial e o pet.
async function apagarPetComoOApp(db, petId) {
  await apagarSubcolecoesComoOApp(db, petId);
  const pet = doc(db, 'Pets', petId);
  const batch = writeBatch(db);
  const eventos = await getDocs(collection(pet, 'eventosSituacao'));
  for (const evento of eventos.docs) {
    batch.delete(evento.ref);
  }
  batch.delete(pet);
  await batch.commit();
}

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-petconnect',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

// Dados sintéticos: Ana tem um pet ativo, um falecido e um legado
// (`userID`); Beto tem um pet ativo com registros em todas as subcoleções.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'Usuarios', ANA), { nome: 'Ana', usuarioID: ANA });
    await setDoc(doc(db, 'Usuarios', BETO), { nome: 'Beto', usuarioID: BETO });
    await setDoc(doc(db, 'Pets', 'petAna'), { userId: ANA, nome: 'Rex' });
    await setDoc(doc(db, 'Pets', 'petAnaFalecido'), {
      userId: ANA,
      nome: 'Mel',
      situacao: 'FALECIDO',
    });
    await setDoc(doc(db, 'Pets', 'petLegado'), { userID: ANA, nome: 'teste2' });
    await setDoc(doc(db, 'Pets', 'petBeto'), { userId: BETO, nome: 'Thor' });
    for (const sub of SUBCOLECOES_CLINICAS) {
      await setDoc(doc(db, 'Pets', 'petBeto', sub, 'r1'), { nota: 'b' });
      await setDoc(doc(db, 'Pets', 'petAna', sub, 'r1'), { nota: 'a' });
      await setDoc(doc(db, 'Pets', 'petAnaFalecido', sub, 'r1'), { nota: 'a' });
    }
    await setDoc(doc(db, 'Pets', 'petAna', 'eventosSituacao', 'e1'), {
      atorId: ANA,
      situacaoAnterior: 'ATIVO',
      situacaoNova: 'FALECIDO',
    });
    await setDoc(doc(db, 'Pets', 'petBeto', 'eventosSituacao', 'e1'), {
      atorId: BETO,
    });
    await setDoc(doc(db, 'Localizacoes', 'l1'), { petId: 'x' });
    for (const [petId, dono] of [
      ['petAna', ANA],
      ['petAnaFalecido', ANA],
      ['petBeto', BETO],
    ]) {
      await setDoc(doc(db, 'Pets', petId, 'fotos', 'f1'), fotoValida(petId, dono, 1));
      await setDoc(doc(db, 'Pets', petId, 'emergencia', 'cartao'), {
        ...cartaoValido(1),
        atualizadoEm: new Date(0),
      });
    }
  });
});

// Mesmo documento que FirebaseCartaoEmergenciaRepository.salvar grava.
function cartaoValido(revisao, atualizadoEm = serverTimestamp()) {
  return {
    versaoEsquema: 1,
    situacaoAlergias: 'INFORMADA',
    alergias: [{ id: 'a1', substancia: 'Dipirona', reacao: 'Vômito' }],
    situacaoMedicamentos: 'NENHUMA_DECLARADA',
    medicamentos: [],
    situacaoCondicoes: 'NAO_INFORMADO',
    condicoes: [],
    tipoSanguineo: 'DEA 1.1 positivo',
    tipoSanguineoConfirmado: true,
    observacoes: 'Morde quando sente dor.',
    veterinario: { nome: 'Dra. Exemplo', clinica: 'Clínica Exemplo', telefone: '+5519900000000' },
    mostrarContatoDoTutor: true,
    revisao,
    atualizadoEm,
  };
}

// Mesmo registro que FirebaseGaleriaRepository.publicar grava.
function fotoValida(petId, userId, criadoEm = serverTimestamp()) {
  return {
    petId,
    userId,
    url: `https://res.cloudinary.com/qgrx3f8s/image/upload/v1/users/${userId}/f.jpg`,
    publicId: `users/${userId}/f`,
    largura: 2048,
    altura: 1536,
    legenda: 'Na praia',
    criadoEm,
  };
}

const comoAna = () => env.authenticatedContext(ANA).firestore();
const comoBeto = () => env.authenticatedContext(BETO).firestore();
const anonimo = () => env.unauthenticatedContext().firestore();

// Mesma escrita que FirebasePetRepository.alterarSituacao faz.
function alterarSituacao(db, petId, { anterior, nova, atorId }) {
  return runTransaction(db, async (tx) => {
    const ref = doc(db, 'Pets', petId);
    await tx.get(ref);
    tx.update(ref, { situacao: nova, situacaoAtualizadaEm: serverTimestamp() });
    tx.set(doc(collection(ref, 'eventosSituacao')), {
      atorId,
      situacaoAnterior: anterior,
      situacaoNova: nova,
      motivo: 'registro_falecimento',
      resultado: 'aplicado',
      origem: 'app',
      em: serverTimestamp(),
    });
  });
}

describe('Usuarios', () => {
  it('o usuário lê e altera o próprio perfil', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Usuarios', ANA)));
    await assertSucceeds(
      updateDoc(doc(comoAna(), 'Usuarios', ANA), { telefone: '1' }),
    );
  });

  it('cadastro grava o perfil com o payload do app (usuarioID, sem uid)', async () => {
    const db = env.authenticatedContext('nova-uid').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'Usuarios', 'nova-uid'), {
        usuarioID: 'nova-uid',
        nome: 'Nova',
        sobrenome: '',
        email: 'nova@example.test',
        telefone: '',
        dataNascimento: '',
        genero: '',
        foto: null,
      }),
    );
  });

  it('ninguém lê, cria, altera ou apaga o perfil de outro usuário', async () => {
    await assertFails(getDoc(doc(comoAna(), 'Usuarios', BETO)));
    await assertFails(getDocs(collection(comoAna(), 'Usuarios')));
    await assertFails(setDoc(doc(comoAna(), 'Usuarios', 'outra-uid'), { nome: 'x' }));
    await assertFails(updateDoc(doc(comoAna(), 'Usuarios', BETO), { nome: 'x' }));
    await assertFails(deleteDoc(doc(comoAna(), 'Usuarios', BETO)));
  });

  it('anônimo não lê perfis', async () => {
    await assertFails(getDoc(doc(anonimo(), 'Usuarios', ANA)));
  });
});

describe('Pets', () => {
  it('o tutor lê e lista os próprios pets (consulta do app por userId)', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Pets', 'petAna')));
    await assertSucceeds(
      getDocs(query(collection(comoAna(), 'Pets'), where('userId', '==', ANA))),
    );
  });

  it('não lê pet de outro tutor nem lista pets sem filtrar pelo dono', async () => {
    await assertFails(getDoc(doc(comoAna(), 'Pets', 'petBeto')));
    await assertFails(getDocs(collection(comoAna(), 'Pets')));
    await assertFails(
      getDocs(query(collection(comoAna(), 'Pets'), where('userId', '==', BETO))),
    );
  });

  it('anônimo não lê pets', async () => {
    await assertFails(getDoc(doc(anonimo(), 'Pets', 'petAna')));
  });

  it('cria pet só em nome próprio', async () => {
    await assertSucceeds(addDoc(collection(comoAna(), 'Pets'), { userId: ANA, nome: 'Novo' }));
    await assertFails(addDoc(collection(comoAna(), 'Pets'), { userId: BETO, nome: 'Novo' }));
    await assertFails(addDoc(collection(comoAna(), 'Pets'), { nome: 'Sem dono' }));
  });

  it('altera e apaga o próprio pet', async () => {
    await assertSucceeds(updateDoc(doc(comoAna(), 'Pets', 'petAna'), { nome: 'Rex 2' }));
    await assertSucceeds(deleteDoc(doc(comoAna(), 'Pets', 'petAna')));
  });

  it('apaga o pet na ordem do app: subcoleções e eventos, inclusive pet falecido', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'Pets', 'petAnaFalecido', 'eventosSituacao', 'e1'), {
        atorId: ANA,
        situacaoAnterior: 'ATIVO',
        situacaoNova: 'FALECIDO',
      });
    });
    for (const petId of ['petAna', 'petAnaFalecido']) {
      await assertSucceeds(apagarPetComoOApp(comoAna(), petId));
    }
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const petId of ['petAna', 'petAnaFalecido']) {
        for (const sub of [...SUBCOLECOES_APAGADAS_COM_O_PET, 'eventosSituacao']) {
          const restantes = await getDocs(collection(db, 'Pets', petId, sub));
          assert.equal(restantes.size, 0, `Pets/${petId}/${sub} ficou órfã`);
        }
        assert.equal((await getDoc(doc(db, 'Pets', petId))).exists(), false);
      }
      // Beto não foi tocado.
      assert.equal((await getDoc(doc(db, 'Pets', 'petBeto', 'eventosSituacao', 'e1'))).exists(), true);
    });
  });

  it('não apaga as subcoleções do pet de outro tutor', async () => {
    await assertFails(apagarPetComoOApp(comoAna(), 'petBeto'));
  });

  it('não altera nem apaga pet de outro tutor', async () => {
    await assertFails(updateDoc(doc(comoAna(), 'Pets', 'petBeto'), { nome: 'x' }));
    await assertFails(deleteDoc(doc(comoAna(), 'Pets', 'petBeto')));
  });

  it('só o dono grava a cópia do QR regenerado (qrPublicId)', async () => {
    const qr = { qrPublicId: 'qr-novo', qrRegeneradoEm: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(comoAna(), 'Pets', 'petAna'), qr));
    await assertFails(updateDoc(doc(comoBeto(), 'Pets', 'petAna'), qr));
  });

  it('não transfere o pet para outra conta', async () => {
    await assertFails(updateDoc(doc(comoAna(), 'Pets', 'petAna'), { userId: BETO }));
  });

  it('pet legado com `userID` continua do dono e só dele', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Pets', 'petLegado')));
    await assertFails(getDoc(doc(comoBeto(), 'Pets', 'petLegado')));
  });
});

describe('subcoleções clínicas', () => {
  for (const sub of SUBCOLECOES_CLINICAS) {
    describe(sub, () => {
      it('o dono lê, cria, altera e apaga', async () => {
        const db = comoAna();
        await assertSucceeds(getDocs(collection(db, 'Pets', 'petAna', sub)));
        await assertSucceeds(addDoc(collection(db, 'Pets', 'petAna', sub), { nota: 'n' }));
        await assertSucceeds(updateDoc(doc(db, 'Pets', 'petAna', sub, 'r1'), { nota: 'x' }));
        await assertSucceeds(deleteDoc(doc(db, 'Pets', 'petAna', sub, 'r1')));
      });

      it('outro tutor não lê nem escreve', async () => {
        const db = comoAna();
        await assertFails(getDocs(collection(db, 'Pets', 'petBeto', sub)));
        await assertFails(getDoc(doc(db, 'Pets', 'petBeto', sub, 'r1')));
        await assertFails(addDoc(collection(db, 'Pets', 'petBeto', sub), { nota: 'n' }));
        await assertFails(updateDoc(doc(db, 'Pets', 'petBeto', sub, 'r1'), { nota: 'x' }));
        await assertFails(deleteDoc(doc(db, 'Pets', 'petBeto', sub, 'r1')));
      });

      it('anônimo não lê', async () => {
        await assertFails(getDocs(collection(anonimo(), 'Pets', 'petAna', sub)));
      });

      it('pet falecido: lê e apaga, mas não cria nem altera', async () => {
        const db = comoAna();
        await assertSucceeds(getDocs(collection(db, 'Pets', 'petAnaFalecido', sub)));
        await assertFails(addDoc(collection(db, 'Pets', 'petAnaFalecido', sub), { nota: 'n' }));
        await assertFails(
          updateDoc(doc(db, 'Pets', 'petAnaFalecido', sub, 'r1'), { nota: 'x' }),
        );
        await assertSucceeds(deleteDoc(doc(db, 'Pets', 'petAnaFalecido', sub, 'r1')));
      });

      it('pet que não existe: negado', async () => {
        await assertFails(addDoc(collection(comoAna(), 'Pets', 'naoExiste', sub), { nota: 'n' }));
      });
    });
  }
});

describe('eventosSituacao (Memorial)', () => {
  it('registrar falecimento: pet + evento na mesma transação', async () => {
    await assertSucceeds(
      alterarSituacao(comoAna(), 'petAna', {
        anterior: 'ATIVO',
        nova: 'FALECIDO',
        atorId: ANA,
      }),
    );
  });

  it('corrigir marcação: FALECIDO → ATIVO com evento', async () => {
    await assertSucceeds(
      alterarSituacao(comoAna(), 'petAnaFalecido', {
        anterior: 'FALECIDO',
        nova: 'ATIVO',
        atorId: ANA,
      }),
    );
  });

  it('o dono lê os eventos; outro tutor não', async () => {
    await assertSucceeds(getDocs(collection(comoAna(), 'Pets', 'petAna', 'eventosSituacao')));
    await assertFails(getDocs(collection(comoAna(), 'Pets', 'petBeto', 'eventosSituacao')));
  });

  it('outro tutor não cria evento nem muda a situação', async () => {
    await assertFails(
      alterarSituacao(comoBeto(), 'petAna', {
        anterior: 'ATIVO',
        nova: 'FALECIDO',
        atorId: BETO,
      }),
    );
  });

  it('evento solto, sem mudança de situação no pet, é negado', async () => {
    await assertFails(
      addDoc(collection(comoAna(), 'Pets', 'petAna', 'eventosSituacao'), {
        atorId: ANA,
        situacaoAnterior: 'ATIVO',
        situacaoNova: 'FALECIDO',
        motivo: 'registro_falecimento',
        resultado: 'aplicado',
        origem: 'app',
        em: serverTimestamp(),
      }),
    );
  });

  it('evento com autor falso, situação divergente ou campo extra é negado', async () => {
    const tentativas = [
      { atorId: BETO },
      { situacaoAnterior: 'FALECIDO' },
      { situacaoNova: 'ATIVO' },
      { extra: 'x' },
    ];
    for (const diferenca of tentativas) {
      const db = comoAna();
      const ref = doc(db, 'Pets', 'petAna');
      const batch = writeBatch(db);
      batch.update(ref, { situacao: 'FALECIDO' });
      batch.set(doc(collection(ref, 'eventosSituacao')), {
        atorId: ANA,
        situacaoAnterior: 'ATIVO',
        situacaoNova: 'FALECIDO',
        motivo: 'registro_falecimento',
        resultado: 'aplicado',
        origem: 'app',
        em: serverTimestamp(),
        ...diferenca,
      });
      await assertFails(batch.commit());
    }
  });

  it('evento já gravado não pode ser alterado nem apagado avulso, nem pelo dono', async () => {
    const ref = doc(comoAna(), 'Pets', 'petAna', 'eventosSituacao', 'e1');
    await assertFails(updateDoc(ref, { situacaoNova: 'ATIVO' }));
    await assertFails(deleteDoc(ref));
  });

  it('o memorial (documento do pet falecido) continua legível pelo dono', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Pets', 'petAnaFalecido')));
  });
});

describe('fotos (galeria)', () => {
  it('o dono lista, lê, publica e exclui', async () => {
    const db = comoAna();
    await assertSucceeds(getDocs(collection(db, 'Pets', 'petAna', 'fotos')));
    await assertSucceeds(getDoc(doc(db, 'Pets', 'petAna', 'fotos', 'f1')));
    await assertSucceeds(
      setDoc(doc(db, 'Pets', 'petAna', 'fotos', 'f2'), fotoValida('petAna', ANA)),
    );
    await assertSucceeds(deleteDoc(doc(db, 'Pets', 'petAna', 'fotos', 'f1')));
  });

  it('legenda, largura e altura são opcionais', async () => {
    const { legenda, largura, altura, ...minima } = fotoValida('petAna', ANA);
    await assertSucceeds(setDoc(doc(comoAna(), 'Pets', 'petAna', 'fotos', 'f2'), minima));
  });

  it('pet no Memorial continua recebendo fotos', async () => {
    const db = comoAna();
    await assertSucceeds(
      setDoc(
        doc(db, 'Pets', 'petAnaFalecido', 'fotos', 'f2'),
        fotoValida('petAnaFalecido', ANA),
      ),
    );
    await assertSucceeds(getDocs(collection(db, 'Pets', 'petAnaFalecido', 'fotos')));
  });

  it('outro tutor não lista, lê, publica nem exclui', async () => {
    const db = comoAna();
    await assertFails(getDocs(collection(db, 'Pets', 'petBeto', 'fotos')));
    await assertFails(getDoc(doc(db, 'Pets', 'petBeto', 'fotos', 'f1')));
    await assertFails(
      setDoc(doc(db, 'Pets', 'petBeto', 'fotos', 'f2'), fotoValida('petBeto', ANA)),
    );
    await assertFails(
      setDoc(doc(db, 'Pets', 'petBeto', 'fotos', 'f2'), fotoValida('petBeto', BETO)),
    );
    await assertFails(deleteDoc(doc(db, 'Pets', 'petBeto', 'fotos', 'f1')));
  });

  it('anônimo não lista nem publica', async () => {
    const db = anonimo();
    await assertFails(getDocs(collection(db, 'Pets', 'petAna', 'fotos')));
    await assertFails(
      setDoc(doc(db, 'Pets', 'petAna', 'fotos', 'f2'), fotoValida('petAna', ANA)),
    );
  });

  it('pet que não existe: negado', async () => {
    await assertFails(
      setDoc(doc(comoAna(), 'Pets', 'naoExiste', 'fotos', 'f2'), fotoValida('naoExiste', ANA)),
    );
  });

  it('registro fora do formato é negado', async () => {
    const db = comoAna();
    const ref = doc(db, 'Pets', 'petAna', 'fotos', 'f2');
    const base = fotoValida('petAna', ANA);
    const invalidas = {
      'vínculo com outro pet': { ...base, petId: 'petBeto' },
      'autor falso': { ...base, userId: BETO },
      'URL fora do Cloudinary': { ...base, url: 'https://exemplo.com/image/upload/f.jpg' },
      'URL de arquivo que não é imagem': {
        ...base,
        url: 'https://res.cloudinary.com/qgrx3f8s/raw/upload/v1/f.pdf',
      },
      'sem publicId': (({ publicId, ...resto }) => resto)(base),
      'legenda longa': { ...base, legenda: 'x'.repeat(301) },
      'horário do aparelho': { ...base, criadoEm: new Date() },
      'campo extra': { ...base, curtidas: 10 },
      'largura não numérica': { ...base, largura: '2048' },
    };
    for (const dados of Object.values(invalidas)) {
      await assertFails(setDoc(ref, dados));
    }
  });

  it('registro não é alterado, nem pelo dono', async () => {
    await assertFails(
      updateDoc(doc(comoAna(), 'Pets', 'petAna', 'fotos', 'f1'), { legenda: 'outra' }),
    );
  });
});

// Mesma ordem de FirebaseUsuarioRepository.deleteAccount: as subcoleções de
// cada pet (`subcolecoesApagadasComOPet`) uma a uma; depois um lote só com os
// eventos do Memorial, os pets e o perfil.
async function excluirConta(db, uid) {
  const pets = await getDocs(query(collection(db, 'Pets'), where('userId', '==', uid)));
  for (const pet of pets.docs) {
    await apagarSubcolecoesComoOApp(db, pet.id);
  }
  const batch = writeBatch(db);
  for (const pet of pets.docs) {
    const eventos = await getDocs(collection(pet.ref, 'eventosSituacao'));
    for (const evento of eventos.docs) {
      batch.delete(evento.ref);
    }
    batch.delete(pet.ref);
  }
  batch.delete(doc(db, 'Usuarios', uid));
  await batch.commit();
}

describe('exclusão de conta (mesma ordem do app)', () => {
  it('apaga subcoleções, eventos, pets e o perfil, inclusive de pet falecido', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'Pets', 'petAnaFalecido', 'eventosSituacao', 'e1'), {
        atorId: ANA,
        situacaoAnterior: 'ATIVO',
        situacaoNova: 'FALECIDO',
      });
    });
    await assertSucceeds(excluirConta(comoAna(), ANA));

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const petId of ['petAna', 'petAnaFalecido']) {
        for (const sub of [...SUBCOLECOES_APAGADAS_COM_O_PET, 'eventosSituacao']) {
          const restantes = await getDocs(collection(db, 'Pets', petId, sub));
          assert.equal(restantes.size, 0, `Pets/${petId}/${sub} ficou órfã`);
        }
        assert.equal((await getDoc(doc(db, 'Pets', petId))).exists(), false);
      }
      assert.equal((await getDoc(doc(db, 'Usuarios', ANA))).exists(), false);
      // Beto não foi tocado.
      assert.equal((await getDoc(doc(db, 'Pets', 'petBeto', 'eventosSituacao', 'e1'))).exists(), true);
    });
  });

  it('evento só sai no lote que apaga o próprio pet ou o perfil', async () => {
    const db = comoAna();
    const evento = doc(db, 'Pets', 'petAna', 'eventosSituacao', 'e1');

    // Lote que apaga outro pet do mesmo tutor.
    const comOutroPet = writeBatch(db);
    comOutroPet.delete(evento);
    comOutroPet.delete(doc(db, 'Pets', 'petAnaFalecido'));
    await assertFails(comOutroPet.commit());

    // Perfil já apagado numa escrita anterior: o evento não sai depois.
    await assertSucceeds(deleteDoc(doc(db, 'Usuarios', ANA)));
    await assertFails(deleteDoc(evento));
  });

  it('pet apagado antes do lote: o evento não sai depois (a regra lê o pet)', async () => {
    const db = comoAna();
    await assertSucceeds(deleteDoc(doc(db, 'Pets', 'petAna')));
    await assertFails(deleteDoc(doc(db, 'Pets', 'petAna', 'eventosSituacao', 'e1')));
  });

  it('apagar o próprio pet ou perfil não libera eventos nem registros de outro tutor', async () => {
    const db = comoAna();
    const comEventoAlheio = writeBatch(db);
    comEventoAlheio.delete(doc(db, 'Pets', 'petBeto', 'eventosSituacao', 'e1'));
    comEventoAlheio.delete(doc(db, 'Pets', 'petAna'));
    comEventoAlheio.delete(doc(db, 'Usuarios', ANA));
    await assertFails(comEventoAlheio.commit());

    for (const sub of SUBCOLECOES_APAGADAS_COM_O_PET) {
      const id = { fotos: 'f1', emergencia: 'cartao' }[sub] ?? 'r1';
      await assertFails(deleteDoc(doc(db, 'Pets', 'petBeto', sub, id)));
    }
    await assertFails(deleteDoc(doc(db, 'Pets', 'petBeto')));
  });
});

describe('emergencia (Cartão de Emergência)', () => {
  const cartao = (db, petId, id = 'cartao') => doc(db, 'Pets', petId, 'emergencia', id);

  it('o dono lê, cria, altera e apaga', async () => {
    const db = comoAna();
    await assertSucceeds(getDoc(cartao(db, 'petAna')));
    await assertSucceeds(updateDoc(cartao(db, 'petAna'), cartaoValido(2)));
    await assertSucceeds(deleteDoc(cartao(db, 'petAna')));
    await assertSucceeds(setDoc(cartao(db, 'petAna'), cartaoValido(1)));
  });

  it('salvar como o app: transação lê a revisão e grava a seguinte', async () => {
    const db = comoAna();
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const atual = await tx.get(cartao(db, 'petAna'));
        tx.set(cartao(db, 'petAna'), cartaoValido(atual.data().revisao + 1));
      }),
    );
  });

  it('cartão mínimo, só com os campos obrigatórios, é aceito', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(cartao(ctx.firestore(), 'petAna'));
    });
    await assertSucceeds(
      setDoc(cartao(comoAna(), 'petAna'), {
        versaoEsquema: 1,
        revisao: 1,
        atualizadoEm: serverTimestamp(),
      }),
    );
  });

  it('edição a partir de versão velha não sobrescreve (revisão)', async () => {
    const db = comoAna();
    // No banco está a revisão 1: gravar 1 de novo, pular para 3 ou voltar
    // para 0 é negado; criar do zero com revisão diferente de 1 também.
    await assertFails(setDoc(cartao(db, 'petAna'), cartaoValido(1)));
    await assertFails(setDoc(cartao(db, 'petAna'), cartaoValido(3)));
    await assertFails(setDoc(cartao(db, 'petAna'), cartaoValido(0)));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(cartao(ctx.firestore(), 'petAna'));
    });
    await assertFails(setDoc(cartao(db, 'petAna'), cartaoValido(2)));
  });

  it('outro tutor não lê, cria, altera nem apaga', async () => {
    const db = comoAna();
    await assertFails(getDoc(cartao(db, 'petBeto')));
    await assertFails(getDocs(collection(db, 'Pets', 'petBeto', 'emergencia')));
    await assertFails(updateDoc(cartao(db, 'petBeto'), cartaoValido(2)));
    await assertFails(deleteDoc(cartao(db, 'petBeto')));
  });

  it('anônimo não lê nem escreve', async () => {
    const db = anonimo();
    await assertFails(getDoc(cartao(db, 'petAna')));
    await assertFails(updateDoc(cartao(db, 'petAna'), cartaoValido(2)));
  });

  it('pet falecido: lê e apaga, mas não altera', async () => {
    const db = comoAna();
    await assertSucceeds(getDoc(cartao(db, 'petAnaFalecido')));
    await assertFails(updateDoc(cartao(db, 'petAnaFalecido'), cartaoValido(2)));
    await assertSucceeds(deleteDoc(cartao(db, 'petAnaFalecido')));
    await assertFails(setDoc(cartao(db, 'petAnaFalecido'), cartaoValido(1)));
  });

  it('pet que não existe: negado', async () => {
    await assertFails(setDoc(cartao(comoAna(), 'naoExiste'), cartaoValido(1)));
    await assertFails(getDoc(cartao(comoAna(), 'naoExiste')));
  });

  it('só existe o documento `cartao`', async () => {
    await assertFails(setDoc(cartao(comoAna(), 'petAna', 'outro'), cartaoValido(1)));
    await assertFails(getDoc(cartao(comoAna(), 'petAna', 'outro')));
  });

  it('documento fora do formato é negado', async () => {
    const db = comoAna();
    const base = cartaoValido(2);
    const vinte = Array.from({ length: 20 }, (_, i) => ({ id: `a${i}`, substancia: 'x' }));
    const invalidos = {
      'campo extra': { ...base, dono: ANA },
      'versão de esquema diferente': { ...base, versaoEsquema: 2 },
      'horário do aparelho': { ...base, atualizadoEm: new Date() },
      'sem horário': (({ atualizadoEm, ...resto }) => resto)(base),
      'situação desconhecida': { ...base, situacaoAlergias: 'TALVEZ' },
      '21 alergias': { ...base, alergias: [...vinte, { id: 'a20', substancia: 'x' }] },
      'condições que não são lista': { ...base, condicoes: 'diabetes' },
      'observações com mais de 1000 caracteres': { ...base, observacoes: 'x'.repeat(1001) },
      'tipo sanguíneo com mais de 40 caracteres': { ...base, tipoSanguineo: 'x'.repeat(41) },
      'confirmação que não é booleana': { ...base, tipoSanguineoConfirmado: 'sim' },
      'veterinário com campo extra': { ...base, veterinario: { nome: 'x', email: 'x@x' } },
      'telefone do veterinário longo demais': {
        ...base,
        veterinario: { telefone: '+'.padEnd(21, '1') },
      },
      'revisão que não é número inteiro': { ...base, revisao: '2' },
    };
    for (const [motivo, dados] of Object.entries(invalidos)) {
      await assertFails(setDoc(cartao(db, 'petAna'), dados)).catch((erro) => {
        throw new Error(`${motivo}: ${erro.message}`);
      });
    }
    // O limite de 20 itens é aceito.
    await assertSucceeds(setDoc(cartao(db, 'petAna'), { ...base, alergias: vinte }));
  });
});

describe('sem catch-all', () => {
  it('coleção sem regra própria é negada para leitura e escrita', async () => {
    await assertFails(setDoc(doc(comoAna(), 'QualquerColecao', 'x'), { a: 1 }));
    await assertFails(getDoc(doc(comoAna(), 'QualquerColecao', 'x')));
  });

  it('subcoleção desconhecida de pet próprio é negada', async () => {
    await assertFails(setDoc(doc(comoAna(), 'Pets', 'petAna', 'outra', 'x'), { a: 1 }));
  });

  it('Localizacoes (legado): leitura só logado, escrita fechada', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Localizacoes', 'l1')));
    await assertFails(getDoc(doc(anonimo(), 'Localizacoes', 'l1')));
    await assertFails(setDoc(doc(comoAna(), 'Localizacoes', 'l2'), { petId: 'x' }));
    await assertFails(deleteDoc(doc(comoAna(), 'Localizacoes', 'l1')));
  });
});
