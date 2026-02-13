import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_cache_utils.dart';
import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../l10n/app_localizations.dart';

class ColorSelectionSection extends StatelessWidget {
  final ProductDetails productDetails;

  const ColorSelectionSection({
    super.key,
    required this.productDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (productDetails.colorOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.selectColor,
              style: AppFonts.getTextStyle(
                fontSize: ResponsiveConstants.mdFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.smPadding,
                vertical: ResponsiveConstants.xsPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(ResponsiveConstants.smRadius),
              ),
              child: Text(
                '${productDetails.colorOptions.length} ${AppLocalizations.of(context)!.colorsAvailable}',
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.xsFontSize,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: ResponsiveConstants.mdSpacing),
        
        // Color options - Single line with horizontal scrolling
        BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
          builder: (context, state) {
            // Get the latest product details from state
            final currentProductDetails = state is ProductDetailsLoaded 
                ? state.productDetails 
                : productDetails;
            
            return SizedBox(
              height: 140, // Reduced height - no "out of stock" text, just icon overlay
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: currentProductDetails.colorOptions.length,
                separatorBuilder: (context, index) => SizedBox(width: ResponsiveConstants.mdSpacing),
                itemBuilder: (context, index) {
                  final colorOption = currentProductDetails.colorOptions[index];
                  return _ColorOptionCard(
                    colorOption: colorOption,
                    productDetails: currentProductDetails,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ColorOptionCard extends StatelessWidget {
  final ColorOption colorOption;
  final ProductDetails productDetails;

  const _ColorOptionCard({
    required this.colorOption,
    required this.productDetails,
  });

  /// Get the English color name for matching
  /// CRITICAL: Always use English names for matching, never use Arabic display names
  String? _getEnglishColorName() {
    // Helper to check if a string contains Arabic characters
    bool containsArabic(String text) {
      if (text.isEmpty) return false;
      final arabicRegex = RegExp(r'[\u0600-\u06FF]');
      return arabicRegex.hasMatch(text);
    }
    
    // PRIMARY: Use ColorOption.name (guaranteed to be English per model parsing)
    // This is the most reliable source for English names
    if (!containsArabic(colorOption.name) && colorOption.name.trim().isNotEmpty) {
      debugPrint('🎨 ColorSelection: Using ColorOption.name (English):'
          ' "${colorOption.name}" for color ID ${colorOption.id} '
          '(display: "${colorOption.displayNameOrName}")');
      return colorOption.name;
    }
    
    // FALLBACK: Try to get from variantAttributeOptions (should be English, but verify)
    for (final opt in productDetails.variantAttributeOptions) {
      final attrNameLower = opt.attributeName.toLowerCase();
      if (attrNameLower == 'color name' || 
          attrNameLower == 'color' || 
          attrNameLower == 'colour' ||
          attrNameLower == 'اللون') {
        // Find the value that matches this color ID
        try {
          final matchedValue = opt.values.firstWhere(
            (v) => v.id == colorOption.id,
          );
          // Check if it's actually English and non-empty (empty causes "x".contains("")=true in Arabic)
          if (!containsArabic(matchedValue.name) && matchedValue.name.trim().isNotEmpty) {
            debugPrint('🎨 ColorSelection: Found English name from variantAttributeOptions: "${matchedValue.name}" for color ID ${colorOption.id} (display: "${colorOption.displayNameOrName}")');
            return matchedValue.name;
          } else {
            debugPrint('⚠️ ColorSelection: variantAttributeOptions has Arabic name "${matchedValue.name}" for color ID ${colorOption.id}');
          }
        } catch (e) {
          // ID not found, continue
        }
      }
    }
    
    debugPrint('❌ ColorSelection: No English name found for color "${colorOption.displayNameOrName}" (ID: ${colorOption.id})');
    return null;
  }

  /// Check if this color is available for the currently selected size.
  /// Uses entity methods so English and Arabic work the same (locale-agnostic).
  bool _isAvailableForCurrentSize() {
    if (productDetails.variantCombinations.isEmpty) return true;
    final colorName = colorOption.displayNameOrName;
    if (colorName.isEmpty) return true;

    String? selectedSize;
    for (final opt in productDetails.variantAttributeOptions) {
      final attrNameLower = opt.attributeName.toLowerCase();
      if ((attrNameLower == 'size' ||
              attrNameLower == productDetails.primaryVariantLabel.toLowerCase() ||
              attrNameLower.contains('size') ||
              attrNameLower.contains('قياس') ||
              attrNameLower.contains('مقاس')) &&
          opt.selectedValue.isNotEmpty) {
        selectedSize = opt.selectedValue;
        break;
      }
    }
    if (selectedSize == null && productDetails.selectedSize.isNotEmpty) {
      selectedSize = productDetails.selectedSize;
    }

    if (selectedSize == null || selectedSize.isEmpty) {
      return productDetails.hasAnyInStockVariantForColor(colorName);
    }
    const sizeAttrNames = ['SIZE', 'size', 'Size', 'القياس', 'قياس', 'مقاس'];
    for (final attrName in sizeAttrNames) {
      if (productDetails.hasInStockVariantForColorAndAttributeValue(
        colorName: colorName,
        attributeName: attrName,
        valueName: selectedSize)) {
        return true;
      }
    }
    if (productDetails.primaryVariantLabel.isNotEmpty &&
        productDetails.hasInStockVariantForColorAndAttributeValue(
          colorName: colorName,
          attributeName: productDetails.primaryVariantLabel,
          valueName: selectedSize)) {
      return true;
    }
    return false;
  }

  /// Check if this color is available based on stock and current selections
  /// NOTE: This method is kept as a fallback, but the widget should use colorOption.isAvailable
  /// from the BLoC instead, which has correct English name matching logic.
  /// This method may have issues with Arabic names, so it's deprecated.
  @Deprecated('Use colorOption.isAvailable from BLoC instead')
  bool _isAvailable() {
    // If no variant combinations exist, assume available (fallback)
    if (productDetails.variantCombinations.isEmpty) {
      debugPrint('⚠️ ColorSelection: No variant combinations, defaulting to available for "${colorOption.name}"');
      return true;
    }
    
    // CRITICAL: Get the English color name from variantAttributeOptions
    // NEVER use colorOption.name for matching as it's in Arabic (display only)
    final englishColorName = _getEnglishColorName();
    
    // If we can't find the English name, we can't match against variants
    if (englishColorName == null || englishColorName.isEmpty) {
      debugPrint('⚠️ ColorSelection: No English name found for "${colorOption.name}", defaulting to available');
      return true; // Default to available if we can't determine (better UX)
    }
    
    String normalize(String s) {
      if (s.isEmpty) return '';
      // Normalize: lowercase, trim, remove extra spaces
      return s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    
    // ONLY use English name from variantAttributeOptions for matching
    // Never use colorOption.name (Arabic display name)
    final List<String> colorNamesToTry = [englishColorName];
    
    // Also try without trailing numbers (e.g., "BLACK 01" -> "black", "CREAM 985" -> "cream")
    final withoutNumbers = englishColorName.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
    if (withoutNumbers.isNotEmpty && withoutNumbers != englishColorName) {
      colorNamesToTry.add(withoutNumbers);
    }
    
    debugPrint('🔍 ColorSelection: Matching "${colorOption.name}" using English names: $colorNamesToTry');
    
    // Get the actual SIZE value from variantAttributeOptions
    String? actualSize;
    for (final opt in productDetails.variantAttributeOptions) {
      if (opt.attributeName.toUpperCase() == 'SIZE' && opt.selectedValue.isNotEmpty) {
        actualSize = opt.selectedValue;
        break;
      }
    }
    // Fallback to selectedSize if numeric
    if (actualSize == null && productDetails.selectedSize.isNotEmpty) {
      final sizeValue = productDetails.selectedSize;
      if (RegExp(r'^\d+').hasMatch(sizeValue)) {
        actualSize = sizeValue;
      }
    }

    // Check if this color has any in-stock variants
    bool hasInStockVariant = false;
    bool colorFoundInVariants = false;
    
    // Helper to get color value from variant trying multiple attribute names
    String? getVariantColorValue(VariantCombination v) {
      final colorAttrNames = ['COLOR NAME', 'color name', 'Color Name', 'color', 'Color', 'COLOR', 'colour', 'Colour', 'اللون', 'لون'];
      for (final attrName in colorAttrNames) {
        final value = v.getAttributeValue(attrName);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }
    
    // Helper function to check if variant matches color using English names only
    bool doesVariantMatchColor(VariantCombination v) {
      final variantColorName = getVariantColorValue(v);
      if (variantColorName == null || variantColorName.isEmpty) {
        return false;
      }
      
      final normalizedVariantColor = normalize(variantColorName);
      
      // Try matching against English color names ONLY (never Arabic)
      for (final englishColorNameToTry in colorNamesToTry) {
        if (englishColorNameToTry.isEmpty) continue; // Empty causes "x".contains("")=true (Arabic bug)
        final normalizedColorName = normalize(englishColorNameToTry);
        if (normalizedColorName.isEmpty) continue;
        
        // Exact match
        if (normalizedVariantColor == normalizedColorName) {
          debugPrint('✅ ColorSelection: Exact match found: variant "${variantColorName}" == English "${englishColorNameToTry}"');
          return true;
        }
        
        // Partial match (e.g., "BLACK 01" matches "black")
        if (normalizedVariantColor.startsWith(normalizedColorName) || 
            normalizedColorName.startsWith(normalizedVariantColor)) {
          debugPrint('✅ ColorSelection: Partial match found: variant "${variantColorName}" ~= English "${englishColorNameToTry}"');
          return true;
        }
        
        // Try removing numbers and matching (e.g., "BLACK 01" vs "black")
        final variantWithoutNumbers = normalizedVariantColor.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
        final colorWithoutNumbers = normalizedColorName.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
        if (variantWithoutNumbers.isNotEmpty && 
            colorWithoutNumbers.isNotEmpty && 
            variantWithoutNumbers == colorWithoutNumbers) {
          debugPrint('✅ ColorSelection: Match after removing numbers: variant "${variantColorName}" ~= English "${englishColorNameToTry}"');
          return true;
        }
      }
      
      return false;
    }
    
    if (actualSize != null && actualSize.isNotEmpty) {
      // Size is selected - check if this color has stock with this size
      for (final v in productDetails.variantCombinations) {
        final bool sizeMatch = v.hasAttributeValue('SIZE', actualSize) ||
                             v.hasAttributeValue('size', actualSize) ||
                             v.hasAttributeValue(productDetails.primaryVariantLabel, actualSize);
        if (!sizeMatch) continue;
        
        final colorMatch = doesVariantMatchColor(v);
        if (colorMatch) {
          colorFoundInVariants = true;
          // Check stock: must have quantity_available > 0 AND in_stock = true
          final qty = v.quantityAvailable ?? 0.0;
          final isInStock = v.inStock && qty > 0;
          if (isInStock) {
            hasInStockVariant = true;
            debugPrint('✅ ColorSelection: Found in-stock variant for ${colorOption.name} (size: $actualSize), variantId: ${v.variantId}, inStock: ${v.inStock}, qty: $qty');
            break;
          } else {
            debugPrint('❌ ColorSelection: Found variant for ${colorOption.name} but out of stock, variantId: ${v.variantId}, inStock: ${v.inStock}, qty: $qty');
          }
        }
      }
    } else {
      // No size selected - check if color has any in-stock variants at all
      for (final v in productDetails.variantCombinations) {
        final colorMatch = doesVariantMatchColor(v);
        if (colorMatch) {
          colorFoundInVariants = true;
          // Check stock: must have quantity_available > 0 AND in_stock = true
          final qty = v.quantityAvailable ?? 0.0;
          final isInStock = v.inStock && qty > 0;
          if (isInStock) {
            hasInStockVariant = true;
            debugPrint('✅ ColorSelection: Found in-stock variant for ${colorOption.name}, variantId: ${v.variantId}, inStock: ${v.inStock}, qty: $qty');
            break;
          } else {
            debugPrint('❌ ColorSelection: Found variant for ${colorOption.name} but out of stock, variantId: ${v.variantId}, inStock: ${v.inStock}, qty: $qty');
          }
        }
      }
    }

    // If we found the color but it's out of stock, return false
    if (colorFoundInVariants && !hasInStockVariant) {
      debugPrint('⚠️ ColorSelection: Color ${colorOption.name} exists but all variants are out of stock');
      return false;
    }
    
    // If we didn't find the color at all, default to available (might be matching issue)
    if (!colorFoundInVariants) {
      debugPrint('⚠️ ColorSelection: Could not find variant for ${colorOption.name}, defaulting to available');
      return true; // Default to available if we can't match (better UX)
    }

    return hasInStockVariant;
  }

  /// Same attribute names as bloc so English API (e.g. "Color") is supported.
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

  /// Get the first variant image for this color (locale-agnostic: entity matches Arabic/English).
  String _getColorImageUrl() {
    final colorName = colorOption.displayNameOrName;
    if (colorName.isEmpty) {
      return colorOption.images.isNotEmpty
          ? ImageCacheUtils.normalizeImageUrl(colorOption.images.first)
          : '';
    }

    String norm(String s) => s.toLowerCase().trim();
    for (final v in productDetails.variantCombinations) {
      final variantColorName = _getVariantColorValue(v);
      if (variantColorName == null || variantColorName.isEmpty || v.variantId.isEmpty) continue;
      final matches = norm(variantColorName) == norm(colorName) ||
          norm(variantColorName) == norm(colorOption.name) ||
          (colorOption.displayName != null &&
              colorOption.displayName!.isNotEmpty &&
              norm(variantColorName) == norm(colorOption.displayName!));
      if (!matches) continue;
      final list = productDetails.variantImagesMap[v.variantId];
      if (list != null && list.isNotEmpty) {
        return ImageCacheUtils.normalizeImageUrl(list.first);
      }
      final path = '/web/image/product.product/${v.variantId}/image_1920';
      return ImageCacheUtils.normalizeImageUrl(path);
    }

    if (colorOption.images.isNotEmpty) {
      return ImageCacheUtils.normalizeImageUrl(colorOption.images.first);
    }
    return productDetails.images.isNotEmpty
        ? ImageCacheUtils.normalizeImageUrl(productDetails.images.first)
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = colorOption.isSelected;
    // Use availability from BLoC (now properly updated when size/color changes)
    // The BLoC recalculates color availability based on selected size in both _onSelectSize and _onSelectColor
    final isAvailable = colorOption.isAvailable;
    final bool isDisabled = !isAvailable;
    final imageUrl = _getColorImageUrl();
    
    if (isSelected) {
      debugPrint(
        '🔴 [ColorSelectionSection] Color SHOWING SELECTED: "${colorOption.displayNameOrName}" (id=${colorOption.id}) '
        'isAvailable=$isAvailable - from colorOption.isSelected (BLoC state)',
      );
    }

    // Unclickable when: only one color, or only one available (no meaningful choice)
    final availableCount =
        productDetails.colorOptions.where((c) => c.isAvailable).length;
    final hasMultipleChoices =
        productDetails.colorOptions.length > 1 && availableCount > 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasMultipleChoices
          ? () {
              debugPrint('🎨 ColorSelectionSection: Tapped color "${colorOption.displayNameOrName}" (ID: ${colorOption.id})');
              context.read<ProductDetailsBloc>().add(
                    SelectColorEvent(
                      productId: productDetails.id,
                      colorId: colorOption.id,
                    ),
                  );
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Color image/swatch
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
                border: isDisabled
                    ? Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      )
                    : Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1.5,
                      ),
                boxShadow: isDisabled
                    ? null // No shadow for out-of-stock items
                    : (isSelected && isAvailable
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius - 1),
                child: Builder(
                  builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Color image with grayscale filter when disabled
                        if (imageUrl.isNotEmpty)
                          ColorFiltered(
                            colorFilter: isDisabled
                                ? const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0, // Grayscale
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 0.5, 0, // Reduce opacity
                                  ])
                                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              cacheKey: imageUrl, // Use normalized URL as cache key
                              fit: BoxFit.fill,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surface,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surface,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: colorScheme.surface,
                            child: Icon(
                              Icons.palette_outlined,
                              color: isDisabled
                                  ? colorScheme.onSurface.withValues(alpha: 0.3)
                                  : colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 32,
                            ),
                          ),
                        
                        // Grey fill background + "out of stock" icon when this color has no stock
                        if (isDisabled) ...[
                          // Grey fill background overlay
                          Container(
                            color: Colors.grey.withValues(alpha: 0.7),
                          ),
                          // "No stock" block icon centered
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.block,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                        
                        // Selected indicator
                        if (isSelected && isAvailable)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                color: colorScheme.onPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveConstants.xsSpacing), // Reduced spacing
            
            // Color name - Single line with ellipsis (no "out of stock" text to prevent overflow)
            Flexible(
              child: Text(
                colorOption.displayNameOrName,
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.smFontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isAvailable
                      ? (isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}