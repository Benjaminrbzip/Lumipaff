import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://lumipaff-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();

  /// Current user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email, password, and username
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save username to Realtime Database
      if (credential.user != null) {
        try {
          await _db.child('users').child(credential.user!.uid).set({
            'username': username,
            'email': email,
            'createdAt': ServerValue.timestamp,
          }).timeout(const Duration(seconds: 10));

          // Also set Firebase Auth display name
          await credential.user!.updateDisplayName(username);
        } catch (e) {
          // Supprimer l'utilisateur si on ne peut pas l'enregistrer dans la base
          await credential.user!.delete();
          return 'Erreur de connexion à la base de données (Timeout). Vérifiez votre configuration Firebase.';
        }
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return '${_mapAuthError(e.code)}\nErreur tech: ${e.message}';
    } catch (e) {
      return 'Une erreur inattendue est survenue.';
    }
  }

  /// Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return '${_mapAuthError(e.code)}\nErreur tech: ${e.message}';
    } on TimeoutException catch (_) {
      return 'Délai d\'attente dépassé. Vérifiez votre connexion internet.';
    } catch (e) {
      return 'Une erreur inattendue est survenue.';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get username for a given uid
  Future<String> getUsername(String uid) async {
    try {
      final snapshot = await _db.child('users').child(uid).child('username').get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        return snapshot.value as String;
      }
    } catch (_) {}
    return 'Joueur';
  }

  /// Sauvegarder l'adresse MAC du pod associé
  Future<void> savePodMac(String mac) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _db.child('users').child(user.uid).child('podMac').set(mac)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Erreur sauvegarde podMac: $e');
    }
  }

  /// Récupérer l'adresse MAC du pod associé
  Future<String?> getPodMac() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final snapshot = await _db.child('users').child(user.uid).child('podMac').get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value as String;
      }
    } catch (_) {}
    return null;
  }

  /// Supprimer le pod associé
  Future<void> removePodMac() async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _db.child('users').child(user.uid).child('podMac').remove()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Erreur suppression podMac: $e');
    }
  }

  /// Map Firebase error codes to French messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Cette adresse email est déjà utilisée.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Le mot de passe est trop faible (min. 6 caractères).';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cette adresse.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-credential':
        return 'Identifiants invalides.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'operation-not-allowed':
        return 'Authentification par Email non activée dans la console Firebase.';
      default:
        return 'Erreur d\'authentification ($code).';
    }
  }
}
