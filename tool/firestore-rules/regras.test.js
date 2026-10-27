// Testes de firestore.rules contra o Firestore Emulator (projeto demo,
// nunca o Firebase real). Rodar: `npm ci && npm test` nesta pasta (precisa
// de Java 21). No Windows deste projeto o emulador não sobe (loopback);
// o CI roda em Linux. Ver docs/security/firestore-isolamento-por-dono.md.
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
  });
});

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

  it('não altera nem apaga pet de outro tutor', async () => {
    await assertFails(updateDoc(doc(comoAna(), 'Pets', 'petBeto'), { nome: 'x' }));
    await assertFails(deleteDoc(doc(comoAna(), 'Pets', 'petBeto')));
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

  it('evento já gravado não pode ser alterado nem apagado, nem pelo dono', async () => {
    const ref = doc(comoAna(), 'Pets', 'petAna', 'eventosSituacao', 'e1');
    await assertFails(updateDoc(ref, { situacaoNova: 'ATIVO' }));
    await assertFails(deleteDoc(ref));
  });

  it('o memorial (documento do pet falecido) continua legível pelo dono', async () => {
    await assertSucceeds(getDoc(doc(comoAna(), 'Pets', 'petAnaFalecido')));
  });
});

describe('exclusão de conta (mesma ordem do app)', () => {
  it('apaga subcoleções, pets e o perfil, inclusive de pet falecido', async () => {
    const db = comoAna();
    for (const petId of ['petAna', 'petAnaFalecido']) {
      for (const sub of ['vacinas', 'historicoMedico']) {
        await assertSucceeds(deleteDoc(doc(db, 'Pets', petId, sub, 'r1')));
      }
      await assertSucceeds(deleteDoc(doc(db, 'Pets', petId)));
    }
    await assertSucceeds(deleteDoc(doc(db, 'Usuarios', ANA)));
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
