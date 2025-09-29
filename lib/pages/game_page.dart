import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_frontend/models/game.dart';
import 'package:coders_cup_minigame_frontend/utils.dart';
import 'package:coders_cup_minigame_frontend/pages/scoreboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GamePage extends StatefulWidget {
  final Game game;

  const GamePage({super.key, required this.game});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _signedIn = false;
  String? _userName;
  String? _userEmail;
  bool _formDisabled =
      false; // disable form when user already registered (for code-based games)
  bool _hasCode = false;
  String? _userCode;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.game.formFields) {
      _controllers[f.label] = TextEditingController();
    }
  }

  Future<void> _maybeLoadExistingResponse() async {
    if (_userEmail == null) return;
    // Show a small loading dialog while we query Firestore so the user knows
    // something is happening (important for code-based games where the form
    // may be disabled if a response already exists).
    if (!mounted) return;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Checking registration...')),
              ],
            ),
          ),
        ),
      );

      final q = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.game.id)
          .collection('responses')
          .where('userEmail', isEqualTo: _userEmail)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        if (d.containsKey('code')) {
          setState(() {
            _userCode = d['code']?.toString();
            _hasCode = _userCode != null;
            _formDisabled = _hasCode;
          });
        }
      }
    } catch (e) {
      // keep a minimal visible error for debugging
      // don't interrupt the flow; just report via snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check existing registration: $e')),
        );
      }
    } finally {
      // Dismiss the loading dialog if still present.
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // ignore if dialog already closed
        }
      }
    }
  }

  String _genShortCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    var v = now;
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(chars[v % chars.length]);
      v = (v ~/ chars.length) ^ (v << 5);
    }
    return sb.toString();
  }

  // Scoreboard moved to a separate page: use ScoreboardPage

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      final String? emailRaw = user?.email ?? googleUser.email;
      if (emailRaw == null) {
        // safety: sign out and inform user
        try {
          await _auth.signOut();
        } catch (_) {}
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to obtain email from Google account.'),
          ),
        );
        return;
      }
      final email = emailRaw.toLowerCase();

      if (!email.endsWith('nu.edu.pk')) {
        // not allowed domain: sign out and inform user
        try {
          await _auth.signOut();
        } catch (_) {}
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in with your nu.edu.pk email.'),
          ),
        );
        return;
      }

      setState(() {
        _signedIn = true;
        _userName = user?.displayName ?? googleUser.displayName ?? '';
        _userEmail = email;
      });
      // After sign-in, if this game is code-based check for existing response
      if (widget.game.codeBased) {
        await _maybeLoadExistingResponse();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
  }

  Future<void> _signOut() async {
    try {
      // Sign out from GoogleSignIn and FirebaseAuth if signed in
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}
    } catch (e) {
      // ignore
    }
    setState(() {
      _signedIn = false;
      _userName = null;
      _userEmail = null;
      _formDisabled = false;
      _hasCode = false;
      _userCode = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signed out')));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    // Stream to count responses in subcollection games/{gameId}/responses
    final responsesStream = FirebaseFirestore.instance
        .collection('games')
        .doc(game.id)
        .collection('responses')
        .snapshots();

    final baseTheme = Theme.of(context);
    final resolvedPrimary =
        (game.primaryColor != null && game.primaryColor!.isNotEmpty)
        ? _parseColorFromHex(game.primaryColor!)
        : baseTheme.colorScheme.primary;

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(primary: resolvedPrimary),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(game.name),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: responsesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            print(game.backgroundImage);
            // We no longer maintain or display a responsesCount field.
            // Keep snapshot available if needed, but do not use a stored count.

            return Stack(
              children: [
                // background image if present
                if (game.backgroundImage != null &&
                    game.backgroundImage!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      game.backgroundImage!,
                      fit: BoxFit.cover,
                      // dim slightly so foreground remains readable
                      color: Colors.black.withOpacity(0.7),
                      colorBlendMode: BlendMode.darken,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stack) {
                        debugPrint(
                          'Background image load failed: ${game.backgroundImage} -> $error',
                        );
                        return Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // primary color overlay (subtle)
                if (game.primaryColor != null && game.primaryColor!.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: _parseColorFromHex(
                        game.primaryColor!,
                      ).withOpacity(0.08),
                    ),
                  ),

                // main content
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
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Registration limits are not enforced client-side anymore.
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ScoreboardPage(
                                  gameId: game.id,
                                  gameName: game.name,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.leaderboard),
                            label: const Text('Show scoreboard'),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Sign in with Google',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.account_circle),
                                    label: Text(
                                      _signedIn
                                          ? 'Signed in as ${_userEmail ?? _userName} (click to sign out)'
                                          : 'Sign in with Google',
                                    ),
                                    onPressed: _signedIn
                                        ? _signOut
                                        : _signInWithGoogle,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_hasCode)
                                    Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[400],
                                            borderRadius: BorderRadius.circular(
                                              90,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'You are registered for this game. Your code: ${_userCode ?? ''}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.copy,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  if (_userCode != null) {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: _userCode!,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Code copied to clipboard',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!_signedIn)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Google sign-in is required to register.',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Please sign in using your nu.edu.pk (NU) email account.',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...game.formFields.map((f) {
                                  final controller = _controllers[f.label]!;
                                  final type = f.type.toLowerCase();

                                  // Date fields: open a date picker and validate ISO date
                                  if (type == 'date') {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: TextFormField(
                                        controller: controller,
                                        readOnly: true,
                                        enabled: !_formDisabled,
                                        decoration: InputDecoration(
                                          labelText: f.label,
                                          border: const OutlineInputBorder(),
                                          suffixIcon: const Icon(
                                            Icons.calendar_today,
                                          ),
                                          helperText: f.required
                                              ? 'required'
                                              : null,
                                          helperStyle: TextStyle(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        onTap: () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: now,
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            controller.text = picked
                                                .toIso8601String()
                                                .split('T')
                                                .first;
                                          }
                                        },
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty)
                                            return 'Required';
                                          try {
                                            DateTime.parse(v);
                                          } catch (_) {
                                            return 'Invalid date (YYYY-MM-DD)';
                                          }
                                          return null;
                                        },
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: TextFormField(
                                      controller: controller,
                                      keyboardType: _keyboardForType(type),
                                      decoration: InputDecoration(
                                        labelText: f.label,
                                        border: const OutlineInputBorder(),
                                        helperText: f.required
                                            ? 'required'
                                            : null,
                                        helperStyle: TextStyle(
                                          color: Colors.red[700],
                                        ),
                                      ),
                                      enabled: !_formDisabled,
                                      validator: (v) {
                                        if (f.required &&
                                            (v == null || v.trim().isEmpty))
                                          return 'Required';
                                        if (v != null) {
                                          if (type == 'email' &&
                                              !_looksLikeEmail(v))
                                            return 'Invalid email';
                                          if ((type == 'number' ||
                                                  type == 'numeric' ||
                                                  type == 'int') &&
                                              num.tryParse(v.trim()) == null)
                                            return 'Must be a number';
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: resolvedPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: (!_signedIn || _formDisabled)
                                      ? null
                                      : () async {
                                          final ok =
                                              _formKey.currentState
                                                  ?.validate() ??
                                              false;
                                          if (!ok) return;
                                          await _register();
                                        },
                                  child: _isRegistering
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Register'),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // bottom-left image
                if (game.bottomLeftImage != null &&
                    game.bottomLeftImage!.isNotEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Image.network(
                      game.bottomLeftImage!,
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
                          'Bottom-left image load failed: ${game.bottomLeftImage} -> $error',
                        );
                        return const SizedBox(
                          width: 120,
                          height: 120,
                          child: Center(child: Icon(Icons.broken_image)),
                        );
                      },
                    ),
                  ),

                // bottom-right image
                if (game.bottomRightImage != null &&
                    game.bottomRightImage!.isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Image.network(
                      game.bottomRightImage!,
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
                          'Bottom-right image load failed: ${game.bottomRightImage} -> $error',
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
  }

  TextInputType _keyboardForType(String type) {
    final t = type.toLowerCase();
    if (t == 'number' || t == 'numeric' || t == 'int')
      return TextInputType.number;
    if (t == 'email') return TextInputType.emailAddress;
    return TextInputType.text;
  }

  bool _looksLikeEmail(String v) => v.contains('@') && v.contains('.');

  bool _hasValidNuEmail(String? email) {
    if (email == null) return false;
    return email.toLowerCase().endsWith('nu.edu.pk');
  }

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

  Future<void> _register() async {
    if (!_signedIn || _userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must sign in with Google first.')),
      );
      return;
    }

    if (!_hasValidNuEmail(_userEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use your nu.edu.pk email to register.'),
        ),
      );
      return;
    }

    setState(() => _isRegistering = true);

    final gameRef = FirebaseFirestore.instance
        .collection('games')
        .doc(widget.game.id);
    final responsesRef = gameRef.collection('responses');
    // Prevent duplicate registration: check if an existing response with the same email exists
    try {
      final q1 = await responsesRef
          .where('userEmail', isEqualTo: _userEmail)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        setState(() => _isRegistering = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Already registered'),
            content: Text(
              'This email ($_userEmail) has already been used to register for this game. You cannot register again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      // Also try lowercase variant in case emails were stored lowercased
      final lower = _userEmail!.toLowerCase();
      if (lower != _userEmail) {
        final q2 = await responsesRef
            .where('userEmail', isEqualTo: lower)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) {
          setState(() => _isRegistering = false);
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Already registered'),
              content: Text(
                'This email ($_userEmail) has already been used to register for this game. You cannot register again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        }
      }

      // continue to transaction
    } catch (e) {
      // if duplicate-check fails, surface an error and abort
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify existing registration: $e')),
      );
      return;
    }

    try {
      // Create the response document inside a transaction after verifying the game exists.
      // For code-based games we try up to maxAttempts to generate a non-colliding code.
      String? allocatedCode;
      final payloadBase = <String, dynamic>{
        'userName': _userName,
        'userEmail': _userEmail,
        'submittedAt': FieldValue.serverTimestamp(),
        'answers': {},
      };

      for (final f in widget.game.formFields) {
        final raw = _controllers[f.label]?.text ?? '';
        final type = f.type.toLowerCase();
        dynamic value = raw;
        if (type == 'number' || type == 'numeric' || type == 'int') {
          value = num.tryParse(raw.trim()) ?? raw;
        } else if (type == 'date') {
          try {
            final dt = DateTime.parse(raw);
            value = Timestamp.fromDate(dt);
          } catch (_) {
            value = raw;
          }
        }
        payloadBase['answers'][f.label] = {
          'value': value,
          'type': f.type,
          'required': f.required,
        };
      }

      if (widget.game.codeBased) {
        const maxAttempts = 3;
        for (var attempt = 0; attempt < maxAttempts; attempt++) {
          final candidate = _genShortCode();
          try {
            final result = await FirebaseFirestore.instance
                .runTransaction<String>((tx) async {
                  final gameSnap = await tx.get(gameRef);
                  if (!gameSnap.exists) throw Exception('Game not found');

                  final candidateRef = responsesRef.doc(candidate);
                  final candSnap = await tx.get(candidateRef);
                  if (candSnap.exists) throw StateError('collision');

                  final payload = Map.of(payloadBase);
                  payload['code'] = candidate;
                  tx.set(candidateRef, payload);
                  return candidate;
                });

            allocatedCode = result;
            break; // success
          } on StateError catch (e) {
            if (e.message == 'collision') {
              // try next candidate
              continue;
            }
            rethrow;
          }
        }
        if (allocatedCode == null)
          throw StateError('Could not allocate a unique code');
      } else {
        // non-code-based: single transaction to write the response with auto-id
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final gameSnap = await tx.get(gameRef);
          if (!gameSnap.exists) throw Exception('Game not found');
          final newRef = responsesRef.doc();
          final payload = Map.of(payloadBase);
          tx.set(newRef, payload);
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registered successfully.')));

      if (widget.game.codeBased) {
        setState(() {
          _userCode = allocatedCode;
          _hasCode = true;
          _formDisabled = true;
        });

        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Your code'),
            content: Text('Your registration code is: $allocatedCode'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } on StateError catch (e) {
      if (e.message == 'limit-reached') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration closed: limit reached.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      setState(() => _isRegistering = false);
    }
  }
}
