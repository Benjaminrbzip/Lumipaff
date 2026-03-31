import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'auth_service.dart';

class FirebaseService {
  // Instance principale pour communiquer avec ta Realtime Database
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://lumipaff-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();

  /// 1. MÉTHODE POUR SAUVEGARDER UN SCORE/NIVEAU
  /// Appelle à la fin d'une partie.
  Future<void> saveScore({
    required String gameMode, // ex: 'lumi_taupe', 'lumi_catch', 'lumi_simon'
    int? score,
    int? level,
  }) async {
    try {
      final auth = AuthService();
      final user = auth.currentUser;
      if (user == null) return;
      
      final username = await auth.getUsername(user.uid);
      
      // .push() crée un nouvel ID unique à chaque partie
      DatabaseReference scoreRef = _db.child('leaderboards').child(gameMode).push();
      
      final data = <String, dynamic>{
        'userId': user.uid,
        'username': username,
        'timestamp': ServerValue.timestamp,
      };
      if (score != null) data['score'] = score;
      if (level != null) data['level'] = level;
      
      await scoreRef.set(data).timeout(const Duration(seconds: 5));
      print("Score/Niveau envoyé avec succès à Firebase !");
    } on TimeoutException catch (_) {
      print("Erreur : Délai d'attente dépassé lors de l'envoi.");
    } catch (e) {
      print("Erreur lors de l'envoi : $e");
    }
  }

  /// 2. MÉTHODE POUR RÉCUPÉRER LE CLASSEMENT PAR SCORE (TOP 50)
  Future<List<Map<String, dynamic>>> getTopScores(String gameMode) async {
    List<Map<String, dynamic>> topScores = [];
    try {
      DatabaseReference modeRef = _db.child('leaderboards').child(gameMode);
      
      // On demande toutes les données pour contourner l'erreur d'Index Firebase manquante
      DataSnapshot snapshot = await modeRef.get().timeout(const Duration(seconds: 15));

      if (snapshot.exists) {
        for (final DataSnapshot child in snapshot.children) {
          if (child.value is Map) {
            final map = child.value as Map;
            topScores.add({
              'userId': map['userId'] ?? child.key,
              'username': map['username'] ?? 'Joueur',
              'score': (map['score'] ?? 0) as int,
              'level': map['level'], // Optional
            });
          }
        }
        
        // Firebase trie du plus petit au plus grand, on inverse
        topScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        if (topScores.length > 50) {
          topScores = topScores.sublist(0, 50);
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des scores : $e");
      topScores.add({
        'userId': 'error',
        'username': 'Erreur : ${e.toString().split('\n').first}',
        'score': 0,
      });
    }
    return topScores;
  }

  /// 3. MÉTHODE POUR RÉCUPÉRER LE CLASSEMENT PAR NIVEAU (TOP 50)
  Future<List<Map<String, dynamic>>> getTopLevels(String gameMode) async {
    List<Map<String, dynamic>> topLevels = [];
    try {
      DatabaseReference modeRef = _db.child('leaderboards').child(gameMode);
      
      DataSnapshot snapshot = await modeRef.get().timeout(const Duration(seconds: 15));

      if (snapshot.exists) {
        for (final DataSnapshot child in snapshot.children) {
          if (child.value is Map) {
            final map = child.value as Map;
            topLevels.add({
              'userId': map['userId'] ?? child.key,
              'username': map['username'] ?? 'Joueur',
              'score': map['score'], // Optional
              'level': (map['level'] ?? 0) as int,
            });
          }
        }
        
        topLevels.sort((a, b) => (b['level'] as int).compareTo(a['level'] as int));
        if (topLevels.length > 50) {
          topLevels = topLevels.sublist(0, 50);
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des niveaux : $e");
      topLevels.add({
        'userId': 'error',
        'username': 'Erreur : ${e.toString().split('\n').first}',
        'level': 0,
      });
    }
    return topLevels;
  }
}