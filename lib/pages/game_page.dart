import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_frontend/models/game.dart';
import 'package:coders_cup_minigame_frontend/utils.dart';
import 'package:coders_cup_minigame_frontend/pages/scoreboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // NOTE: Google Sign-In integration was temporarily disabled because of
  // package API mismatches. Use a simple dialog-based sign-in (name + NU email)
  // as a temporary replacement so the app compiles and registration can proceed.
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.game.formFields) {
      _controllers[f.label] = TextEditingController();
    }
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
          const SnackBar(content: Text('Failed to obtain email from Google account.')),
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
          const SnackBar(content: Text('Please sign in with your nu.edu.pk email.')),
        );
        return;
      }

      setState(() {
        _signedIn = true;
        _userName = user?.displayName ?? googleUser.displayName ?? '';
        _userEmail = email;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
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

    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: responsesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // We no longer maintain or display a responsesCount field.
          // Keep snapshot available if needed, but do not use a stored count.

          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: isLandscape(context)
                  ? MediaQuery.of(context).size.width * 0.2
                  : MediaQuery.of(context).size.width * 0.05,
            ),
            child: SingleChildScrollView(
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.account_circle),
                            label: Text(
                              _signedIn
                                  ? 'Signed in as ${_userEmail ?? _userName} (click to sign out)'
                                  : 'Sign in with Google',
                            ),
                            onPressed: _signedIn ? _signOut : _signInWithGoogle,
                          ),
                          const SizedBox(height: 8),
                          if (!_signedIn)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                decoration: InputDecoration(
                                  labelText: f.label,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  helperText: f.required ? 'required' : null,
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
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextFormField(
                              controller: controller,
                              keyboardType: _keyboardForType(type),
                              decoration: InputDecoration(
                                labelText: f.label,
                                border: const OutlineInputBorder(),
                                helperText: f.required ? 'required' : null,
                                helperStyle: TextStyle(color: Colors.red[700]),
                              ),
                              validator: (v) {
                                if (f.required &&
                                    (v == null || v.trim().isEmpty))
                                  return 'Required';
                                if (v != null) {
                                  if (type == 'email' && !_looksLikeEmail(v))
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
                          onPressed: (!_signedIn)
                              ? null
                              : () async {
                                  final ok =
                                      _formKey.currentState?.validate() ??
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
          );
        },
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
                'This email ($_userEmail) has already been used to register for this game. You cannot register again.'),
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
                  'This email ($_userEmail) has already been used to register for this game. You cannot register again.'),
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
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final gameSnap = await tx.get(gameRef);
        if (!gameSnap.exists) throw Exception('Game not found');

        // Prepare response payload
        final payload = <String, dynamic>{
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
          // Save each answer as an object with type metadata so backend can know the datatype
          payload['answers'][f.label] = {
            'value': value,
            'type': f.type,
            'required': f.required,
          };
        }

  // Create a new response doc with auto id
  final newRef = responsesRef.doc();
  tx.set(newRef, payload);

  // Do not maintain responsesCount here; counts are derived by querying the
  // responses subcollection when needed.
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registered successfully.')));
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
