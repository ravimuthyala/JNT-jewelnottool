import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RegistrationProfileUpload extends StatelessWidget {
  const RegistrationProfileUpload({
    super.key,
    required this.onTap,
    this.imageBytes,
    this.imageProvider,
    this.label,
    this.helperText,
    this.size = 88,
    this.focusNode,
  });

  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final ImageProvider? imageProvider;
  final String? label;
  final String? helperText;
  final double size;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final resolvedImage = imageBytes != null
        ? MemoryImage(imageBytes!) as ImageProvider
        : imageProvider;
    final hasImage = resolvedImage != null;

    final accessibleLabel =
        (label != null && label!.trim().isNotEmpty)
        ? '${hasImage ? 'Change' : 'Add'} ${label!.trim()}'
        : (hasImage ? 'Change photo' : 'Add photo');

    return Column(
      children: [
        Center(
          child: Semantics(
            button: true,
            label: accessibleLabel,
            hint: hasImage ? 'Uploaded. Opens photo options' : 'Opens photo options',
            child: Focus(
              focusNode: focusNode,
              child: GestureDetector(
              onTap: onTap,
              child: ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: size,
                      width: size,
                      decoration: BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCatBorderLight,
                          width: 1.4,
                        ),
                      ),
                      child: resolvedImage == null
                          ? const Icon(
                              Icons.camera_alt_outlined,
                              size: 26,
                              color: AppColors.blackCat,
                            )
                          : Image(
                              image: resolvedImage,
                              fit: BoxFit.cover,
                              width: size,
                              height: size,
                            ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        height: 24,
                        width: 24,
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppColors.blackCatBorderLight,
                          ),
                        ),
                        child: const Icon(
                          Icons.file_upload_outlined,
                          size: 16,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
        if (label != null && label!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
                fontFamily: 'Arial',
              ),
            ),
          ),
        ],
        if (helperText != null && helperText!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              helperText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.blackCat.withValues(alpha: 0.62),
                fontFamily: 'Arial',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
