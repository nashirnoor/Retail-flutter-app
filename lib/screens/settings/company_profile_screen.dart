import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../database/database_helper.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _db = DatabaseHelper();
  
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _isEditing = false;
  String? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastBackupTime = prefs.getString('last_backup_time');
    });
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final data = await _db.getCompanyProfile();
    setState(() {
      _nameCtrl.text = data['name'] ?? '';
      _addressCtrl.text = data['address'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _loading = false;
    });
  }

  Future<void> _backupDatabase() async {
    try {
      final path = await _db.getDatabasePath();
      final file = File(path);
      
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(path)], 
          subject: 'Inventory Database Backup',
          text: 'Backup of your inventory data as of ${DateTime.now()}',
        );
        
        // Save backup time
        final now = DateTime.now();
        final formattedTime = DateFormat('MMM dd, yyyy HH:mm').format(now);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_time', formattedTime);
        setState(() {
          _lastBackupTime = formattedTime;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database file not found!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final importFile = File(result.files.single.path!);
        
        if (!importFile.path.endsWith('.db')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a valid .db database file')),
            );
          }
          return;
        }

        final path = await _db.getDatabasePath();
        final dbFile = File(path);
        
        // Copy the imported file over the existing database
        await importFile.copy(dbFile.path);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                   Icon(Icons.check_circle_rounded, color: AppColors.accent),
                   SizedBox(width: 8),
                   Text('Import Successful'),
                ],
              ),
              content: const Text('Your database has been restored successfully. The application will now close to apply changes. Please open it again.'),
              actions: [
                TextButton(
                  onPressed: () => exit(0),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('Close App'),
                )
              ],
            )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    await _db.updateCompanyProfile(
      _nameCtrl.text.trim(),
      _addressCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );
    setState(() => _isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company Profile Updated!')),
      );
    }
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.business_rounded, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          _nameCtrl.text.isEmpty ? 'Setup Company Profile' : _nameCtrl.text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(_addressCtrl.text.isEmpty ? 'No address added' : _addressCtrl.text, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(_phoneCtrl.text.isEmpty ? 'No phone added' : _phoneCtrl.text, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Profile'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Edit Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadProfile(); // Reset fields to previous values
              },
            )
          ],
        ),
        const SizedBox(height: 20),
        const Text('Company Name', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.business_rounded)),
        ),
        const SizedBox(height: 20),
        const Text('Address', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_rounded)),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text('Phone Number', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_rounded)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Profile'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Company Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: _isEditing ? _buildProfileEdit() : _buildProfileView(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Export your database for safekeeping, or import a previously exported database to restore your data.', 
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                        const SizedBox(height: 8),
                        if (_lastBackupTime != null)
                          Text('Last Backup: $_lastBackupTime', 
                            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _backupDatabase,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Backup Database'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _importDatabase,
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Import Database'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
