import 'dart:io';
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/widgets/sponsor_banner.dart';
import '../models/sponsor.dart';
import '../services/sponsor_service.dart';

class SponsorDetailScreen extends StatefulWidget {
  final Sponsor? sponsor; // If null, creating new

  const SponsorDetailScreen({super.key, this.sponsor});

  @override
  State<SponsorDetailScreen> createState() => _SponsorDetailScreenState();
}

class _SponsorDetailScreenState extends State<SponsorDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sponsorService = SponsorService();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  String _selectedPlan = 'bronce';
  bool _isActive = true;

  // Selected Files
  // Selected Files
  XFile? _logoFile;
  Uint8List? _logoBytes;

  XFile? _bannerFile;
  Uint8List? _bannerBytes;

  XFile? _assetFile;
  Uint8List? _assetBytes;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sponsor?.name ?? '');
    _selectedPlan = widget.sponsor?.planType ?? 'bronce';
    _isActive = widget.sponsor?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        // --- Validation: Max 2MB ---
        final sizeInMb = bytes.lengthInBytes / (1024 * 1024);
        if (sizeInMb > 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '⚠️ La imagen es muy grande (máx 2MB). Intenta comprimirla.',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
          }
          return;
        }

        setState(() {
          switch (type) {
            case 'logo':
              _logoFile = pickedFile;
              _logoBytes = bytes;
              break;
            case 'banner':
              _bannerFile = pickedFile;
              _bannerBytes = bytes;
              break;
            case 'asset':
              _assetFile = pickedFile;
              _assetBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _saveSponsor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.sponsor == null) {
        // CREATE
        await _sponsorService.createSponsor(
          name: _nameController.text.trim(),
          planType: _selectedPlan,
          isActive: _isActive,
          // Mobile Fallback
          logoFile:
              (!kIsWeb && _logoFile != null) ? File(_logoFile!.path) : null,
          bannerFile:
              (!kIsWeb && _bannerFile != null) ? File(_bannerFile!.path) : null,
          assetFile:
              (!kIsWeb && _assetFile != null) ? File(_assetFile!.path) : null,
          // Web Support
          logoBytes: kIsWeb ? _logoBytes : null,
          bannerBytes: kIsWeb ? _bannerBytes : null,
          assetBytes: kIsWeb ? _assetBytes : null,
          logoExtension: _logoFile?.name.split('.').last,
          bannerExtension: _bannerFile?.name.split('.').last,
          assetExtension: _assetFile?.name.split('.').last,
        );
      } else {
        // UPDATE
        await _sponsorService.updateSponsor(
          id: widget.sponsor!.id,
          name: _nameController.text.trim(),
          planType: _selectedPlan,
          isActive: _isActive,

          // Mobile Fallback
          logoFile:
              (!kIsWeb && _logoFile != null) ? File(_logoFile!.path) : null,
          bannerFile:
              (!kIsWeb && _bannerFile != null) ? File(_bannerFile!.path) : null,
          assetFile:
              (!kIsWeb && _assetFile != null) ? File(_assetFile!.path) : null,
          // Web Support
          logoBytes: kIsWeb ? _logoBytes : null,
          bannerBytes: kIsWeb ? _bannerBytes : null,
          assetBytes: kIsWeb ? _assetBytes : null,
          logoExtension: _logoFile?.name.split('.').last,
          bannerExtension: _bannerFile?.name.split('.').last,
          assetExtension: _assetFile?.name.split('.').last,

          currentLogoUrl: widget.sponsor!.logoUrl,
          currentBannerUrl: widget.sponsor!.bannerUrl,
          currentAssetUrl: widget.sponsor!.minigameAssetUrl,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patrocinador guardado correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
    );

    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        elevation: 0,
        title: Text(
          widget.sponsor == null
              ? "Nuevo Patrocinador"
              : "Editar Patrocinador",
          style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Basic Info ---
                      _buildSectionTitle("Información Básica"),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color),
                        decoration: inputDecoration.copyWith(
                          labelText: "Nombre de la Marca/Patrocinador",
                          hintText: "Ej. Coca-Cola, Nike...",
                          prefixIcon: Icon(Icons.abc, color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa un nombre'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedPlan,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color),
                        decoration: inputDecoration.copyWith(
                          labelText: "Plan",
                          prefixIcon:
                              Icon(Icons.star, color: AppTheme.lGoldAction),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'bronce', child: Text("BRONCE (Básico)")),
                          DropdownMenuItem(
                              value: 'plata',
                              child: Text("PLATA (Intermedio)")),
                          DropdownMenuItem(
                              value: 'oro', child: Text("ORO (Premium)")),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedPlan = val ?? 'bronce'),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Switch(
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            activeColor: AppTheme.lGoldAction,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isActive
                                ? "Activo (Visible en el juego)"
                                : "Inactivo",
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- Images ---
                      _buildSectionTitle("Imágenes y Assets"),
                      const SizedBox(height: 8),
                      Text(
                        "Sube las imágenes correspondientes para personalizar la experiencia.",
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      _buildImagePicker(
                        label: "Logo de la Marca",
                        description: "Visible en listas y créditos.",
                        type: 'logo',
                        file: _logoFile,
                        bytes: _logoBytes,
                        currentUrl: widget.sponsor?.logoUrl,
                        context: context,
                      ),
                      const SizedBox(height: 24),

                      _buildImagePicker(
                        label: "Banner Publicitario",
                        description: "Banner horizontal para menús.",
                        type: 'banner',
                        file: _bannerFile,
                        bytes: _bannerBytes,
                        currentUrl: widget.sponsor?.bannerUrl,
                        context: context,
                      ),
                      const SizedBox(height: 12),

                      _buildFormatGuidelines(),
                      const SizedBox(height: 16),

                      _buildBannerPreview(
                        context: context,
                        name: _nameController.text.trim(),
                        bytes: _bannerBytes,
                        file: _bannerFile,
                        currentUrl: widget.sponsor?.bannerUrl,
                      ),
                      const SizedBox(height: 32),

                      // PNG ENFORCEMENT ALERT
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.warningOrange, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.warningOrange, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "REQUISITO CRÍTICO",
                                    style: TextStyle(
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    "El asset para minijuegos DEBE ser PNG con fondo transparente.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildImagePicker(
                        label: "Asset Minijuego (La Manzana)",
                        description:
                            "Imagen PNG con fondo transparente (64x64px recomendado).",
                        type: 'asset',
                        file: _assetFile,
                        bytes: _assetBytes,
                        currentUrl: widget.sponsor?.minigameAssetUrl,
                        context: context,
                      ),

                      const SizedBox(height: 48),

                      // --- Save Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSponsor,
                          icon: const Icon(Icons.save),
                          label: const Text("GUARDAR PATROCINADOR"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.lGoldAction,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.lGoldAction,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String description,
    required String type,
    XFile? file,
    Uint8List? bytes,
    String? currentUrl,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold)),
        Text(description,
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickImage(type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), style: BorderStyle.solid),
            ),
            child: bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  )
                : file != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(file.path, fit: BoxFit.contain)
                            : Image.file(File(file.path), fit: BoxFit.contain),
                      )
                    : currentUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                Image.network(currentUrl, fit: BoxFit.contain),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), size: 40),
                              const SizedBox(height: 8),
                              Text("Toca para subir imagen",
                                  style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),
                            ],
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatGuidelines() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lGoldAction.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lGoldAction.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "FORMATOS RECOMENDADOS",
            style: TextStyle(
              color: AppTheme.lGoldAction,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Banner: 1200x260 px (ratio 4.6:1), PNG o WebP sin compresion agresiva.",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          SizedBox(height: 4),
          Text(
            "Logo: 512x512 px, PNG con fondo transparente para mejor legibilidad.",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          SizedBox(height: 4),
          Text(
            "Minijuego: PNG 64x64 px transparente (obligatorio).",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPreview({
    required BuildContext context,
    required String name,
    Uint8List? bytes,
    XFile? file,
    String? currentUrl,
  }) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final ImageProvider? previewProvider = _buildPreviewImageProvider(
      bytes: bytes,
      file: file,
      currentUrl: currentUrl,
    );

    if (previewProvider == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vista previa del banner",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
              color: Theme.of(context).cardTheme.color,
            ),
            child: Text(
              "Sube un banner para ver la previsualizacion",
              style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final previewSponsor = (widget.sponsor ?? Sponsor(
      id: 'preview',
      name: name.isEmpty ? 'Marca' : name,
      planType: 'oro',
      isActive: true,
      createdAt: DateTime.now(),
    )).copyWith(
      name: name.isEmpty ? 'Marca' : name,
      bannerUrl: null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Vista previa del banner",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SponsorBanner(
          sponsor: previewSponsor,
          bannerImageOverride: previewProvider,
        ),
      ],
    );
  }

  ImageProvider? _buildPreviewImageProvider({
    Uint8List? bytes,
    XFile? file,
    String? currentUrl,
  }) {
    if (bytes != null) return MemoryImage(bytes);
    if (file != null) {
      if (kIsWeb) {
        return NetworkImage(file.path);
      }
      return FileImage(File(file.path));
    }
    if (currentUrl != null && currentUrl.isNotEmpty) {
      return NetworkImage(currentUrl);
    }
    return null;
  }
}
