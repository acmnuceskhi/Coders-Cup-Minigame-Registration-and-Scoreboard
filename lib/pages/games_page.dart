import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_frontend/models/form_field.dart'
    as model_field;
import 'package:coders_cup_minigame_frontend/models/game.dart';
import 'package:coders_cup_minigame_frontend/pages/game_page.dart';
import 'package:coders_cup_minigame_frontend/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final CollectionReference<Map<String, dynamic>> _gamesRef = FirebaseFirestore
      .instance
      .collection('games')
      .withConverter(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACM Activities')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _gamesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No games found.'));
          }

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = isLandscape(context)
              ? 4
              : (width ~/ 220).clamp(1, 4);

          return GridView.builder(
            padding: EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: isLandscape(context)
                  ? MediaQuery.of(context).size.width * 0.12
                  : MediaQuery.of(context).size.width * 0.05,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 4,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              // Parse fields defensively
              final id = doc.id;
              final name = (data['name'] as String?) ?? 'Unnamed Game';

              int? limit;
              try {
                final rawLimit = data['limit'];
                if (rawLimit is int) {
                  limit = rawLimit;
                } else if (rawLimit is double) {
                  limit = rawLimit.toInt();
                } else if (rawLimit is String) {
                  limit = int.tryParse(rawLimit);
                }
              } catch (_) {
                limit = null;
              }

              // Parse formFields if present
              final List<model_field.FormField> formFields = [];
              try {
                final rawFields = data['formFields'];
                if (rawFields is Iterable) {
                  for (final f in rawFields) {
                    if (f is Map<String, dynamic>) {
                      final label = (f['label'] as String?) ?? '';
                      final type = (f['type'] as String?) ?? '';
                      final req = (f['required'] as bool?) ?? false;
                      formFields.add(
                        model_field.FormField(
                          label: label,
                          type: type,
                          required: req,
                        ),
                      );
                    } else if (f is Map) {
                      final label = (f['label']?.toString()) ?? '';
                      final type = (f['type']?.toString()) ?? '';
                      final req = (f['required']?.toString() == 'true');
                      formFields.add(
                        model_field.FormField(
                          label: label,
                          type: type,
                          required: req,
                        ),
                      );
                    }
                  }
                }
              } catch (_) {
                // ignore parsing errors, leave empty
              }

              final codeBased = (data['codeBased'] as bool?) ?? false;
              final game = Game(
                id: id,
                name: name,
                limit: limit,
                codeBased: codeBased,
                backgroundImage: (data['backgroundImage'] as String?)?.trim(),
                bottomLeftImage: (data['bottomLeftImage'] as String?)?.trim(),
                bottomRightImage: (data['bottomRightImage'] as String?)?.trim(),
                primaryColor: (data['primaryColor'] as String?)?.trim(),
              );
              game.formFields = formFields;

              return _HoverGameCard(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => GamePage(game: game))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // image area
                    Expanded(
                      flex: 6,
                      child:
                          game.backgroundImage != null &&
                              game.backgroundImage!.isNotEmpty
                          ? Image.network(
                              game.backgroundImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircleAvatar(
                                  backgroundColor:
                                      game.primaryColor != null &&
                                          game.primaryColor!.isNotEmpty
                                      ? _parseColorFromHex(game.primaryColor!)
                                      : Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    game.name.isNotEmpty
                                        ? game.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    // lower info area
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              game.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Limit of Regs: ${game.limit?.toString() ?? 'No limit'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _parseColorFromHex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return Colors.transparent;
    try {
      final v = int.parse(h, radix: 16);
      return Color(v);
    } catch (_) {
      return Colors.transparent;
    }
  }
}

class _HoverGameCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverGameCard({required this.child, this.onTap});

  @override
  State<_HoverGameCard> createState() => _HoverGameCardState();
}

class _HoverGameCardState extends State<_HoverGameCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerController.addStatusListener((s) {
      if (s == AnimationStatus.completed) _shimmerController.repeat();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEnterEvent e) {
    setState(() => _hovering = true);
    _shimmerController.forward(from: 0.0);
  }

  void _onExit(PointerExitEvent e) {
    setState(() => _hovering = false);
    _shimmerController.stop();
  }

  @override
  Widget build(BuildContext context) {
    // animated elevation / scale
    final scale = _hovering ? 1.025 : 1.0;
    final elevation = _hovering ? 14.0 : 4.0;

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          transform: Matrix4.identity()..scale(scale, scale),
          curve: Curves.easeOutCubic,
          child: Material(
            elevation: elevation,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // the card content passed in
                widget.child,
                // subtle dark overlay to lift content when hovered
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hovering ? 0.06 : 0.0,
                  child: Container(color: Colors.black),
                ),
                // shimmering highlight
                if (_hovering)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        final t = _shimmerController.value;
                        final width = MediaQuery.of(context).size.width;
                        // shimmer moves left-to-right across the card
                        final left = (-0.6 + 1.6 * t) * width;
                        return IgnorePointer(
                          child: Transform.translate(
                            offset: Offset(left, 0),
                            child: Container(
                              width: width * 0.6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.18),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                                // slight rotation to create diagonal shine
                                backgroundBlendMode: BlendMode.screen,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
