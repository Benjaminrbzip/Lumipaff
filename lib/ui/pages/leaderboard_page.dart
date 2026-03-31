import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../widgets/main_navigation_bar.dart';
import '../../services/firebase_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  int _selectedTabIndex = 0; // 0: Taupe, 1: Catch, 2: Simon
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    String mode;
    bool isSimon = _selectedTabIndex == 2;
    if (_selectedTabIndex == 0) mode = 'lumi_taupe';
    else if (_selectedTabIndex == 1) mode = 'lumi_catch';
    else mode = 'lumi_simon';
    
    final db = FirebaseService();
    List<Map<String, dynamic>> results;
    if (isSimon) {
      results = await db.getTopLevels(mode);
    } else {
      results = await db.getTopScores(mode);
    }
    
    if (mounted) {
      setState(() {
        _leaderboardData = results;
        _isLoading = false;
      });
    }
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex == index) return;
        setState(() => _selectedTabIndex = index);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? kPrimaryButtonColor : kCyanColor,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? kPrimaryButtonColor : kCyanColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(int rank, String name, int scoreOrLevel, {int? level}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kCyanColor, width: 1.0),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedTabIndex == 1) // Afficher la colonne niveau pour Lumi Catch
            SizedBox(
              width: 50,
              child: Text(
                level != null ? 'Lvl $level' : '-',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
          SizedBox(
            width: 60,
            child: Text(
              '$scoreOrLevel',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundColor,
      bottomNavigationBar: const MainNavigationBar(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab('Lumi Taupe', 0),
                  const SizedBox(width: 12),
                  _buildTab('Lumi Catch', 1),
                  const SizedBox(width: 12),
                  _buildTab('Lumi Simon', 2),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(width: 44, child: Text('Rank', style: TextStyle(color: kCyanColor, fontSize: 16))),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Player', style: TextStyle(color: kCyanColor, fontSize: 16))),
                  if (_selectedTabIndex == 1) // Lumi Catch
                    const SizedBox(width: 50, child: Text('Lvl', style: TextStyle(color: kCyanColor, fontSize: 16))),
                  SizedBox(
                    width: 60, 
                    child: Text(_selectedTabIndex == 2 ? 'Level' : 'Score', style: const TextStyle(color: kCyanColor, fontSize: 16), textAlign: TextAlign.right)
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: kCyanColor))
                : _leaderboardData.isEmpty 
                  ? const Center(child: Text('Aucun score pour le moment', style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      itemCount: _leaderboardData.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _leaderboardData[index];
                        final val = _selectedTabIndex == 2 ? item['level'] ?? 0 : item['score'] ?? 0;
                        return _buildScoreRow(index + 1, item['username'] ?? 'Joueur', val, level: item['level']);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
