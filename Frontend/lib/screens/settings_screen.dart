import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/bible_provider.dart';
import '../providers/settings_provider.dart';
import '../services/local_storage_service.dart';
import '../models/user_settings_enums.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ───────────────────────────────── UI CONTROLLERS ────────────────────────────
  late final TextEditingController _searchController;
  late final TextEditingController _geminiApiKeyController;
  Timer? _debounce;
  bool _obscureApiKey = true;

  // Data lists
  List<dynamic> _filteredTranslations = [];

  // ────────────────────────────── LIFECYCLE ────────────────────────────────────
  @override
  void initState() {
    super.initState();

    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    _searchController = TextEditingController(
        text: settingsProvider.currentTranslationName ?? '');
    _geminiApiKeyController = TextEditingController(
        text: settingsProvider.geminiApiKey ?? '');
    // _filteredTranslations = bibleProvider.translations;
    _filteredTranslations =
        _groupAndSortTranslations(bibleProvider.translations);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          _filterTranslations(_searchController.text);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  // ─────────────────────────────── HELPERS ────────────────────────────────────
  void _filterTranslations(String query) {
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    setState(() {
      // Simple fuzzy + substring filter
      final all = bibleProvider.translations;
      if (query.isEmpty) {
        _filteredTranslations = _groupAndSortTranslations(all);
        return;
      }

      final lowerQuery = query.toLowerCase();
      // score each translation
      final scored = all.map((t) {
        final display = _buildDisplayName(t).toLowerCase();
        final score = StringSimilarity.compareTwoStrings(display, lowerQuery);
        final map = Map<String, dynamic>.from(t); // 👈 cast it properly
        map['_score'] = score;
        return map;
      }).where((t) {
        final disp = _buildDisplayName(t).toLowerCase();
        return disp.contains(lowerQuery) || t['_score'] > 0.2;
      }).toList();

      scored.sort(
          (a, b) => (b['_score'] as double).compareTo(a['_score'] as double));

      // ensure current translation stays visible
      final currentId = settingsProvider.currentTranslationId;
      if (currentId != null &&
          _filteredTranslations.every((t) => t['id'] != currentId)) {
        final current =
            all.firstWhere((t) => t['id'] == currentId, orElse: () => {});
        if (current.isNotEmpty) _filteredTranslations.insert(0, current);
      }
      _filteredTranslations = _groupAndSortTranslations(scored);
    });
  }

  List<Map<String, dynamic>> _groupAndSortTranslations(
      List<dynamic> translations) {
    List<Map<String, dynamic>> english = [];
    Map<String, List<Map<String, dynamic>>> others = {};

    for (var t in translations) {
      final langName = (t['language']?['name'] ?? '').toString().toLowerCase();
      final name = (t['name'] ?? '').toString().toLowerCase();

      final isEnglish = langName == 'english' ||
          langName.isEmpty ||
          t['language']?['id'] == 'eng' ||
          ['esv', 'niv', 'nkjv', 'nlt', 'nasb', 'net', 'csb']
              .any((key) => name.contains(key));

      if (isEnglish) {
        english.add(t);
      } else {
        final lang = t['language']?['name'] ?? 'Unknown';
        others.putIfAbsent(lang, () => []).add(t);
      }
    }

    english.sort((a, b) => a['name'].compareTo(b['name']));
    for (var group in others.values) {
      group.sort((a, b) => a['name'].compareTo(b['name']));
    }

    final sortedLanguages = others.keys.toList()..sort();
    final result = [...english];
    for (var lang in sortedLanguages) {
      result.addAll(others[lang]!);
    }

    return result;
  }

  // Settings are saved locally automatically via SharedPreferences
  void _queueSave() {
    // No-op - settings are saved locally by the provider methods
  }

  String _buildDisplayName(Map t) {
    final name = t['name']?.toString() ?? '';
    final lang = t['language']?['name']?.toString() ?? '';
    return (lang.toLowerCase() == 'english' || lang.isEmpty)
        ? name
        : '$name ($lang)';
  }

  // ────────────────────────────── BUILD ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final bibleProvider = Provider.of<BibleProvider>(context);

    final List<MaterialColor> palette = [
      // Row 1: Black, warm colors, purple
      _createSolidMaterialColor(const Color.fromARGB(255, 0, 0, 0)),       // True Black
      createMutedMaterialColor(const Color.fromARGB(255, 145, 39, 32)),    // Red
      createMutedMaterialColor(const Color.fromARGB(255, 231, 153, 36)),   // Orange
      createMutedMaterialColor(const Color.fromARGB(255, 210, 199, 101)),  // Yellow
      createMutedMaterialColor(const Color.fromARGB(255, 255, 94, 148)),   // Pink
      createMutedMaterialColor(const Color.fromARGB(255, 159, 86, 179)),   // Purple
      createMutedMaterialColor(const Color.fromARGB(255, 125, 105, 218)),  // Indigo
      // Row 2: Blues, greens, white
      createMutedMaterialColor(const Color.fromARGB(255, 83, 98, 181)),    // Blue
      createMutedMaterialColor(const Color.fromARGB(255, 29, 107, 171)),   // Deep blue
      createMutedMaterialColor(const Color.fromARGB(255, 73, 178, 192)),   // Cyan
      createMutedMaterialColor(const Color.fromARGB(255, 52, 185, 172)),   // Teal
      createMutedMaterialColor(const Color.fromARGB(255, 23, 66, 25)),     // Dark green
      createMutedMaterialColor(const Color.fromARGB(255, 100, 186, 100)),  // Light green
      _createSolidMaterialColor(const Color.fromARGB(255, 255, 255, 255)), // True White
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // ── Bible translation ──────────────────────────────────────────────
          ExpansionTile(
            title: const Text('Bible Translation'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search or scroll translations',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Container(
                height: 320,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    itemCount: _filteredTranslations.length,
                    itemBuilder: (context, idx) {
                      final t = _filteredTranslations[idx];
                      final isCurrent =
                          t['id'] == settingsProvider.currentTranslationId;
                      return ListTile(
                        title: Text(_buildDisplayName(t),
                            overflow: TextOverflow.ellipsis),
                        trailing: isCurrent
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        // onTap: () async {
                        //   await settingsProvider.updateTranslation(
                        //       t['id'], t['name']);
                        //   _searchController.text = t['name'];
                        //   await bibleProvider.fetchBooks(t['id']);
                        //   _queueSave();
                        // },
                        onTap: () async {
                          final name = t['name'].toString().toLowerCase();
                          if (name.contains('niv') ||
                              name.contains('new international version') ||
                              name.contains('esv') ||
                              name.contains('english standard version')) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Translation Not Available"),
                                content: RichText(
                                  text: TextSpan(
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    children: [
                                      const TextSpan(
                                          text: "Unfortunately, the "),
                                      TextSpan(
                                          text: name.toUpperCase(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const TextSpan(
                                          text:
                                              " translation is not available in Bybl.\n\nWhy? Because its publisher won't license individually-owned open-source projects — only formal organizations or churches.\n\n"),
                                      const TextSpan(
                                          text:
                                              "You can read their policies here:\n"),
                                      TextSpan(
                                        text: name.toLowerCase().contains(
                                                'new international version')
                                            ? "https://www.biblica.com/licensing/"
                                            : "https://www.crossway.org/permissions/faq/",
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            launchUrl(Uri.parse(
                                              name.toLowerCase().contains(
                                                      'new international version')
                                                  ? "https://www.biblica.com/licensing/"
                                                  : "https://www.crossway.org/permissions/faq/",
                                            ));
                                          },
                                      ),
                                      const TextSpan(
                                          text:
                                              "\n\nWe recommend trying a more open translation like the "),
                                      const TextSpan(
                                          text: "Berean Standard Bible (BSB) ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const TextSpan(text: "or the "),
                                      const TextSpan(
                                          text: "World English Bible (WEB)",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const TextSpan(text: "."),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Got it"),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          await settingsProvider.updateTranslation(
                              t['id'], t['name']);
                          _searchController.text = t['name'];
                          await bibleProvider.fetchBooks(t['id']);
                          _queueSave();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── Theme & Colors ─────────────────────────────────────────────────
          ExpansionTile(
            title: const Text('Theme & Colors'),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8),
                child: Text('App Color',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              _buildColorGrid(
                palette,
                settingsProvider.currentColor,
                (c) => settingsProvider.updateColor(c),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8),
                child: Text('Highlighter Color',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              _buildColorGrid(
                palette,
                settingsProvider.highlightColor,
                (c) => settingsProvider.updateHighlightColor(c),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text('Theme Mode',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              _buildThemeModeOption(
                  settingsProvider, ThemeMode.light, 'Light Mode'),
              _buildThemeModeOption(
                  settingsProvider, ThemeMode.dark, 'Dark Mode'),
              const SizedBox(height: 8),
            ],
          ),

          // ── Gemini AI Settings ───────────────────────────────────────────
          ExpansionTile(
            title: const Text('Gemini AI Settings'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('API Key',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _geminiApiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        hintText: 'Enter your Gemini API key',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(_obscureApiKey
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _obscureApiKey = !_obscureApiKey;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.save),
                              onPressed: () {
                                settingsProvider.updateGeminiApiKey(
                                    _geminiApiKeyController.text.trim());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('API key saved')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get your API key from Google AI Studio',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        launchUrl(
                            Uri.parse('https://aistudio.google.com/apikey'));
                      },
                      child: const Text('Get API Key →'),
                    ),
                    const SizedBox(height: 16),
                    Text('Model',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Ensure current model is in the list, otherwise use default
                        final currentModel = SettingsProvider.availableGeminiModels
                                .contains(settingsProvider.geminiModel)
                            ? settingsProvider.geminiModel
                            : SettingsProvider.availableGeminiModels.first;
                        
                        // Auto-update if model was invalid
                        if (currentModel != settingsProvider.geminiModel) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            settingsProvider.updateGeminiModel(currentModel);
                          });
                        }
                        
                        return DropdownButtonFormField<String>(
                          value: currentModel,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: SettingsProvider.availableGeminiModels
                              .map((model) => DropdownMenuItem(
                                    value: model,
                                    child: Text(model),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              settingsProvider.updateGeminiModel(value);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── AI Personality & Context ─────────────────────────────────────
          ExpansionTile(
            title: const Text('AI Personality & Context'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Denomination',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Denomination>(
                      value: settingsProvider.denomination,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        helperText:
                            'Influences the theological perspective of the AI.',
                      ),
                      items: Denomination.values
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.updateDenomination(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Result Type',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AIContext>(
                      value: settingsProvider.aiContext,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        helperText:
                            'Determines the style and depth of the response.',
                      ),
                      items: AIContext.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.updateAIContext(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Backup & Export ─────────────────────────────────────────────
          ExpansionTile(
            title: const Text('Backup & Export'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export your bookmarks and highlighted verses to a file that you can save or share.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Export Data'),
                        onPressed: _exportData,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Import Data'),
                        onPressed: _importData,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final jsonData = await LocalStorageService.exportAllData();
      
      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/bybl_backup_$timestamp.json');
      await file.writeAsString(jsonData);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Bybl Backup',
        text: 'My Bybl bookmarks and highlights backup',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup file ready to share')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        
        final counts = await LocalStorageService.importData(jsonString);
        if (mounted) {
          final settingsMsg = counts['settings'] == 1 ? ', settings' : '';
          final chatsMsg = (counts['chats'] ?? 0) > 0 ? ', ${counts['chats']} chats' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${counts['bookmarks']} bookmarks, ${counts['highlights']} highlights$chatsMsg$settingsMsg. Restart app to apply.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: Invalid file or format')),
        );
      }
    }
  }

  // ────────────────────────── UI BUILD HELPERS ───────────────────────────────
  Widget _buildColorGrid(List<MaterialColor> colors, Color? selected,
      Function(MaterialColor) onTap) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: colors.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, idx) {
          final color = colors[idx];
          final isSelected = selected?.value == color.value;
          // Determine if color is light or dark for contrast
          final luminance = color.computeLuminance();
          final isLightColor = luminance > 0.5;
          final checkColor = isLightColor ? Colors.black : Colors.white;
          final borderColor = isLightColor ? Colors.black54 : Colors.white;
          
          return GestureDetector(
            onTap: () {
              onTap(color);
              _queueSave();
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected ? borderColor : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: isSelected
                  ? Center(child: Icon(Icons.check, color: checkColor, size: 20))
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeModeOption(
      SettingsProvider sp, ThemeMode mode, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<ThemeMode>(
        value: mode,
        groupValue: sp.currentThemeMode,
        onChanged: (val) {
          if (val != null) {
            sp.updateThemeMode(val);
            _queueSave();
          }
        },
      ),
    );
  }

  // ─────────────────────────── COLOR HELPERS ────────────────────────────────

  /// Return a pastel / “muted” MaterialColor by blending the base colour
  /// toward white.  The larger the blendFactor, the paler the shade.
  ///
  /// e.g.  blendFactor 0.80  →  80 % white  +  20 % base colour.
  MaterialColor createMutedMaterialColor(Color base,
      {double blendFactor = 0.80}) {
    assert(blendFactor >= 0 && blendFactor <= 1);

    Color _blend(double t) => Color.lerp(base, Colors.white, blendFactor * t)!;

    return MaterialColor(base.value, {
      50: _blend(1.00),
      100: _blend(0.90),
      200: _blend(0.80),
      300: _blend(0.65),
      400: _blend(0.45),
      500: _blend(0.30),
      600: _blend(0.20),
      700: _blend(0.12),
      800: _blend(0.07),
      900: _blend(0.04),
    });
  }

  /// Create a solid MaterialColor without blending (for black/white)
  MaterialColor _createSolidMaterialColor(Color base) {
    return MaterialColor(base.value, {
      50: base,
      100: base,
      200: base,
      300: base,
      400: base,
      500: base,
      600: base,
      700: base,
      800: base,
      900: base,
    });
  }
}
