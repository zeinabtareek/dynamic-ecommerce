import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../bloc/product_details_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../bloc/product_details_bloc.dart';
import '../controllers/dynamic_variant_controller.dart';
import '../../domain/entities/product_details.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_cache_utils.dart';
import '../../../../l10n/app_localizations.dart';

class ColorSelectionWidget extends StatelessWidget {
  final ProductDetails productDetails;
  final VoidCallback? onAfterAttributeSelected;

  const ColorSelectionWidget({
    super.key,
    required this.productDetails,
    this.onAfterAttributeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: ResponsiveConstants.mdSpacing,
      left: ResponsiveConstants.mdSpacing,
      right: ResponsiveConstants.mdSpacing,
      child: productDetails.colorOptions.isEmpty
          ? ColorSelectionSkeleton(colorScheme: Theme.of(context).colorScheme)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColorLabel(context),
                SizedBox(height: ResponsiveConstants.smSpacing),
                _buildColorThumbnails(context, onAfterAttributeSelected),
              ],
            ),
    );
  }

  Widget _buildColorLabel(BuildContext context) {
    return Consumer<DynamicVariantController>(
      builder: (context, variantController, _) {
        final l10n = AppLocalizations.of(context)!;
        
        // Find color attribute_id from variantAttributeOptions
        int? colorAttributeId;
        for (final opt in productDetails.variantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();
          if (attrNameLower == 'color name' || 
              attrNameLower == 'color' || 
              attrNameLower == 'colour' ||
              attrNameLower == 'اللون') {
            final attrId = int.tryParse(opt.attributeId ?? '');
            if (attrId != null) {
              colorAttributeId = attrId;
              break;
            }
          }
        }
        
        // Get selected value_id from controller (from second API / full variant data)
        final selectedColorValueId = colorAttributeId != null 
            ? variantController.selectedAttributes[colorAttributeId] 
            : null;
        
        // Find the ColorOption that matches the selected value_id, or from model's isSelected (first API selected_variant)
        ColorOption? selectedOpt;
        if (selectedColorValueId != null) {
          selectedOpt = productDetails.colorOptions.firstWhere(
            (c) => int.tryParse(c.id) == selectedColorValueId,
            orElse: () => productDetails.colorOptions.first,
          );
        } else {
          // Fallback: use model's isSelected (set from selected_variant in first API response)
          final withSelected = productDetails.colorOptions.where((c) => c.isSelected).toList();
          selectedOpt = withSelected.isNotEmpty
              ? withSelected.first
              : (productDetails.colorOptions.isNotEmpty ? productDetails.colorOptions.first : null);
        }
        
        if (selectedOpt == null) {
          return const SizedBox.shrink();
        }
        
        final label = selectedOpt.displayNameOrName;
        
        debugPrint('🎨 ColorSelectionWidget._buildColorLabel: Selected color "${label}" (value_id: $selectedColorValueId)');
        
        return Text(
          '${l10n.color}: ${label.toLowerCase()}',
          style: AppFonts.getTextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            shadows: [
              Shadow(
                offset: Offset(0, 1.h),
                blurRadius: 4.r,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.9),
              ),
              Shadow(
                offset: Offset(0, 1.h),
                blurRadius: 2.r,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorThumbnails(BuildContext context, VoidCallback? onAfterAttributeSelected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: productDetails.colorOptions.map((color) {
          return _buildColorThumbnail(context, color, onAfterAttributeSelected);
        }).toList(),
      ),
    );
  }

  /// Same attribute names as bloc's _getVariantColorValue so English API (e.g. "Color") is supported.
  static const _colorAttrNames = [
    'COLOR NAME', 'color name', 'Color Name', 'color', 'Color', 'COLOR',
    'colour', 'Colour', 'اللون', 'لون',
  ];

  String? _getVariantColorValue(VariantCombination v) {
    for (final attrName in _colorAttrNames) {
      final value = v.getAttributeValue(attrName);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Get a thumbnail image for a color using variantCombinations.variantId
  /// and the grouped variant images (variantImagesMap) from ProductDetails.
  /// Supports both English name and Arabic displayName; uses same color attribute names as bloc.
  String _firstVariantImageForColor(ColorOption color) {
    String normalize(String s) => s.toLowerCase().trim();
    final List<VariantCombination> colorVariants = [];

    for (final v in productDetails.variantCombinations) {
      final variantColor = _getVariantColorValue(v);
      if (variantColor == null || variantColor.isEmpty || v.variantId.isEmpty) continue;
      final nV = normalize(variantColor);
      final nName = normalize(color.name);
      final nDisplay = color.displayName != null && color.displayName!.isNotEmpty
          ? normalize(color.displayName!)
          : '';
      final matchName = nV == nName || nV.contains(nName) || nName.contains(nV);
      final matchDisplay = nDisplay.isNotEmpty && (nV == nDisplay || nV.contains(nDisplay) || nDisplay.contains(nV));
      if (matchName || matchDisplay) {
        colorVariants.add(v);
      }
    }

    if (colorVariants.isEmpty) {
      // No variants for this color -> let caller fall back
      return '';
    }

    // Pick the variantId for this color that has the MOST images in variantImagesMap.
    String bestVariantId = colorVariants.first.variantId;
    int bestCount = -1;

    for (final v in colorVariants) {
      final String vid = v.variantId;
      final List<String> imgs =
          productDetails.variantImagesMap[vid] ?? const <String>[];
      if (imgs.length > bestCount) {
        bestCount = imgs.length;
        bestVariantId = vid;
      }
    }

    final List<String> bestImages =
        productDetails.variantImagesMap[bestVariantId] ?? const <String>[];

    if (bestImages.isNotEmpty) {
      return ImageCacheUtils.normalizeImageUrl(bestImages.first);
    }

    // Fallback: construct the standard variant image URL
    final String path = '/web/image/product.product/$bestVariantId/image_1920';
    return ImageCacheUtils.normalizeImageUrl(path);
  }

  Widget _buildColorThumbnail(BuildContext context, ColorOption color, VoidCallback? onAfterAttributeSelected) {
    return Consumer<DynamicVariantController>(
      builder: (context, variantController, _) {
        // Prefer a variant-based image (grouped by variantId), then color-level images, then product-level images.
        String thumbUrl = _firstVariantImageForColor(color);
        if (thumbUrl.isEmpty) {
          // Use images we already grouped per color in the model
          if (color.images.isNotEmpty) {
            thumbUrl = ImageCacheUtils.normalizeImageUrl(color.images.first);
          } else if (productDetails.images.isNotEmpty) {
            thumbUrl = ImageCacheUtils.normalizeImageUrl(productDetails.images.first);
          } else {
            thumbUrl = '';
          }
        }

        // Find color attribute_id from variantAttributeOptions
        int? colorAttributeId;
        for (final opt in productDetails.variantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();
          if (attrNameLower == 'color name' || 
              attrNameLower == 'color' || 
              attrNameLower == 'colour' ||
              attrNameLower == 'اللون') {
            final attrId = int.tryParse(opt.attributeId ?? '');
            if (attrId != null) {
              colorAttributeId = attrId;
              break;
            }
          }
        }

        // Get value_id from colorOption.id
        final colorValueId = int.tryParse(color.id);
        
        // Get selected value_id for color attribute from controller (second API)
        final selectedColorValueId = colorAttributeId != null 
            ? variantController.selectedAttributes[colorAttributeId] 
            : null;
        
        // Check if this color is selected: controller state, or model's isSelected (first API selected_variant)
        final isSelected = selectedColorValueId != null
            ? selectedColorValueId == colorValueId
            : color.isSelected;
        
        debugPrint('🎨 ColorSelectionWidget (Top): Color "${color.displayNameOrName}" (value_id: $colorValueId)');
        debugPrint('   Selected value_id: $selectedColorValueId, isSelected: $isSelected');

        // When only one color exists, no action - nothing to choose
        final hasMultipleColors = productDetails.colorOptions.length > 1;
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // Ensure taps are captured even on transparent areas
          onTap: hasMultipleColors && colorAttributeId != null && colorValueId != null
              ? () async {
                  debugPrint('🎨 ColorSelectionWidget (Top): Tapped color "${color.displayNameOrName}" (value_id: $colorValueId, attribute_id: $colorAttributeId)');
                  await HapticService.buttonClick();
                  // Sync with latest product details and variant_combinations from normal API
                  final state = context.read<ProductDetailsBloc>().state;
                  if (state is ProductDetailsLoaded) {
                    variantController.updateProductDetails(state.productDetails);
                    variantController.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
                  }
                  variantController.selectAttributeValue(colorAttributeId!, colorValueId!);
                  onAfterAttributeSelected?.call();
                }
          : null,
          child: Container(
            margin: EdgeInsets.only(right: ResponsiveConstants.productDetailsColorThumbnailSpacing),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(ResponsiveConstants.smRadius),
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                  : Theme.of(context).colorScheme.surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveConstants.smRadius),
              child: SizedBox(
                width: ResponsiveConstants.productDetailsColorThumbnailSize,
                height: ResponsiveConstants.productDetailsColorThumbnailSize,
                child: (thumbUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          final colorScheme = Theme.of(context).colorScheme;
                          return Container(
                            color: colorScheme.surface,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 20.w,
                            ),
                          );
                        },
                      )
                    : Builder(
                        builder: (context) {
                          final colorScheme = Theme.of(context).colorScheme;
                          return Container(
                            color: colorScheme.surface,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 20.w,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for the color selection overlay when no color data is available.
/// Matches the layout of the real widget (label + horizontal thumbnails).
class ColorSelectionSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const ColorSelectionSkeleton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? colorScheme.outline.withValues(alpha: 0.35)
        : Colors.grey.shade300;
    final highlightColor =
        isDark ? colorScheme.outline.withValues(alpha: 0.5) : Colors.grey.shade100;
    final thumbSize = ResponsiveConstants.productDetailsColorThumbnailSize;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 14,
            width: 90,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: ResponsiveConstants.smSpacing),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: ResponsiveConstants.productDetailsColorThumbnailSpacing),
                Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(ResponsiveConstants.smRadius),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
