import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/constants/api_endpoints.dart';
import '../core/localization/app_translations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppTranslations.tr(lang, "app_settings_title", "Application Settings"),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                  title: Text(
                    AppTranslations.tr(lang, "voice_ui_language", "Voice & UI Language"),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${AppTranslations.tr(lang, "current_lang_label", "Current:")} ${AppTranslations.getLanguageName(auth.selectedLanguage)}"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    AppTranslations.showLanguageSelectorModal(
                      context,
                      auth.selectedLanguage,
                      (newLang) => auth.setLanguage(newLang),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
                  title: Text(
                    AppTranslations.tr(lang, "offline_sync_cache_title", "Offline Sync Cache"),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(AppTranslations.tr(lang, "manage_pending_uploads", "Manage pending uploads and local storage")),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/sync_center'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_rounded, color: AppColors.primary),
                  title: Text(
                    AppTranslations.tr(lang, "backend_server_host", "Backend Server Host"),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Endpoint: ${ApiEndpoints.baseUrl}"),
                  trailing: const Icon(Icons.edit_rounded, size: 18),
                  onTap: () {
                    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          AppTranslations.tr(lang, "backend_server_host", "Configure Backend Host"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "When testing on a physical mobile phone, enter your computer's local Wi-Fi IP (e.g. http://192.168.1.5:8000).",
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller,
                              decoration: const InputDecoration(hintText: "http://<ip>:8000/api/v1"),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(AppTranslations.tr(lang, "cancel_btn", "Cancel")),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              ApiEndpoints.setBaseUrl(controller.text.trim());
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Server URL updated: ${ApiEndpoints.baseUrl}"), backgroundColor: AppColors.primary),
                              );
                            },
                            child: Text(AppTranslations.tr(lang, "save_btn", "Save")),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: AppColors.primary),
                  title: Text(
                    AppTranslations.tr(lang, "blockchain_proof_title", "Blockchain Proof Verification"),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(AppTranslations.tr(lang, "sha256_proof_sub", "SHA-256 Tamper-Proof Cryptographic Anchoring")),
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              "PRAMAAN AgTech Platform v2.0.0",
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
