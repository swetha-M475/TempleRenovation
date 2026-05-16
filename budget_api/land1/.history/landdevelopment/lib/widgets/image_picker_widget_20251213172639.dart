import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/colors.dart';

class ImagePickerWidget extends StatefulWidget {
  final int maxImages;
  final Function(List<String>) onImagesSelected;

  const ImagePickerWidget({
    super.key,
    required this.maxImages,
    required this.onImagesSelected,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  List<String> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return;

      for (final img in images) {
        if (_selectedImages.length >= widget.maxImages) break;
        _selectedImages.add(img.path);
      }

      setState(() {});
      widget.onImagesSelected(_selectedImages);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onImagesSelected(_selectedImages);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _selectedImages.length +
              (_selectedImages.length < widget.maxImages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              return _buildAddButton();
            }
            return _buildPreview(index);
          },
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${_selectedImages.length} / ${widget.maxImages} images selected',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.greyDark.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text('Add',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(
                  _selectedImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Image.file(
                  File(_selectedImages[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
