import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/login_social.dart';
import '../domain/usuario.dart';
import '../domain/usuario_repository.dart';
import 'entrada_social.dart';
import 'provedores_sociais.dart';

class FirebaseUsuarioRepository implements UsuarioRepository {
  FirebaseUsuarioRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    Map<ProvedorSocial, ProvedorDeCredencial> provedores = const {},
  })  : _auth = auth,
        _firestore = firestore {
    _social = EntradaSocial(
      auth: auth,
      provedores: provedores,
      aposEntrar: _garantirPerfil,
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  late final EntradaSocial _social;

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
  Future<void> entrarComProvedor(ProvedorSocial provedor) =>
      _social.entrar(provedor);

  @override
  Future<void> entrarComSenhaEVincular({
    required String email,
    required String senha,
    required ContaExisteComOutroMetodo pendente,
  }) =>
      _social.entrarComSenhaEVincular(
          email: email, senha: senha, pendente: pendente);

  /// Primeiro login social: cria `Usuarios/{uid}` com o que o provedor
  /// informa (nome e e-mail). Telefone e nascimento ficam vazios, como em
  /// contas antigas, e o tutor completa em Editar perfil. A foto do
  /// provedor não é copiada. Se o perfil já existe (conta por e-mail ou
  /// outro provedor), nada é alterado.
  Future<void> _garantirPerfil(User user) async {
    final doc = _usuarios.doc(user.uid);
    if ((await doc.get()).exists) return;

    final partes = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
    await doc.set({
      'usuarioID': user.uid,
      'nome': partes.first,
      'sobrenome': partes.skip(1).join(' '),
      'email': user.email ?? '',
      'telefone': '',
      'dataNascimento': '',
      'genero': '',
      'foto': null,
    });
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _social.sairDosProvedores();
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
      await _deleteSubcollection(pet.reference.collection('vacinas'));
      await _deleteSubcollection(pet.reference.collection('historicoMedico'));
      await _deleteSubcollection(pet.reference.collection('fotos'));
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
