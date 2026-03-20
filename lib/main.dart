import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class _MyHomePageState extends State<MyHomePage> {

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
                        child: const Image(
                          height: 75,
                          width: 100,
                          image: AssetImage('assets/italy.svg'),
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onLocaleChange(const Locale('pl')),
                      child: Opacity(
                        opacity: widget.currentLocale.languageCode == 'pl' ? 1.0 : 0.5,
                        child: const Image(
                          height: 75,
                          width: 100,
                          image: AssetImage('assets/poland.svg'),
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
                    TextButton(onPressed: () {}, child: Text(l10n.login)),
                    TextButton(onPressed: () {}, child: Text(l10n.register))
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
