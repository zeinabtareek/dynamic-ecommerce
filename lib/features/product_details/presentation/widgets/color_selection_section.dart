import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_cache_utils.dart';
import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import '../controllers/dynamic_variant_controller.dart' show DynamicVariantController, ValueState;
import '../../../../core/theme/app_fonts.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';

class ColorSelectionSection extends StatelessWidget {
  final ProductDetails productDetails;
  final ScrollController? scrollController;
  final VoidCallback? onAfterAttributeSelected;

  const ColorSelectionSection({
    super.key,
    required this.productDetails,
    this.scrollController,
    this.onAfterAttributeSelected,
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
        
        // Color options - Single line with horizontal scrolling + scroll indicators
        Consumer<DynamicVariantController>(
          builder: (context, variantController, _) {
            return BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
              builder: (context, state) {
                // Get the latest product details from state
                final currentProductDetails = state is ProductDetailsLoaded
                    ? state.productDetails
                    : productDetails;

                debugPrint('🎨 ColorSelectionSection: Rendering ${currentProductDetails.colorOptions.length} colors');

                if (currentProductDetails.colorOptions.isEmpty) {
                  debugPrint('⚠️ ColorSelectionSection: No color options available');
                  return const SizedBox.shrink();
                }

                return _ColorListWithIndicators(
                  productDetails: currentProductDetails,
                  pageScrollController: scrollController,
                  onAfterAttributeSelected: onAfterAttributeSelected,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Horizontal color list with scroll position indicators (dots).
/// Indicator count is dynamic from [productDetails.colorOptions.length].
class _ColorListWithIndicators extends StatefulWidget {
  final ProductDetails productDetails;
  final ScrollController? pageScrollController;
  final VoidCallback? onAfterAttributeSelected;

  const _ColorListWithIndicators({
    required this.productDetails,
    this.pageScrollController,
    this.onAfterAttributeSelected,
  });

  @override
  State<_ColorListWithIndicators> createState() => _ColorListWithIndicatorsState();
}

class _ColorListWithIndicatorsState extends State<_ColorListWithIndicators> {
  late ScrollController _listScrollController;
  static const double _colorCardWidth = 100;
  DynamicVariantController? _variantController;
  bool _scrollEndListenerAttached = false;
  ValueNotifier<bool>? _isScrollingNotifier;
  /// Until the user taps a color or scrolls, we keep the list fixed on the selected index
  /// so the catalog-driven selection is not overwritten by scroll position.
  bool _hasUserInteractedWithColorList = false;

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController();
    _listScrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<DynamicVariantController>();
    if (controller != _variantController) {
      _variantController?.removeListener(_onVariantSelectionChanged);
      _variantController = controller;
      _variantController!.addListener(_onVariantSelectionChanged);
    }
    _attachScrollEndListener();
  }

  void _attachScrollEndListener() {
    if (_scrollEndListenerAttached || !_listScrollController.hasClients) return;
    _isScrollingNotifier = _listScrollController.position.isScrollingNotifier;
    _isScrollingNotifier!.addListener(_onScrollingChanged);
    _scrollEndListenerAttached = true;
  }

  void _onScrollingChanged() {
    if (_listScrollController.position.isScrollingNotifier.value) return;
    _onScrollEnd();
  }

  void _onScrollEnd() {
    if (!mounted || _variantController == null) return;
    // On initial load, do not sync selection from scroll position so catalog selection stays correct.
    if (!_hasUserInteractedWithColorList) return;
    final colorAttributeId = _getColorAttributeId();
    if (colorAttributeId == null) return;
    final colorOptions = widget.productDetails.colorOptions;
    final count = colorOptions.length;
    if (count <= 1) return;
    final extent = _colorCardWidth + ResponsiveConstants.mdSpacing;
    final offset = _listScrollController.offset.clamp(0.0, double.infinity);
    final index = (offset / extent).round().clamp(0, count - 1);
    final selectedValueId = _variantController!.selectedAttributes[colorAttributeId];
    final colorAtIndex = colorOptions[index];
    final valueIdAtIndex = int.tryParse(colorAtIndex.id);
    if (valueIdAtIndex != null && valueIdAtIndex != selectedValueId) {
      if (mounted) {
        final state = context.read<ProductDetailsBloc>().state;
        if (state is ProductDetailsLoaded) {
          _variantController!.updateProductDetails(state.productDetails);
          _variantController!.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
        }
      }
      _variantController!.selectAttributeValue(colorAttributeId, valueIdAtIndex);
      widget.onAfterAttributeSelected?.call();
    }
  }

  void _onVariantSelectionChanged() {
    if (!mounted) return;
    if (_listScrollController.hasClients &&
        _listScrollController.position.isScrollingNotifier.value) {
      return;
    }
    final colorAttributeId = _getColorAttributeId();
    if (colorAttributeId == null || _variantController == null) return;
    final selectedValueId = _variantController!.selectedAttributes[colorAttributeId];
    if (selectedValueId == null) return;
    final colorOptions = widget.productDetails.colorOptions;
    final count = colorOptions.length;
    if (count <= 1) return;
    final idx = colorOptions.indexWhere((c) => int.tryParse(c.id) == selectedValueId);
    if (idx < 0 || idx >= count) return;
    if (idx != _currentIndex) {
      setState(() => _currentIndex = idx);
      if (_hasUserInteractedWithColorList) {
        _scrollToIndex(idx);
      } else {
        _jumpToIndex(idx);
      }
    }
  }

  void _onScroll() {
    if (!mounted || !_listScrollController.hasClients) return;
    _attachScrollEndListener();
    // On initial load, do not update _currentIndex from scroll so selected index stays correct.
    if (!_hasUserInteractedWithColorList) return;
    final count = widget.productDetails.colorOptions.length;
    if (count <= 1) return;
    final extent = _colorCardWidth + ResponsiveConstants.mdSpacing;
    final offset = _listScrollController.offset.clamp(0.0, double.infinity);
    final index = (offset / extent).round().clamp(0, count - 1);
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  int _currentIndex = 0;

  int? _getColorAttributeId() {
    for (final opt in widget.productDetails.variantAttributeOptions) {
      final n = opt.attributeName.toLowerCase();
      if (n == 'color name' || n == 'color' || n == 'colour' || n == 'اللون') {
        final id = int.tryParse(opt.attributeId ?? '');
        if (id != null) return id;
        break;
      }
    }
    return null;
  }

  void _scrollToIndex(int index) {
    if (!_listScrollController.hasClients) return;
    final count = widget.productDetails.colorOptions.length;
    if (count <= 1) return;
    final extent = _colorCardWidth + ResponsiveConstants.mdSpacing;
    final targetOffset = (index * extent).clamp(
      0.0,
      _listScrollController.position.maxScrollExtent,
    );
    _listScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Jumps to index without animation. Used on initial load so the list shows the selected
  /// color and does not trigger scroll listeners that could change selection.
  void _jumpToIndex(int index) {
    if (!_listScrollController.hasClients) return;
    final count = widget.productDetails.colorOptions.length;
    if (count <= 1) return;
    final extent = _colorCardWidth + ResponsiveConstants.mdSpacing;
    final targetOffset = (index * extent).clamp(
      0.0,
      _listScrollController.position.maxScrollExtent,
    );
    _listScrollController.jumpTo(targetOffset);
  }

  @override
  void dispose() {
    _isScrollingNotifier?.removeListener(_onScrollingChanged);
    _isScrollingNotifier = null;
    _scrollEndListenerAttached = false;
    _variantController?.removeListener(_onVariantSelectionChanged);
    _variantController = null;
    _listScrollController.removeListener(_onScroll);
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorOptions = widget.productDetails.colorOptions;
    final count = colorOptions.length;

    return Consumer<DynamicVariantController>(
      builder: (context, variantController, _) {
        final colorAttributeId = _getColorAttributeId();
        int? selectedColorIndex;
        if (colorAttributeId != null) {
          final selectedValueId = variantController.selectedAttributes[colorAttributeId];
          if (selectedValueId != null) {
            final idx = colorOptions.indexWhere(
              (c) => int.tryParse(c.id) == selectedValueId,
            );
            if (idx >= 0) selectedColorIndex = idx;
          }
        }

        // When selection changes from tap (top or bottom), update indicator and scroll list
        // Skip programmatic scroll if user is currently dragging so the list doesn't retract
        if (selectedColorIndex != null &&
            selectedColorIndex! >= 0 &&
            selectedColorIndex! < count &&
            selectedColorIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = selectedColorIndex!);
            final isUserScrolling = _listScrollController.hasClients &&
                _listScrollController.position.isScrollingNotifier.value;
            if (!isUserScrolling) {
              if (_hasUserInteractedWithColorList) {
                _scrollToIndex(selectedColorIndex!);
              } else {
                _jumpToIndex(selectedColorIndex!);
              }
            }
          });
        }

        final effectiveIndex = (selectedColorIndex ?? _currentIndex).clamp(0, count - 1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final width = maxW.isFinite && maxW > 0
                    ? maxW
                    : MediaQuery.sizeOf(context).width;
                return SizedBox(
                  width: width,
                  height: 140,
                  child: ListView.separated(
                    controller: _listScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: count,
                    separatorBuilder: (_, __) => SizedBox(width: ResponsiveConstants.mdSpacing),
                    itemBuilder: (context, index) {
                      final colorOption = colorOptions[index];
                      return _ColorOptionCard(
                        colorOption: colorOption,
                        productDetails: widget.productDetails,
                        scrollController: widget.pageScrollController,
                        itemIndex: index,
                        onAfterAttributeSelected: widget.onAfterAttributeSelected,
                        onSelected: (int selectedIndex) {
                          if (!_hasUserInteractedWithColorList) {
                            setState(() => _hasUserInteractedWithColorList = true);
                          }
                          setState(() => _currentIndex = selectedIndex);
                          _scrollToIndex(selectedIndex);
                        },
                      );
                    },
                  ),
                );
              },
            ),
            if (count > 1) ...[
              SizedBox(height: ResponsiveConstants.smSpacing),
              _ScrollIndicators(
                itemCount: count,
                currentIndex: effectiveIndex,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Dot indicators for horizontal list scroll position.
class _ScrollIndicators extends StatelessWidget {
  final int itemCount;
  final int currentIndex;

  const _ScrollIndicators({
    required this.itemCount,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        itemCount,
        (index) {
          final isActive = index == currentIndex;
          return Container(
            margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.xsSpacing / 2),
            width: isActive ? 8 : 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? primary
                  : onSurface.withValues(alpha: 0.3),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton placeholder shown while a color thumbnail image is loading.
class _ColorImageSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ColorImageSkeleton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? colorScheme.outline.withValues(alpha: 0.3)
        : Colors.grey.shade300;
    final highlightColor =
        isDark ? colorScheme.outline.withValues(alpha: 0.5) : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius - 1),
        ),
      ),
    );
  }
}

class _ColorOptionCard extends StatelessWidget {
  final ColorOption colorOption;
  final ProductDetails productDetails;
  final ScrollController? scrollController;
  final int itemIndex;
  final VoidCallback? onAfterAttributeSelected;
  final void Function(int index)? onSelected;

  const _ColorOptionCard({
    required this.colorOption,
    required this.productDetails,
    this.scrollController,
    required this.itemIndex,
    this.onAfterAttributeSelected,
    this.onSelected,
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

  /// Check if this color is available for the currently selected size
  /// This checks availability dynamically based on the current size selection
  bool _isAvailableForCurrentSize() {
    // If no variant combinations exist, assume available (fallback)
    if (productDetails.variantCombinations.isEmpty) {
      return true;
    }
    
    // Get the English color name for matching
    final englishColorName = _getEnglishColorName();
    if (englishColorName == null || englishColorName.isEmpty) {
      return true; // Default to available if we can't determine
    }
    
    String normalize(String s) => s.toLowerCase().trim();
    
    // Get the currently selected size
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
    
    // Helper to get color value from variant
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
    
    // Check if this color-size combination is in stock
    if (selectedSize != null && selectedSize.isNotEmpty) {
      // Size is selected - check if this color has stock with this size
      for (final v in productDetails.variantCombinations) {
        final bool sizeMatch = v.hasAttributeValue('SIZE', selectedSize) ||
                             v.hasAttributeValue('size', selectedSize) ||
                             v.hasAttributeValue(productDetails.primaryVariantLabel, selectedSize);
        if (!sizeMatch) continue;
        
        final variantColorName = getVariantColorValue(v);
        if (variantColorName == null) continue;
        
        final normalizedVariant = normalize(variantColorName);
        final normalizedColor = normalize(englishColorName);
        
        final bool colorMatch = normalizedVariant == normalizedColor ||
                              normalizedVariant.contains(normalizedColor) ||
                              normalizedColor.contains(normalizedVariant);
        
        if (colorMatch) {
          final qty = v.quantityAvailable ?? 0.0;
          final isInStock = v.inStock && qty > 0;
          if (isInStock) {
            return true; // Found in-stock variant for this color-size combination
          }
        }
      }
      // No in-stock variant found for this color-size combination
      return false;
    } else {
      // No size selected - check if color has any in-stock variants at all
      for (final v in productDetails.variantCombinations) {
        final variantColorName = getVariantColorValue(v);
        if (variantColorName == null) continue;
        
        final normalizedVariant = normalize(variantColorName);
        final normalizedColor = normalize(englishColorName);
        
        final bool colorMatch = normalizedVariant == normalizedColor ||
                              normalizedVariant.contains(normalizedColor) ||
                              normalizedColor.contains(normalizedVariant);
        
        if (colorMatch) {
          final qty = v.quantityAvailable ?? 0.0;
          final isInStock = v.inStock && qty > 0;
          if (isInStock) {
            return true;
          }
        }
      }
      return false;
    }
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

  /// Get the first variant image for this color (English: use same color attr names + flexible match).
  String _getColorImageUrl() {
    final englishColorName = _getEnglishColorName();
    if (englishColorName == null) {
      return colorOption.images.isNotEmpty
          ? ImageCacheUtils.normalizeImageUrl(colorOption.images.first)
          : '';
    }

    String normalize(String s) => s.toLowerCase().trim();
    final nEnglish = normalize(englishColorName);

    for (final v in productDetails.variantCombinations) {
      final variantColorName = _getVariantColorValue(v);
      if (variantColorName == null || variantColorName.isEmpty || v.variantId.isEmpty) continue;
      final nV = normalize(variantColorName);
      final colorMatch = nV == nEnglish || nV.contains(nEnglish) || nEnglish.contains(nV);
      if (colorMatch) {
        final list = productDetails.variantImagesMap[v.variantId];
        if (list != null && list.isNotEmpty) {
          return ImageCacheUtils.normalizeImageUrl(list.first);
        }
        final path = '/web/image/product.product/${v.variantId}/image_1920';
        return ImageCacheUtils.normalizeImageUrl(path);
      }
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
    return Consumer<DynamicVariantController>(
      builder: (context, variantController, _) {
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
        final colorValueId = int.tryParse(colorOption.id);
        
        // Get selected value_id for color attribute
        final selectedColorValueId = colorAttributeId != null
            ? variantController.selectedAttributes[colorAttributeId]
            : null;

        // Determine value state from the dynamic variant controller.
        // - fullyAvailable: in-stock and compatible with current selection
        // - existsButIncompatible: in-stock somewhere, but not with current selection
        // - doesNotExist: no in-stock variants for this value at all
        final ValueState valueState =
            colorAttributeId != null && colorValueId != null
                ? variantController.getValueState(colorAttributeId, colorValueId)
                : ValueState.fullyAvailable;

        // Treat both fullyAvailable and existsButIncompatible as "available" for selection.
        // Only values that truly do not exist in any in-stock variant are disabled.
        final bool isAvailable = valueState != ValueState.doesNotExist;
        final bool isDisabled = !isAvailable;
        // Use controller selection when present; otherwise use model's isSelected (from selected_variant in first API)
        final bool isSelected = selectedColorValueId != null
            ? selectedColorValueId == colorValueId
            : colorOption.isSelected;
        final imageUrl = _getColorImageUrl();
        
        debugPrint('🎨 ColorSelection: "${colorOption.displayNameOrName}" (value_id: $colorValueId)');
        debugPrint('   Available: $isAvailable, Selected: $isSelected');
        debugPrint('   Selected value_id in controller: $selectedColorValueId');
        debugPrint('   Controller selectedAttributes: ${variantController.selectedAttributes}');

        // Allow tap on any available color (exists in at least one in-stock variant),
        // even if it is currently incompatible with the chosen size/material.
        // This lets the user switch from an out-of-stock color to another color.
        final bool canTap =
            colorAttributeId != null && colorValueId != null && isAvailable;
        
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTap
              ? () async {
                  debugPrint('🎨 ColorSelectionSection (Bottom): Tapped color "${colorOption.displayNameOrName}" (value_id: $colorValueId, attribute_id: $colorAttributeId)');
                  await HapticService.buttonClick();
                  // Sync with latest product details and variant_combinations from normal API
                  final state = context.read<ProductDetailsBloc>().state;
                  if (state is ProductDetailsLoaded) {
                    variantController.updateProductDetails(state.productDetails);
                    variantController.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
                  }
                  variantController.selectAttributeValue(colorAttributeId!, colorValueId!);
                  onAfterAttributeSelected?.call();
                  // Update indicator and scroll list to bring selected color into view
                  onSelected?.call(itemIndex);

                  // Animate scroll to top (main image area)
                  if (scrollController != null && scrollController!.hasClients) {
                    scrollController!.animateTo(
                      0,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
                    );
                  }
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
                              placeholder: (context, url) => _ColorImageSkeleton(
                                colorScheme: colorScheme,
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
                        
                        // Selected indicator - show checkmark when selected (regardless of availability)
                        // This ensures visual consistency: if selected, show checkmark
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isAvailable ? colorScheme.primary : Colors.grey.shade600,
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
                                isAvailable ? Icons.check : Icons.block,
                                color: Colors.white,
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
      },
    );
  }
}