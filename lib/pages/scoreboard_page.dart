import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_frontend/utils.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

class ScoreboardPage extends StatelessWidget {
  final String gameId;
  final String gameName;

  const ScoreboardPage({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  Color _parseColorFromHex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h'; // add alpha
    if (h.length != 8) return Colors.transparent;
    try {
      final v = int.parse(h, radix: 16);
      return Color(v);
    } catch (_) {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsesRef = FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .collection('responses');

    final gameDocStream = FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: gameDocStream,
      builder: (context, gameSnap) {
        if (gameSnap.hasError)
          return Center(child: Text('Error: ${gameSnap.error}'));
        final gameData = gameSnap.data?.data();
        final backgroundImage =
            (gameData != null && gameData['backgroundImage'] is String)
            ? (gameData['backgroundImage'] as String)
            : null;
        final bottomLeftImage =
            (gameData != null && gameData['bottomLeftImage'] is String)
            ? (gameData['bottomLeftImage'] as String)
            : null;
        final bottomRightImage =
            (gameData != null && gameData['bottomRightImage'] is String)
            ? (gameData['bottomRightImage'] as String)
            : null;
        final primaryHex =
            (gameData != null && gameData['primaryColor'] is String)
            ? (gameData['primaryColor'] as String)
            : null;

        final baseTheme = Theme.of(context);
        final resolvedPrimary = (primaryHex != null && primaryHex.isNotEmpty)
            ? _parseColorFromHex(primaryHex)
            : baseTheme.colorScheme.primary;

        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: resolvedPrimary,
            ),
          ),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(title: Text('Scoreboard')),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: responsesRef.snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs;
                var entries = docs.map((d) {
                  final data = d.data();
                  final name =
                      (data['userName'] ?? data['userEmail'] ?? 'Unknown')
                          .toString();
                  final score = data.containsKey('score')
                      ? (data['score'] as num?)?.toInt()
                      : null;
                  return {'id': d.id, 'name': name, 'score': score};
                }).toList();

                entries.sort((a, b) {
                  final sa = a['score'] as int?;
                  final sb = b['score'] as int?;
                  if (sa == null && sb == null) return 0;
                  if (sa == null) return 1;
                  if (sb == null) return -1;
                  return sb.compareTo(sa);
                });

                // Always render the themed Stack (background, overlays, corner images).
                // If there are no entries, show a placeholder inside the list area so
                // the background and images remain visible.
                //
                // Do not early-return here.

                return Stack(
                  children: [
                    if (backgroundImage != null && backgroundImage.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          backgroundImage,
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.7),
                          colorBlendMode: BlendMode.darken,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              'Scoreboard background load failed: $backgroundImage -> $error',
                            );
                            return Container(color: Colors.black26);
                          },
                        ),
                      ),
                    if (primaryHex != null && primaryHex.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          color: _parseColorFromHex(
                            primaryHex,
                          ).withOpacity(0.08),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12.0,
                        bottom: 12.0,
                        left: isLandscape(context)
                            ? MediaQuery.of(context).size.width * 0.2
                            : MediaQuery.of(context).size.width * 0.05,
                        right: isLandscape(context)
                            ? MediaQuery.of(context).size.width * 0.2
                            : MediaQuery.of(context).size.width * 0.05,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(90),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Text(
                                        gameName,
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.07,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        'Leaderboard',
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.02,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.7,
                                  child: entries.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No one played yet.',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(12),
                                          itemBuilder: (context, i) {
                                            final e = entries[i];
                                            final rank = i + 1;
                                            final name = e['name'] as String;
                                            final score = e['score'] as int?;
                                            return Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      resolvedPrimary,
                                                  child: Text(rank.toString()),
                                                ),
                                                title: Text(name),
                                                trailing: Text(
                                                  score != null
                                                      ? score.toString()
                                                      : 'Yet to play',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: score != null
                                                        ? Colors.white
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          itemCount: entries.length,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (bottomLeftImage != null && bottomLeftImage.isNotEmpty)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Image.network(
                          bottomLeftImage,
                          width:
                              MediaQuery.of(context).size.height <
                                  MediaQuery.of(context).size.width
                              ? MediaQuery.of(context).size.height * 0.4
                              : MediaQuery.of(context).size.width * 0.5,
                          height:
                              MediaQuery.of(context).size.height <
                                  MediaQuery.of(context).size.width
                              ? MediaQuery.of(context).size.height * 0.4
                              : MediaQuery.of(context).size.width * 0.5,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              'Scoreboard bottom-left load failed: $bottomLeftImage -> $error',
                            );
                            return const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(child: Icon(Icons.broken_image)),
                            );
                          },
                        ),
                      ),
                    if (bottomRightImage != null && bottomRightImage.isNotEmpty)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Image.network(
                          bottomRightImage,
                          width:
                              MediaQuery.of(context).size.height <
                                  MediaQuery.of(context).size.width
                              ? MediaQuery.of(context).size.height * 0.4
                              : MediaQuery.of(context).size.width * 0.5,
                          height:
                              MediaQuery.of(context).size.height <
                                  MediaQuery.of(context).size.width
                              ? MediaQuery.of(context).size.height * 0.4
                              : MediaQuery.of(context).size.width * 0.5,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              'Scoreboard bottom-right load failed: $bottomRightImage -> $error',
                            );
                            return const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(child: Icon(Icons.broken_image)),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
