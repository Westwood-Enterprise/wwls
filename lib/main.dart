import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Westwood Way Language Services',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('it'),
        Locale('pl'),
      ],
      locale: _locale,
      home: MyHomePage(
        title: 'Westwood Way Language Services',
        onLocaleChange: _setLocale,
        currentLocale: _locale,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onLocaleChange,
    required this.currentLocale,
  });
  final String title;
  final Function(Locale) onLocaleChange;
  final Locale currentLocale;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');
  static const String _jwtKey = 'auth.jwt';
  static const String _jwtExpiresAtKey = 'auth.jwt.expiresAt';

  bool _isSubmitting = false;
  String? _jwtToken;
  int? _jwtExpiresAtMillis;

  Uri get _apiBaseUri {
    if (_apiBaseOverride.isNotEmpty) {
      return Uri.parse(_apiBaseOverride);
    }

    if (kReleaseMode) {
      return Uri.https('wwdb.obelous.dev');
    }

    return Uri.http('localhost:3000');
  }

  Uri _endpoint(String path) => _apiBaseUri.replace(path: path);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _renewTokenIfNeeded(force: false);
    }
  }

  Future<void> _initializeSession() async {
    await _loadStoredAuth();
    await _renewTokenIfNeeded(force: false);
  }

  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_jwtKey);
    final expiresAt = prefs.getInt(_jwtExpiresAtKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _jwtToken = token;
      _jwtExpiresAtMillis = expiresAt;
    });
  }

  Future<void> _saveAuth({required String token, required int expiresAtMillis}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, token);
    await prefs.setInt(_jwtExpiresAtKey, expiresAtMillis);

    if (!mounted) {
      return;
    }

    setState(() {
      _jwtToken = token;
      _jwtExpiresAtMillis = expiresAtMillis;
    });
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_jwtExpiresAtKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _jwtToken = null;
      _jwtExpiresAtMillis = null;
    });
  }

  Future<void> _renewTokenIfNeeded({required bool force}) async {
    final token = _jwtToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final expiresAt = _jwtExpiresAtMillis;
    final now = DateTime.now().millisecondsSinceEpoch;
    const renewalWindowMillis = 3 * 24 * 60 * 60 * 1000;
    final shouldRenew = force || expiresAt == null || expiresAt - now <= renewalWindowMillis;

    if (!shouldRenew) {
      return;
    }

    try {
      final response = await http.post(
        _endpoint('/token/renew'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          await _persistTokenFromResponse(body);
        }
      } else if (response.statusCode == 401) {
        await _clearAuth();
      }
    } catch (_) {
      // Keep current token if renewal fails due to temporary connectivity issues.
    }
  }

  Future<void> _persistTokenFromResponse(Map<String, dynamic> body) async {
    final token = body['token'] as String?;
    final expiresAtDynamic = body['tokenExpiresAt'];

    final expiresAtMillis = switch (expiresAtDynamic) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };

    if (token == null || token.isEmpty) {
      return;
    }

    if (expiresAtMillis == null) {
      return;
    }

    await _saveAuth(token: token, expiresAtMillis: expiresAtMillis);
  }

  Future<void> _handleRegister() async {
    await _runAuthFlow(
      title: 'Register',
      endpointPath: '/signup',
      successMessage: 'Account created successfully',
    );
  }

  Future<void> _handleLogin() async {
    await _runAuthFlow(
      title: 'Login',
      endpointPath: '/login',
      successMessage: 'Login successful',
    );
  }

  Future<void> _runAuthFlow({
    required String title,
    required String endpointPath,
    required String successMessage,
  }) async {
    final credentials = await _showCredentialsDialog(title: title);
    if (!mounted || credentials == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        _endpoint(endpointPath),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(credentials),
      );

      if (!mounted) {
        return;
      }

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final serverError = body is Map<String, dynamic> ? body['error'] as String? : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body is Map<String, dynamic>) {
          await _persistTokenFromResponse(body);
        }
        _showMessage(successMessage);
      } else {
        _showMessage(serverError ?? 'Request failed (${response.statusCode})');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to connect to ${_apiBaseUri.host}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _showCredentialsDialog({required String title}) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final username = usernameController.text.trim();
                final password = passwordController.text;

                if (username.isEmpty || password.isEmpty) {
                  return;
                }

                Navigator.of(context).pop({
                  'username': username,
                  'password': password,
                });
              },
              child: Text(title),
            ),
          ],
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(l10n.selectLanguage),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    GestureDetector(
                      onTap: () => widget.onLocaleChange(const Locale('en')),
                      child: Opacity(
                        opacity: widget.currentLocale.languageCode == 'en' ? 1.0 : 0.5,
                        child: SvgPicture.asset(
                          'assets/england.svg',
                          height: 75,
                          width: 100,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onLocaleChange(const Locale('it')),
                      child: Opacity(
                        opacity: widget.currentLocale.languageCode == 'it' ? 1.0 : 0.5,
                        child: SvgPicture.asset(
                          'assets/italy.svg',
                          height: 75,
                          width: 100,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onLocaleChange(const Locale('pl')),
                      child: Opacity(
                        opacity: widget.currentLocale.languageCode == 'pl' ? 1.0 : 0.5,
                        child: SvgPicture.asset(
                          'assets/poland.svg',
                          height: 75,
                          width: 100,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : _handleLogin,
                      child: Text(l10n.login),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : _handleRegister,
                      child: Text(l10n.register),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting) const CircularProgressIndicator(),
              if (_jwtToken != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Session active'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
