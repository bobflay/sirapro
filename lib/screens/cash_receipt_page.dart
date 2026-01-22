import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sirapro/services/wallet_service.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

class CashReceiptPage extends StatefulWidget {
  const CashReceiptPage({super.key});

  @override
  State<CashReceiptPage> createState() => _CashReceiptPageState();
}

class _CashReceiptPageState extends State<CashReceiptPage> {
  final WalletService _walletService = WalletService();
  final ImagePicker _picker = ImagePicker();

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validate() {
    _fieldErrors = {};

    if (_selectedImage == null) {
      _fieldErrors['image'] = 'Veuillez sélectionner une image du reçu';
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _fieldErrors['amount'] = 'Le montant est requis';
    } else {
      final amount = double.tryParse(amountText);
      if (amount == null || amount < 0.01) {
        _fieldErrors['amount'] = 'Le montant doit être au moins 0.01';
      }
    }

    final notes = _notesController.text.trim();
    if (notes.length > 1000) {
      _fieldErrors['notes'] = 'Les notes ne doivent pas dépasser 1000 caractères';
    }

    setState(() {});
    return _fieldErrors.isEmpty;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      // Validate file size (max 10MB)
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('L\'image ne doit pas dépasser 10 Mo'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate file extension
      final extension = image.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format accepté : JPG, JPEG ou PNG'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _fieldErrors.remove('image');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choisir la source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final response = await _walletService.submitCashReceipt(
        imageBytes: _imageBytes!,
        fileName: _selectedImage!.name,
        amount: amount,
        notes: notes,
      );

      if (mounted) {
        final message = response['message']?.toString() ??
            'Reçu soumis avec succès. En attente de validation.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo du reçu *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isSubmitting ? null : _showImageSourceSheet,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _fieldErrors.containsKey('image')
                    ? Colors.red
                    : Colors.grey[300]!,
                width: _fieldErrors.containsKey('image') ? 1.5 : 1,
              ),
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _selectedImage = null;
                                      _imageBytes = null;
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Appuyez pour ajouter une photo',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, JPEG ou PNG (max 10 Mo)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_fieldErrors.containsKey('image'))
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _fieldErrors['image']!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Montant (FCFA) *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: 'Ex: 15000',
            prefixIcon: const Icon(Icons.payments_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _fieldErrors['amount'],
          ),
          onChanged: (_) {
            if (_fieldErrors.containsKey('amount')) {
              setState(() => _fieldErrors.remove('amount'));
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (optionnel)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 1000,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: 'Ex: Versement du 22 janvier',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Icons.notes_outlined),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _fieldErrors['notes'],
          ),
          onChanged: (_) {
            if (_fieldErrors.containsKey('notes')) {
              setState(() => _fieldErrors.remove('notes'));
            }
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          _isSubmitting ? 'Envoi en cours...' : 'Soumettre le reçu',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SessionAwareAppBar(title: 'Versement'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Prenez en photo votre reçu de versement. '
                        'La demande sera vérifiée avant validation.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildAmountField(),
              const SizedBox(height: 24),
              _buildNotesField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
