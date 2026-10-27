import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/usuario.dart';
import '../domain/usuario_repository.dart';

/// Subcoleções de cada pet apagadas por [FirebaseUsuarioRepository.deleteAccount]
/// antes do próprio pet (LGPD, RF09/RNF13).
///
/// `eventosSituacao` (auditoria do Memorial) fica de fora: `firestore.rules`
/// nega `delete` nela, inclusive para o dono. Apagar ou reter esses eventos é
/// decisão pendente do proprietário (ver
/// docs/security/firestore-isolamento-por-dono.md).
const subcolecoesApagadasNaExclusaoDeConta = [
  'vacinas',
  'consultas',
  'historicoMedico',
  'localizacoes',
];

class FirebaseUsuarioRepository implements UsuarioRepository {
  FirebaseUsuarioRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('Usuarios');

  @override
  Stream<Usuario?> watchUsuario(String uid) {
    return _usuarios.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return Usuario.fromMap(doc.id, data);
    });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    // usuarioID reaproveita o uid por ora — a modelagem original tinha um
    // UUID separado cujo uso ainda não foi confirmado (ver
    // docs/modelo-dados-firestore.md).
    await _usuarios.doc(uid).set({
      'usuarioID': uid,
      'nome': nome,
      'sobrenome': '',
      'email': email,
      'telefone': telefone,
      'dataNascimento': dataNascimento,
      'genero': '',
      'foto': null,
    });
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> updateUsuario({
    required String nome,
    required String sobrenome,
    required String telefone,
    required String dataNascimento,
    required String genero,
    String? foto,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _usuarios.doc(uid).update({
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
      'dataNascimento': dataNascimento,
      'genero': genero,
      if (foto != null) 'foto': foto,
    });
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser!;
    final uid = user.uid;

    final pets = await _firestore
        .collection('Pets')
        .where('userId', isEqualTo: uid)
        .get();
    for (final pet in pets.docs) {
      for (final sub in subcolecoesApagadasNaExclusaoDeConta) {
        await _deleteSubcollection(pet.reference.collection(sub));
      }
      await pet.reference.delete();
    }

    await _usuarios.doc(uid).delete();
    await user.delete();
  }

  Future<void> _deleteSubcollection(
      CollectionReference<Map<String, dynamic>> collection) async {
    final docs = await collection.get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
  }
}
