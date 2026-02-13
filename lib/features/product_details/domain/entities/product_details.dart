import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';

/// Represents a single attribute value in a variant combination coming from
/// `attribute_value_combinations.available_combination_values`.
class AttributeCombinationValue extends Equatable {
  final int id; // Backend value id (e.g. 296)
  final String value; // Slug, e.g. "size-40", "color-black"

  const AttributeCombinationValue({
    required this.id,
    required this.value,
  });

  @override
  List<Object?> get props => [id, value];
}

/// Represents a single variant combination derived from `attribute_value_combinations`.
/// This is a normalized, variant-centric view that includes:
/// - variant_id
/// - quantity_available
/// - in_stock
/// - full list of attribute values (id + slug) that define this variant.
class AttributeVariantCombination extends Equatable {
  final int variantId;
  final double quantityAvailable;
  final bool inStock;
  final List<AttributeCombinationValue> values;

  const AttributeVariantCombination({
    required this.variantId,
    required this.quantityAvailable,
    required this.inStock,
    required this.values,
  });

  @override
  List<Object?> get props => [variantId, quantityAvailable, inStock, values];
}

/// Result of resolving a selection against [attributeVariantCombinations].
/// - [enabledValueIds]: all attribute value ids that are still valid (have stock)
///   for the current partial selection.
/// - [enabledValueSlugs]: normalized value names/slugs (e.g. "printed-cover", "40")
///   from the same combos; use with id for dual validation so multiple in-stock
///   attributes are not wrongly disabled when id matching fails.
/// - [matchedVariant]: the best matching variant (if any) for the current selection.
/// - [suggestedSelection]: when resolving by clicked value, attr slug -> value slug
///   from the best combo's available_combination_values to auto-select in UI.
class AttributeSelectionResult extends Equatable {
  final Set<int> enabledValueIds;
  /// Normalized value slugs (value part of "attr-value" from combo) for name-based availability check.
  final Set<String> enabledValueSlugs;
  final AttributeVariantCombination? matchedVariant;
  final Map<String, String>? suggestedSelection;

  const AttributeSelectionResult({
    required this.enabledValueIds,
    this.enabledValueSlugs = const {},
    required this.matchedVariant,
    this.suggestedSelection,
  });

  @override
  List<Object?> get props => [enabledValueIds, enabledValueSlugs, matchedVariant, suggestedSelection];
}

class ProductDetails extends Equatable {
  final String id;
  final String brand;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final int rating;
  final int reviewCount;
  final List<String> images;
  final List<ColorOption> colorOptions;
  final List<SizeOption> sizeOptions;
  final List<VariantAttributeOption> variantAttributeOptions; // New field for multiple variant attributes
  final String selectedColor;
  final String selectedSize;
  final bool isFavorite;
  final bool hasDiscount;
  final int? discountPercentage;
  final List<String> features;
  final String material;
  final List<String> materialsList; // Detailed materials breakdown
  final List<String> materialOptions; // Selectable material options
  final String? selectedMaterial; // Currently selected material option
  final String careInstructions;
  final String? websiteUrl; // Product page path like /shop/... or full URL
  final double? heelHeightCm; // If footwear has heels
  final String? heelType; // e.g., Stiletto, Block, Wedge
  final List<double> heelHeightOptions; // Selectable heel height options
  final double? selectedHeelHeightCm; // Currently selected heel height
  final bool isPlusMember;
  final int pointsEarned;
  // Related products
  final List<RelatedProduct> optionalProducts;
  final List<RelatedProduct> accessoryProducts;
  final List<RelatedProduct> alternativeProducts;
  final List<VariantCombination> variantCombinations;
  /// Normalized combinations built from `attribute_value_combinations` in the API.
  final List<AttributeVariantCombination> attributeVariantCombinations;
  /// Map of value-key -> combos. Top-level keys from API (e.g. "printed-cover", "black", "40").
  /// Use clicked value as key to get combos, then filter by in_stock.
  final Map<String, List<AttributeVariantCombination>> attributeValueCombinationsByKey;
  final String primaryVariantLabel; // e.g., Legs, Size, Material (non-color attribute shown as choices)
  // Overall stock flag for the currently selected variant (computed)
  final bool inStock;
  /// Quantity available for the currently selected variant (from BLoC); used for badge (low stock when 1–5).
  final int? selectedVariantQuantityAvailable;
  final List<ProductTag> tags; // Product tags/categories
  // Map of variant_id -> list of image URLs for that variant
  final Map<String, List<String>> variantImagesMap;

  const ProductDetails({
    required this.id,
    required this.brand,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.colorOptions,
    required this.sizeOptions,
    this.variantAttributeOptions = const [],
    required this.selectedColor,
    required this.selectedSize,
    required this.isFavorite,
    required this.hasDiscount,
    this.discountPercentage,
    required this.features,
    required this.material,
    this.materialsList = const [],
    this.materialOptions = const [],
    this.selectedMaterial,
    required this.careInstructions,
    this.websiteUrl,
    this.heelHeightCm,
    this.heelType,
    this.heelHeightOptions = const [],
    this.selectedHeelHeightCm,
    required this.isPlusMember,
    required this.pointsEarned,
    this.optionalProducts = const [],
    this.accessoryProducts = const [],
    this.alternativeProducts = const [],
    this.variantCombinations = const [],
    this.attributeVariantCombinations = const [],
    this.attributeValueCombinationsByKey = const {},
    this.primaryVariantLabel = 'Size',
    this.inStock = true,
    this.selectedVariantQuantityAvailable,
    this.tags = const [],
    this.variantImagesMap = const {},
  });

  @override
  List<Object?> get props => [
        id,
        brand,
        name,
        description,
        price,
        originalPrice,
        rating,
        reviewCount,
        images,
        colorOptions,
        sizeOptions,
        variantAttributeOptions,
        selectedColor,
        selectedSize,
        isFavorite,
        hasDiscount,
        discountPercentage,
        features,
        material,
        materialsList,
        materialOptions,
        selectedMaterial,
        careInstructions,
        websiteUrl,
        heelHeightCm,
        heelType,
        heelHeightOptions,
        selectedHeelHeightCm,
        isPlusMember,
        pointsEarned,
      optionalProducts,
      accessoryProducts,
      alternativeProducts,
      variantCombinations,
      attributeVariantCombinations,
      attributeValueCombinationsByKey,
      primaryVariantLabel,
      inStock,
      selectedVariantQuantityAvailable,
      tags,
      variantImagesMap,
      ];

  /// Get all variants that have a specific attribute value
  List<VariantCombination> getVariantsWithAttribute(String attributeName, String valueName) {
    return variantCombinations.where((variant) => 
      variant.hasAttributeValue(attributeName, valueName)
    ).toList();
  }

  /// Get all unique values for a specific attribute across all variants
  List<String> getUniqueAttributeValues(String attributeName) {
    final values = <String>{};
    for (final variant in variantCombinations) {
      final value = variant.getAttributeValue(attributeName);
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }
    return values.toList();
  }

  /// Get images for a specific variant_id
  List<String> getImagesForVariant(String variantId) {
    return variantImagesMap[variantId] ?? [];
  }

  /// Variant id used for images: first variant that matches selected color only.
  /// Images update only on color change; size/material/height do not change images.
  String? get variantIdForImagesByColor {
    if (selectedColor.isEmpty) return null;
    final norm = selectedColor.toLowerCase().trim();
    for (final v in variantCombinations) {
      final colorVal = v.getAttributeValue('COLOR NAME') ??
          v.getAttributeValue('COLOR') ??
          v.getAttributeValue('اللون');
      if (colorVal != null &&
          colorVal.toLowerCase().trim() == norm &&
          v.variantId.isNotEmpty) {
        return v.variantId;
      }
    }
    return null;
  }

  /// Get filtered images based on selected attributes
  List<String> getFilteredImages({String? color, String? size, String? material}) {
    List<VariantCombination> filteredVariants = variantCombinations;

    // Apply filters
    if (color != null) {
      filteredVariants = filteredVariants.where((variant) => 
        variant.hasAttributeValue('اللون', color) || 
        variant.hasAttributeValue('color', color)
      ).toList();
    }

    if (size != null) {
      filteredVariants = filteredVariants.where((variant) => 
        variant.hasAttributeValue(primaryVariantLabel, size) ||
        variant.hasAttributeValue('size', size)
      ).toList();
    }

    if (material != null) {
      filteredVariants = filteredVariants.where((variant) => 
        variant.hasAttributeValue('material', material)
      ).toList();
    }

    // Extract images from filtered variants
    final filteredImages = <String>[];
    for (final variant in filteredVariants) {
      final variantImagePath = '/web/image/product.product/${variant.variantId}/image_1920';
      final fullImageUrl = '${AppConstants.baseUrl}${variantImagePath.startsWith('/') ? variantImagePath.substring(1) : variantImagePath}';
      if (!filteredImages.contains(fullImageUrl)) {
        filteredImages.add(fullImageUrl);
      }
    }

    return filteredImages;
  }

  /// Create a copy of this ProductDetails with updated fields
  ProductDetails copyWith({
    String? id,
    String? brand,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    int? rating,
    int? reviewCount,
    List<String>? images,
    List<ColorOption>? colorOptions,
    List<SizeOption>? sizeOptions,
    String? selectedColor,
    String? selectedSize,
    bool? isFavorite,
    bool? hasDiscount,
    int? discountPercentage,
    List<String>? features,
    String? material,
    List<String>? materialsList,
    List<String>? materialOptions,
    String? selectedMaterial,
    String? careInstructions,
    String? websiteUrl,
    String? heelType,
    List<double>? heelHeightOptions,
    double? heelHeightCm,
    double? selectedHeelHeightCm,
    bool? isPlusMember,
    int? pointsEarned,
    List<RelatedProduct>? optionalProducts,
    List<RelatedProduct>? accessoryProducts,
    List<RelatedProduct>? alternativeProducts,
    List<VariantCombination>? variantCombinations,
    List<AttributeVariantCombination>? attributeVariantCombinations,
    Map<String, List<AttributeVariantCombination>>? attributeValueCombinationsByKey,
    String? primaryVariantLabel,
    List<VariantAttributeOption>? variantAttributeOptions,
    bool? inStock,
    int? selectedVariantQuantityAvailable,
    List<ProductTag>? tags,
    Map<String, List<String>>? variantImagesMap,
  }) {
    return ProductDetails(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      images: images ?? this.images,
      colorOptions: colorOptions ?? this.colorOptions,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedSize: selectedSize ?? this.selectedSize,
      isFavorite: isFavorite ?? this.isFavorite,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      features: features ?? this.features,
      material: material ?? this.material,
      materialsList: materialsList ?? this.materialsList,
      materialOptions: materialOptions ?? this.materialOptions,
      selectedMaterial: selectedMaterial ?? this.selectedMaterial,
      careInstructions: careInstructions ?? this.careInstructions,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      heelType: heelType ?? this.heelType,
      heelHeightOptions: heelHeightOptions ?? this.heelHeightOptions,
      heelHeightCm: heelHeightCm ?? this.heelHeightCm,
      selectedHeelHeightCm: selectedHeelHeightCm ?? this.selectedHeelHeightCm,
      isPlusMember: isPlusMember ?? this.isPlusMember,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      optionalProducts: optionalProducts ?? this.optionalProducts,
      accessoryProducts: accessoryProducts ?? this.accessoryProducts,
      alternativeProducts: alternativeProducts ?? this.alternativeProducts,
      variantCombinations: variantCombinations ?? this.variantCombinations,
      attributeVariantCombinations:
          attributeVariantCombinations ?? this.attributeVariantCombinations,
      attributeValueCombinationsByKey:
          attributeValueCombinationsByKey ?? this.attributeValueCombinationsByKey,
      primaryVariantLabel: primaryVariantLabel ?? this.primaryVariantLabel,
      variantAttributeOptions: variantAttributeOptions ?? this.variantAttributeOptions,
      inStock: inStock ?? this.inStock,
      selectedVariantQuantityAvailable: selectedVariantQuantityAvailable ?? this.selectedVariantQuantityAvailable,
      tags: tags ?? this.tags,
      variantImagesMap: variantImagesMap ?? this.variantImagesMap,
    );
  }

  /// Builds map of API attribute_name -> value_name from current selection (strings).
  /// Keys: COLOR, SIZE, MATERIALS, HEIGHT, WIDTH, MEASUREMENT, etc.
  /// Used to match variant by value_name (e.g. BLACK, 36, Synthetic Leather, 4.5).
  Map<String, String> getSelectedAttributesByValueName() {
    final map = <String, String>{};
    if (selectedColor.isNotEmpty) map['COLOR'] = selectedColor.trim();
    if (selectedSize.isNotEmpty) map['SIZE'] = selectedSize.trim();
    if (selectedMaterial != null && selectedMaterial!.isNotEmpty) {
      map['MATERIALS'] = selectedMaterial!.trim();
    }
    if (selectedHeelHeightCm != null) {
      map['HEIGHT'] = selectedHeelHeightCm!.toStringAsFixed(1);
    }
    // Fill from variantAttributeOptions for any attribute not yet set
    for (final opt in variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      final attrLower = opt.attributeName.toLowerCase();
      final value = opt.selectedValue.trim();
      if (attrLower.contains('color') || attrLower == 'colour' || attrLower == 'اللون') {
        if (!map.containsKey('COLOR')) map['COLOR'] = value;
      } else if (attrLower == 'size' || (primaryVariantLabel.isNotEmpty && attrLower == primaryVariantLabel.toLowerCase())) {
        if (!map.containsKey('SIZE')) map['SIZE'] = value;
      } else if (attrLower.contains('material')) {
        if (!map.containsKey('MATERIALS')) map['MATERIALS'] = value;
      } else if (attrLower == 'height' || attrLower.contains('heel')) {
        if (!map.containsKey('HEIGHT')) map['HEIGHT'] = value;
      } else {
        // Include all other attributes (WIDTH, MEASUREMENT, BRAND, etc.) for exact variant matching
        final key = opt.apiAttributeName?.isNotEmpty == true
            ? opt.apiAttributeName!
            : opt.attributeName;
        map[key] = value;
      }
    }
    return map;
  }

  /// Builds map of attribute_slug -> value_slug from current selection.
  /// Uses value names as-is from variantAttributeOptions (no conversion e.g. 4 to 4.0)
  /// to match available_combination_values exactly.
  /// API slugs: color-black, size-40, materials-printed-cover, etc.
  Map<String, String> getSelectedAttributesForRawValueMatching() {
    final map = <String, String>{};
    for (final opt in variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      final attrLower = opt.attributeName.toLowerCase();
      final value = opt.selectedValue.trim();
      String attr = attrLower.replaceAll(' ', '-');
      if (attr.contains('material')) attr = 'materials';
      if (attr.contains('color') || attr.contains('colour')) attr = 'color';
      final val = value.toLowerCase().replaceAll(' ', '-');
      if (attr.isEmpty || val.isEmpty) continue;
      map[attr] = val;
    }
    if (!map.containsKey('color') && selectedColor.isNotEmpty) {
      map['color'] = selectedColor.trim().toLowerCase().replaceAll(' ', '-');
    }
    return map;
  }

  /// Parses combo slug "size-40" -> ("size","40"), "materials-printed-cover" -> ("materials","printed-cover")
  static (String, String) _parseComboSlug(String slug) {
    final idx = slug.indexOf('-');
    if (idx <= 0) return ('', slug);
    return (slug.substring(0, idx), slug.substring(idx + 1));
  }

  /// Returns true if combo matches our selection by raw attribute value names.
  /// Each available_combination_values slug (e.g. "size-40") is parsed to (attr, valuePart);
  /// for every selected (attr, value), combo must have a slug with same attr and valuePart == value.
  bool _comboMatchesByRawValues(
    List<AttributeCombinationValue> comboValues,
    Map<String, String> selected,
  ) {
    for (final e in selected.entries) {
      final hasMatch = comboValues.any((cv) {
        final (attr, valuePart) = _parseComboSlug(cv.value);
        return attr == e.key && valuePart == e.value;
      });
      if (!hasMatch) return false;
    }
    return true;
  }

  /// Returns true if combo matches selection by value IDs only (language-agnostic).
  /// For every (attrSlug, valueId) in [selectionByAttrSlugToValueId], combo must have
  /// a value with that attr and id. Normalize API attr (e.g. "اللون") to slug ("color") so match works.
  static bool comboMatchesByValueIds(
    List<AttributeCombinationValue> comboValues,
    Map<String, int> selectionByAttrSlugToValueId,
  ) {
    if (selectionByAttrSlugToValueId.isEmpty) return false;
    for (final e in selectionByAttrSlugToValueId.entries) {
      final hasMatch = comboValues.any((cv) {
        final (attr, _) = _parseComboSlug(cv.value);
        final comboAttrSlug = _attributeNameToComboSlug(attr);
        return comboAttrSlug == e.key && cv.id == e.value;
      });
      if (!hasMatch) return false;
    }
    return true;
  }

  /// Public helper for building attribute slug from display name (e.g. for initial load in model).
  static String attributeNameToComboSlug(String attrName) =>
      _attributeNameToComboSlug(attrName);

  /// Builds current selection as attribute slug -> value id from [variantAttributeOptions].
  /// Used for ID-only matching so English and Arabic produce the same result.
  Map<String, int> getSelectedAttributeSlugToValueId() {
    final map = <String, int>{};
    for (final opt in variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      VariantAttributeValue? selectedVal;
      for (final v in opt.values) {
        if (v.isSelected) {
          selectedVal = v;
          break;
        }
        if (_toValueKey(v.name) == _toValueKey(opt.selectedValue) ||
            (v.displayName != null &&
                v.displayName!.isNotEmpty &&
                _toValueKey(v.displayName!) == _toValueKey(opt.selectedValue))) {
          selectedVal = v;
          break;
        }
      }
      if (selectedVal == null) continue;
      final idInt = int.tryParse(selectedVal.id.toString());
      if (idInt == null) continue;
      final attrSlug = _attributeNameToComboSlug(opt.attributeName);
      map[attrSlug] = idInt;
    }
    return map;
  }

  /// Returns true if [combo]'s value ids exactly match [selectionBySlug] (current selection).
  /// Use after loop returns a combo: validate that the combo is for the full selection, not just the clicked id.
  static bool comboMatchesFullSelection(
    AttributeVariantCombination combo,
    Map<String, int> selectionBySlug,
  ) {
    if (selectionBySlug.isEmpty) return false;
    final selectedIds = selectionBySlug.values.toSet();
    final comboIds = combo.values.map((v) => v.id).toSet();
    return selectedIds.length == comboIds.length && selectedIds.containsAll(comboIds);
  }

  /// Finds the best in-stock combo by looking up only the clicked attribute value id.
  /// API keys attribute_value_combinations by value id (e.g. "325" for size 38).
  /// Pass only this id; the loop fetches combos for that key and returns the best match.
  AttributeVariantCombination? findMatchingComboByClickedValueId(String clickedValueId) {
    if (clickedValueId.trim().isEmpty) return null;
    final key = clickedValueId.toString().trim();
    var combos = attributeValueCombinationsByKey[key];
    if (combos == null || combos.isEmpty) {
      final keyNum = int.tryParse(key);
      if (keyNum != null) combos = attributeValueCombinationsByKey[keyNum.toString()];
    }
    combos ??= [];
    final inStock = combos
        .where((c) => c.inStock && c.quantityAvailable > 0)
        .toList();
    if (inStock.isEmpty) return null;
    return inStock.reduce((a, b) =>
        a.quantityAvailable >= b.quantityAvailable ? a : b);
  }

  /// Finds the best in-stock combo that matches [selectionByAttrSlugToValueId] by value IDs.
  /// Used for initial load so stock/quantity come from the same loop as attribute clicks.
  static AttributeVariantCombination? findMatchingComboByValueIds(
    List<AttributeVariantCombination> combos,
    Map<String, int> selectionByAttrSlugToValueId,
  ) {
    if (combos.isEmpty || selectionByAttrSlugToValueId.isEmpty) return null;
    final inStock = combos
        .where((c) => c.inStock && c.quantityAvailable > 0)
        .toList();
    if (inStock.isEmpty) return null;
    final matching = inStock
        .where((c) => comboMatchesByValueIds(c.values, selectionByAttrSlugToValueId))
        .toList();
    if (matching.isEmpty) return null;
    return matching.reduce((a, b) =>
        a.quantityAvailable >= b.quantityAvailable ? a : b);
  }

  /// Normalize attribute value to API key (e.g. "PRINTED COVER" -> "printed-cover", "4" -> "4").
  static String _toValueKey(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '-');

  /// Map UI attribute name to combo slug (e.g. "SIZE" -> "size", "اللون" -> "color").
  static String _attributeNameToComboSlug(String attrName) {
    final a = attrName.toLowerCase().trim().replaceAll(' ', '-');
    if (a == 'size' || a.contains('size') || a == 'القياس') return 'size';
    if (a.contains('color') || a == 'colour' || a == 'اللون') return 'color';
    if (a.contains('material')) return 'materials';
    if (a.contains('height') || a.contains('heel')) return 'height';
    if (a == 'width') return 'width';
    if (a.contains('measurement')) return 'measurement';
    return a;
  }

  /// Returns enabled value ids and slugs for [attributeName] from combos that match
  /// [selectedByAttribute] for all *other* attributes. So when user selects size 40,
  /// we get all sizes (40, 38, 36, ...) that exist in combos with current color/material/height,
  /// so 38 stays available instead of being disabled.
  /// [selectedByAttributeById]: when names are localized (e.g. Arabic), pass attr slug -> value id
  /// so combos are matched by id and Arabic works the same as English.
  ({Set<int> ids, Set<String> slugs}) getEnabledIdsAndSlugsForAttribute(
    String attributeName,
    Map<String, String> selectedByAttribute,
    String primaryVariantLabel, {
    Map<String, int>? selectedByAttributeById,
  }) {
    debugPrint(
      '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName", '
      'selectedByAttribute=$selectedByAttribute, '
      'selectedByAttributeById=$selectedByAttributeById',
    );
    if (attributeVariantCombinations.isEmpty) {
      debugPrint(
        '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName" → NO attributeVariantCombinations',
      );
      return (ids: {}, slugs: {});
    }
    final inStock = attributeVariantCombinations
        .where((c) => c.quantityAvailable > 0)
        .toList();
    if (inStock.isEmpty) {
      debugPrint(
        '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName" → no in‑stock combos',
      );
      return (ids: {}, slugs: {});
    }

    final targetAttrSlug = _attributeNameToComboSlug(attributeName);
    // Build selection: prefer id-only (selectedByAttributeById with slug keys) so loop uses only value ids.
    final Map<String, String> otherSelection = {};
    final Map<String, int> otherSelectionById = {};
    if (selectedByAttributeById != null && selectedByAttributeById.isNotEmpty) {
      for (final e in selectedByAttributeById.entries) {
        if (e.key == targetAttrSlug) continue;
        final normKey = e.key == 'size' && primaryVariantLabel.isNotEmpty
            ? _attributeNameToComboSlug(primaryVariantLabel)
            : e.key;
        if (normKey == targetAttrSlug) continue;
        otherSelectionById[e.key] = e.value;
      }
    }
    if (otherSelectionById.isEmpty) {
      for (final e in selectedByAttribute.entries) {
        if (e.value.isEmpty) continue;
        final keySlug = _attributeNameToComboSlug(e.key);
        if (keySlug == targetAttrSlug) continue;
        final normKey = keySlug == 'size' && primaryVariantLabel.isNotEmpty
            ? _attributeNameToComboSlug(primaryVariantLabel)
            : keySlug;
        if (normKey == targetAttrSlug) continue;
        otherSelection[keySlug] = _toValueKey(e.value);
        if (selectedByAttributeById != null) {
          int? id = selectedByAttributeById[keySlug] ?? selectedByAttributeById[e.key];
          if (id == null) {
            for (final entry in selectedByAttributeById.entries) {
              if (_attributeNameToComboSlug(entry.key) == keySlug) {
                id = entry.value;
                break;
              }
            }
          }
          if (id != null) otherSelectionById[keySlug] = id;
        }
      }
    }

    // Match by id OR by name: same behaviour for English (name matches); Arabic uses id when name doesn't.
    bool comboMatchesOtherSelection(List<AttributeCombinationValue> comboValues) {
      final allKeys = <String>{...otherSelectionById.keys, ...otherSelection.keys};
      for (final key in allKeys) {
        final matchById = otherSelectionById.containsKey(key) &&
            comboValues.any((cv) {
              final (attr, valuePart) = _parseComboSlug(cv.value);
              return attr == key && cv.id == otherSelectionById[key];
            });
        final matchByName = otherSelection.containsKey(key) &&
            comboValues.any((cv) {
              final (attr, valuePart) = _parseComboSlug(cv.value);
              return attr == key && _toValueKey(valuePart) == otherSelection[key];
            });
        // Accept if either matches so both languages work (English: name; Arabic: id when name differs).
        if (!matchById && !matchByName) return false;
      }
      return true;
    }

    final matchingCombos = (otherSelection.isEmpty && otherSelectionById.isEmpty)
        ? inStock
        : inStock.where((combo) => comboMatchesOtherSelection(combo.values)).toList();
    debugPrint(
      '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName" → '
      'matchingCombos=${matchingCombos.length} (of ${inStock.length} in‑stock)',
    );
    if (matchingCombos.isEmpty) {
      debugPrint(
        '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName" → no matching combos after filter',
      );
      return (ids: {}, slugs: {});
    }

    final Set<int> ids = {};
    final Set<String> slugs = {};
    for (final combo in matchingCombos) {
      for (final v in combo.values) {
        final (attr, valuePart) = _parseComboSlug(v.value);
        if (attr != targetAttrSlug) continue;
        ids.add(v.id);
        if (valuePart.isNotEmpty) slugs.add(_toValueKey(valuePart));
      }
    }
    debugPrint(
      '🧮 [getEnabledIdsAndSlugsForAttribute] attr="$attributeName" → '
      'enabledIds=${ids.toList()}, enabledSlugs=${slugs.toList()}',
    );
    return (ids: ids, slugs: slugs);
  }

  /// Resolve selection using ONLY the clicked attribute value name.
  /// [alternativeLookupKeys]: when the primary key (e.g. Arabic name) is not in the API,
  /// try these keys (e.g. English name, value id) so Arabic and other locales work.
  /// Flow:
  /// 1. Lookup attribute_value_combinations[clickedValueName] by key.
  /// 2. Filter combos where quantity_available > 0 (stock != 0).
  /// 3. Collect enabledValueIds from available_combination_values of filtered combos.
  /// 4. Pick best combo (highest quantity) for stock badge and suggested selection.
  /// 5. Build suggestedSelection (attr->value) from combo's available_combination_values.
  AttributeSelectionResult resolveSelectionByClickedValue(
    String clickedAttributeValueName, {
    List<String>? alternativeLookupKeys,
  }) {
    if (attributeValueCombinationsByKey.isEmpty) {
      debugPrint(
        '📦 [resolveByClickedValue] attributeValueCombinationsByKey is empty',
      );
      return const AttributeSelectionResult(
        enabledValueIds: {},
        enabledValueSlugs: {},
        matchedVariant: null,
      );
    }

    final valueKey = _toValueKey(clickedAttributeValueName);
    var candidateCombos = attributeValueCombinationsByKey[valueKey];
    // Fallback for numeric values: try "4" and "4.0"
    if (candidateCombos == null && valueKey.contains('.')) {
      candidateCombos = attributeValueCombinationsByKey[valueKey.split('.').first];
    }
    if (candidateCombos == null && !valueKey.contains('.')) {
      candidateCombos = attributeValueCombinationsByKey['$valueKey.0'];
    }
    // Fallback only when primary key finds nothing (e.g. Arabic name vs API English keys).
    // Does not affect flow when primary key works (e.g. English).
    if ((candidateCombos == null || candidateCombos.isEmpty) &&
        alternativeLookupKeys != null &&
        alternativeLookupKeys.isNotEmpty) {
      for (final alt in alternativeLookupKeys) {
        if (alt.isEmpty) continue;
        final altKey = _toValueKey(alt);
        candidateCombos = attributeValueCombinationsByKey[altKey];
        if (candidateCombos == null && altKey.contains('.')) {
          candidateCombos = attributeValueCombinationsByKey[altKey.split('.').first];
        }
        if (candidateCombos == null && !altKey.contains('.')) {
          candidateCombos = attributeValueCombinationsByKey['$altKey.0'];
        }
        if (candidateCombos != null && candidateCombos.isNotEmpty) {
          debugPrint(
            '📦 [resolveByClickedValue] Used alternative key "$altKey" (from "$alt") for lookup',
          );
          break;
        }
      }
    }
    candidateCombos ??= [];

    debugPrint(
      '📦 [resolveByClickedValue] Lookup key="$valueKey" (from "$clickedAttributeValueName") '
      '→ combosCount=${candidateCombos.length}, availableKeys=${attributeValueCombinationsByKey.keys.toList()}',
    );

    // Filter: only combos with stock > 0
    candidateCombos = candidateCombos
        .where((c) => c.quantityAvailable > 0)
        .toList();

    if (candidateCombos.isEmpty) {
      debugPrint(
        '📦 [resolveByClickedValue] No combos with quantity_available > 0 for key="$valueKey"',
      );
      return const AttributeSelectionResult(
        enabledValueIds: {},
        enabledValueSlugs: {},
        matchedVariant: null,
      );
    }

    // Best combo = highest quantity (for stock badge and suggested selection)
    final bestCombo = candidateCombos.reduce((a, b) =>
        a.quantityAvailable >= b.quantityAvailable ? a : b);

    // Enabled ids and value slugs = union from available_combination_values (for dual validation)
    final Set<int> enabledIds = {};
    final Set<String> enabledSlugs = {};
    for (final combo in candidateCombos) {
      for (final v in combo.values) {
        enabledIds.add(v.id);
        final (_, valuePart) = _parseComboSlug(v.value);
        if (valuePart.isNotEmpty) {
          enabledSlugs.add(_toValueKey(valuePart));
        }
      }
    }

    // Suggested selection from best combo's available_combination_values
    final Map<String, String> suggestedSelection = {};
    for (final cv in bestCombo.values) {
      final (attr, valuePart) = _parseComboSlug(cv.value);
      if (attr.isNotEmpty && valuePart.isNotEmpty) {
        suggestedSelection[attr] = valuePart;
      }
    }

    debugPrint(
      '📦 [resolveByClickedValue] matched: variantId=${bestCombo.variantId}, '
      'quantityAvailable=${bestCombo.quantityAvailable}, inStock=${bestCombo.inStock}, '
      'enabledIds=$enabledIds, suggestedSelection=$suggestedSelection',
    );

    return AttributeSelectionResult(
      enabledValueIds: enabledIds,
      enabledValueSlugs: enabledSlugs,
      matchedVariant: bestCombo,
      suggestedSelection: suggestedSelection,
    );
  }

  /// Resolve the current selection against [attributeVariantCombinations].
  /// Prefers ID-based matching (same result for English and Arabic); falls back to
  /// raw value matching when selection-by-ID is empty.
  AttributeSelectionResult resolveSelectionFromAttributeCombinations(
    Set<int> selectedValueIds,
  ) {
    if (attributeVariantCombinations.isEmpty) {
      debugPrint(
        '📦 [resolveSelectionFromAttrCombos] NO attributeVariantCombinations; selectedValueIds=$selectedValueIds',
      );
      return const AttributeSelectionResult(
        enabledValueIds: {},
        enabledValueSlugs: {},
        matchedVariant: null,
      );
    }

    final candidateCombos = attributeVariantCombinations
        .where((c) => c.inStock && c.quantityAvailable > 0)
        .toList();

    debugPrint(
      '📦 [resolveSelectionFromAttrCombos] selectedValueIds=$selectedValueIds, '
      'candidateCombos=${candidateCombos.length}',
    );

    if (candidateCombos.isEmpty) {
      debugPrint(
        '📦 [resolveSelectionFromAttrCombos] NO in‑stock candidateCombos',
      );
      return const AttributeSelectionResult(
        enabledValueIds: {},
        enabledValueSlugs: {},
        matchedVariant: null,
      );
    }

    // Prefer ID-based matching so English and Arabic get the same result.
    final selectionById = getSelectedAttributeSlugToValueId();
    debugPrint(
      '📦 [resolveSelectionFromAttrCombos] selectionById (attr slug -> value id)=$selectionById',
    );

    List<AttributeVariantCombination> fullMatchCombos = selectionById.isNotEmpty
        ? candidateCombos
            .where((c) => comboMatchesByValueIds(c.values, selectionById))
            .toList()
        : <AttributeVariantCombination>[];

    // Fallback to name/slug matching when no ID-based selection or no ID match.
    Map<String, String> selectedRawValues = {};
    if (fullMatchCombos.isEmpty) {
      selectedRawValues = getSelectedAttributesForRawValueMatching();
      debugPrint(
        '📦 [resolveSelection] fallback selectedRawValues=$selectedRawValues, '
        'candidateCombosCount=${candidateCombos.length}',
      );
      fullMatchCombos = selectedRawValues.isNotEmpty
          ? candidateCombos
              .where((combo) =>
                  _comboMatchesByRawValues(combo.values, selectedRawValues))
              .toList()
          : <AttributeVariantCombination>[];
    }

    List<AttributeVariantCombination> compatible = fullMatchCombos.isNotEmpty
        ? fullMatchCombos
        : (selectedRawValues.isNotEmpty
            ? candidateCombos.where((combo) {
                return selectedRawValues.entries.any((e) {
                  return combo.values.any((cv) {
                    final (attr, valuePart) = _parseComboSlug(cv.value);
                    return attr == e.key && valuePart == e.value;
                  });
                });
              }).toList()
            : <AttributeVariantCombination>[]);

    if (compatible.isEmpty) {
      debugPrint(
        '📦 [resolveSelectionFromAttrCombos] NO compatible combos selectionById=$selectionById selectedRawValues=$selectedRawValues',
      );
      return const AttributeSelectionResult(
        enabledValueIds: {},
        enabledValueSlugs: {},
        matchedVariant: null,
      );
    }

    final Set<int> enabledIds = {};
    final Set<String> enabledSlugs = {};
    for (final combo in compatible) {
      for (final v in combo.values) {
        enabledIds.add(v.id);
        final (_, valuePart) = _parseComboSlug(v.value);
        if (valuePart.isNotEmpty) {
          enabledSlugs.add(_toValueKey(valuePart));
        }
      }
    }

    final AttributeVariantCombination? matched = fullMatchCombos.isEmpty
        ? null
        : fullMatchCombos.reduce((a, b) =>
            a.quantityAvailable >= b.quantityAvailable ? a : b);

    if (matched != null) {
      debugPrint(
        '📦 [resolveSelectionFromAttrCombos] matched variantId=${matched.variantId}, '
        'qty=${matched.quantityAvailable}, inStock=${matched.inStock}',
      );
    } else {
      debugPrint(
        '📦 [resolveSelectionFromAttrCombos] no full‑match combo; enabledIds=${enabledIds.toList()}',
      );
    }

    return AttributeSelectionResult(
      enabledValueIds: enabledIds,
      enabledValueSlugs: enabledSlugs,
      matchedVariant: matched,
    );
  }

  /// Builds map of attribute_id (from variant_attributes) -> value_name from current selection.
  /// Used to filter variants by attribute_id + value_name (variant_combinations.attributes).
  Map<String, String> getSelectedAttributesByAttributeIdAndValueName() {
    final map = <String, String>{};
    for (final opt in variantAttributeOptions) {
      if (opt.attributeId == null || opt.attributeId!.trim().isEmpty) continue;
      if (opt.selectedValue.isEmpty) continue;
      map[opt.attributeId!.trim()] = opt.selectedValue.trim();
    }
    return map;
  }

  /// Finds the single variant combination that matches current selection.
  /// Prefer matching by attribute_id + value_name (from variant_attributes and variant_combinations);
  /// fallback to attribute_name + value_name.
  VariantCombination? findVariantMatchingSelectionByValueName() {
    // 1) Prefer filter by attribute_id + value_name when we have attribute ids
    final byAttrId = getSelectedAttributesByAttributeIdAndValueName();
    if (byAttrId.isNotEmpty) {
      final matching = variantCombinations
          .where((c) => c.matchesAttributesByAttributeIdAndValueName(byAttrId))
          .toList();
      if (matching.isNotEmpty) {
        if (matching.length == 1) return matching.first;
        matching.sort((a, b) => (b.quantityAvailable ?? 0).compareTo(a.quantityAvailable ?? 0));
        return matching.first;
      }
    }
    // 2) Fallback: match by attribute_name + value_name
    final selected = getSelectedAttributesByValueName();
    if (selected.isEmpty) return null;
    final matching = variantCombinations
        .where((c) => c.matchesAttributesByValueName(selected))
        .toList();
    if (matching.isEmpty) return null;
    if (matching.length == 1) return matching.first;
    matching.sort((a, b) => (b.quantityAvailable ?? 0).compareTo(a.quantityAvailable ?? 0));
    return matching.first;
  }

  /// Filters variants based on all selected attributes from variantAttributeOptions.
  /// Returns all variant combinations that match the currently selected attribute values.
  /// This function uses attribute_id + value_name matching when available, falling back to attribute_name + value_name.
  /// 
  /// Example usage:
  /// ```dart
  /// final filteredVariants = productDetails.filterVariantsBySelectedAttributes();
  /// // Returns all variants that match SIZE=36, COLOR=BLACK, MATERIALS=Synthetic Leather, etc.
  /// ```
  List<VariantCombination> filterVariantsBySelectedAttributes() {
    // Get all selected attributes from variantAttributeOptions
    final Map<String, String> selectedAttributes = {};
    
    for (final opt in variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      
      // Prefer using attribute_id if available (more reliable matching)
      if (opt.attributeId != null && opt.attributeId!.trim().isNotEmpty) {
        selectedAttributes[opt.attributeId!.trim()] = opt.selectedValue.trim();
      } else {
        // Fallback to attribute name
        final attrKey = opt.apiAttributeName?.isNotEmpty == true 
            ? opt.apiAttributeName! 
            : opt.attributeName;
        selectedAttributes[attrKey] = opt.selectedValue.trim();
      }
    }
    
    if (selectedAttributes.isEmpty) {
      return List.from(variantCombinations);
    }
    
    // Filter variants that match all selected attributes
    final filtered = variantCombinations.where((variant) {
      // Try matching by attribute_id first (more reliable)
      final byAttrId = getSelectedAttributesByAttributeIdAndValueName();
      if (byAttrId.isNotEmpty) {
        return variant.matchesAttributesByAttributeIdAndValueName(byAttrId);
      }
      
      // Fallback to attribute_name matching
      return variant.matchesAttributesByValueName(selectedAttributes);
    }).toList();
    
    return filtered;
  }

  /// Returns true when there exists at least one variant in [variantCombinations]
  /// that matches **both** the given [colorName] and the attribute/value pair
  /// ([attributeName] = [valueName]) and is actually available in stock
  /// (`inStock == true` and `quantityAvailable > 0`).
  ///
  /// This is used by the UI attribute section to decide whether a specific
  /// attribute button (size, material, height, etc.) should be enabled for the
  /// currently selected color.
  bool hasInStockVariantForColorAndAttributeValue({
    required String colorName,
    required String attributeName,
    required String valueName,
  }) {
    if (colorName.isEmpty || valueName.isEmpty) return false;

    String norm(String s) => s.toLowerCase().trim();
    final equivalentNames = _equivalentNormalizedColorNames(colorName);
    final normalizedValue = norm(valueName);

    // Common attribute names used by the backend for color.
    const colorAttrNames = [
      'COLOR NAME',
      'color name',
      'Color Name',
      'color',
      'Color',
      'COLOR',
      'colour',
      'Colour',
      'اللون',
      'لون',
    ];

    for (final combo in variantCombinations) {
      // 1) Match color (Arabic selectedColor matches variant English via colorOptions).
      String? variantColor;
      for (final attrName in colorAttrNames) {
        final v = combo.getAttributeValue(attrName);
        if (v != null && v.isNotEmpty) {
          variantColor = v;
          break;
        }
      }
      if (variantColor == null || variantColor.isEmpty) continue;

      if (!_variantColorMatches(variantColor, equivalentNames)) continue;

      // 2) Match the target attribute/value pair.
      final String? variantAttrValue =
          combo.getAttributeValue(attributeName);
      if (variantAttrValue == null || variantAttrValue.isEmpty) continue;

      if (norm(variantAttrValue) != normalizedValue) continue;

      // 3) Stock rule: only consider variants that are actually available.
      final double qty = combo.quantityAvailable ?? 0;
      final bool inStockAndPositiveQty = combo.inStock && qty > 0;
      if (!inStockAndPositiveQty) continue;

      // Found at least one matching, in‑stock variant.
      return true;
    }

    return false;
  }

  /// All normalized names that count as the same color (e.g. Arabic display + English name).
  /// So when selectedColor is Arabic, we still match variants that have English color.
  Set<String> _equivalentNormalizedColorNames(String colorName) {
    String norm(String s) => s.toLowerCase().trim();
    final out = <String>{norm(colorName)};
    for (final c in colorOptions) {
      if (norm(c.name) == norm(colorName) || norm(c.displayName ?? '') == norm(colorName)) {
        out.add(norm(c.name));
        if (c.displayName != null && c.displayName!.isNotEmpty) {
          out.add(norm(c.displayName!));
        }
      }
    }
    return out;
  }

  bool _variantColorMatches(String? variantColor, Set<String> equivalentNames) {
    if (variantColor == null || variantColor.isEmpty) return false;
    final n = variantColor.toLowerCase().trim();
    if (equivalentNames.contains(n)) return true;
    for (final eq in equivalentNames) {
      if (n.contains(eq) || eq.contains(n)) return true;
    }
    return false;
  }

  /// Whether [variantColorValue] is considered the same as current [selectedColor].
  /// Use when matching variants by color in UI (e.g. add-to-cart); works for both
  /// English and Arabic (equivalent names from [colorOptions]).
  bool colorValueMatchesSelection(String variantColorValue) {
    if (selectedColor.isEmpty) return false;
    return _variantColorMatches(
      variantColorValue,
      _equivalentNormalizedColorNames(selectedColor),
    );
  }

  /// Whether [variantColorValue] is considered the same as [colorName] (e.g. a color option's
  /// name or displayName). Use for matching variant to a color option; works for both languages.
  bool colorValueMatchesColorName(String variantColorValue, String colorName) {
    if (colorName.isEmpty) return false;
    return _variantColorMatches(
      variantColorValue,
      _equivalentNormalizedColorNames(colorName),
    );
  }

  /// Returns true when there exists at least one variant in [variantCombinations]
  /// that matches the given [colorName] and is actually available in stock
  /// (`inStock == true` and `quantityAvailable > 0`).
  ///
  /// This is used to check if a color has ANY in-stock variants at all.
  /// If a color has no in-stock variants, all attribute buttons should be disabled.
  bool hasAnyInStockVariantForColor(String colorName) {
    if (colorName.isEmpty) return false;

    String norm(String s) => s.toLowerCase().trim();
    final equivalentNames = _equivalentNormalizedColorNames(colorName);

    // Common attribute names used by the backend for color.
    const colorAttrNames = [
      'COLOR NAME',
      'color name',
      'Color Name',
      'color',
      'Color',
      'COLOR',
      'colour',
      'Colour',
      'اللون',
      'لون',
    ];

    for (final combo in variantCombinations) {
      // Match color (Arabic selectedColor matches variant English color via colorOptions).
      String? variantColor;
      for (final attrName in colorAttrNames) {
        final v = combo.getAttributeValue(attrName);
        if (v != null && v.isNotEmpty) {
          variantColor = v;
          break;
        }
      }
      if (variantColor == null || variantColor.isEmpty) continue;

      if (!_variantColorMatches(variantColor, equivalentNames)) continue;

      // Stock rule: only consider variants that are actually available.
      final double qty = combo.quantityAvailable ?? 0;
      final bool inStockAndPositiveQty = combo.inStock && qty > 0;
      if (!inStockAndPositiveQty) continue;

      // Found at least one in-stock variant for this color.
      return true;
    }

    return false;
  }

  /// Filters variants by the given [colorName] that have `inStock == true` and
  /// `quantityAvailable > 0`, then collects ALL attribute values from those variants.
  ///
  /// Returns a map where:
  /// - Key: attribute name (e.g., "SIZE", "MATERIAL NAME", "HEIGHT")
  /// - Value: Set of value names that are available for this color with stock
  ///
  /// This is used to determine which attribute buttons should be enabled
  /// and which values should be auto-selected for the selected color.
  Map<String, Set<String>> getEnabledAttributeValuesForColor(String colorName) {
    final Map<String, Set<String>> enabledAttributes = {};
    
    if (colorName.isEmpty || variantCombinations.isEmpty) {
      debugPrint('🔍 getEnabledAttributeValuesForColor: colorName is empty or no variants');
      return enabledAttributes;
    }

    String norm(String s) => s.toLowerCase().trim();
    final equivalentNames = _equivalentNormalizedColorNames(colorName);

    debugPrint('🔍 getEnabledAttributeValuesForColor: Starting filter for color="$colorName"');
    debugPrint('   Total variants to check: ${variantCombinations.length}');

    // Common attribute names used by the backend for color.
    const colorAttrNames = [
      'COLOR NAME',
      'color name',
      'Color Name',
      'color',
      'Color',
      'COLOR',
      'colour',
      'Colour',
      'اللون',
      'لون',
    ];

    // Step 1: Filter variants that match color AND have stock
    final List<VariantCombination> matchingVariants = [];
    
    for (int i = 0; i < variantCombinations.length; i++) {
      final combo = variantCombinations[i];
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 Checking Variant #${i + 1}/${variantCombinations.length}');
      debugPrint('   Variant ID: ${combo.variantId}');
      
      // Match color (Arabic selectedColor matches variant English via colorOptions).
      String? variantColor;
      for (final attrName in colorAttrNames) {
        final v = combo.getAttributeValue(attrName);
        if (v != null && v.isNotEmpty) {
          variantColor = v;
          break;
        }
      }
      
      if (variantColor == null || variantColor.isEmpty) {
        debugPrint('   ❌ No color attribute found - SKIPPING');
        continue;
      }

      debugPrint('   Color found: "$variantColor"');
      
      if (!_variantColorMatches(variantColor, equivalentNames)) {
        debugPrint('   ❌ Color mismatch: "$variantColor" != "$colorName" (equivalents: $equivalentNames) - SKIPPING');
        continue;
      }

      debugPrint('   ✅ Color matches!');

      // Check stock conditions: inStock == true AND quantityAvailable > 0
      final double qty = combo.quantityAvailable ?? 0;
      final bool inStockAndPositiveQty = combo.inStock && qty > 0;
      
      debugPrint('   Stock check: inStock=${combo.inStock}, quantityAvailable=${combo.quantityAvailable}, qty=$qty');
      
      if (!inStockAndPositiveQty) {
        debugPrint('   ❌ Stock condition failed (inStock=$inStockAndPositiveQty) - SKIPPING');
        continue;
      }

      debugPrint('   ✅ Stock condition passed!');
      
      // Print all attributes for this variant
      debugPrint('   📋 Variant Attributes:');
      for (final attr in combo.attributes) {
        debugPrint('      - ${attr.attributeName}: "${attr.valueName}"');
      }

      // This variant matches color and has stock - add it
      matchingVariants.add(combo);
      debugPrint('   ✅ Variant ADDED to matching list');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 Filter Results: Found ${matchingVariants.length} matching variants with stock');

    // Step 2: Collect all attribute values from matching variants
    // Skip color attributes since we're filtering by color
    debugPrint('🔍 Step 2: Collecting attribute values from ${matchingVariants.length} matching variants...');
    
    for (int i = 0; i < matchingVariants.length; i++) {
      final combo = matchingVariants[i];
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📦 Processing Matching Variant #${i + 1}/${matchingVariants.length}');
      debugPrint('   Variant ID: ${combo.variantId}');
      debugPrint('   Attributes:');
      
      for (final attr in combo.attributes) {
        final attrName = attr.attributeName;
        final attrValue = attr.valueName;
        
        // Skip color attributes
        final attrNameLower = attrName.toLowerCase();
        if (attrNameLower == 'color name' ||
            attrNameLower == 'color' ||
            attrNameLower == 'colour' ||
            attrNameLower == 'اللون' ||
            attrNameLower == 'لون') {
          debugPrint('      ⏭️  ${attrName}: "${attrValue}" (SKIPPED - color attribute)');
          continue;
        }

        // Skip empty values
        if (attrValue.isEmpty) {
          debugPrint('      ⏭️  ${attrName}: "" (SKIPPED - empty value)');
          continue;
        }

        debugPrint('      ✅ ${attrName}: "${attrValue}" (ADDED to enabled set)');

        // Add to enabled set for this attribute
        enabledAttributes.putIfAbsent(attrName, () => <String>{});
        enabledAttributes[attrName]!.add(attrValue);
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 Final Enabled Attributes Map:');
    for (final entry in enabledAttributes.entries) {
      debugPrint('   ${entry.key}: ${entry.value.toList()}');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return enabledAttributes;
  }

  /// Returns the first matching variant for the given [colorName] that has
  /// `inStock == true` and `quantityAvailable > 0`, along with its stock info.
  /// This is used to update the stock badge based on the matched variant.
  VariantCombination? getFirstInStockVariantForColor(String colorName) {
    if (colorName.isEmpty || variantCombinations.isEmpty) {
      return null;
    }

    final equivalentNames = _equivalentNormalizedColorNames(colorName);

    // Common attribute names used by the backend for color.
    const colorAttrNames = [
      'COLOR NAME',
      'color name',
      'Color Name',
      'color',
      'Color',
      'COLOR',
      'colour',
      'Colour',
      'اللون',
      'لون',
    ];

    for (final combo in variantCombinations) {
      // Match color (Arabic selectedColor matches variant English via colorOptions).
      String? variantColor;
      for (final attrName in colorAttrNames) {
        final v = combo.getAttributeValue(attrName);
        if (v != null && v.isNotEmpty) {
          variantColor = v;
          break;
        }
      }
      if (variantColor == null || variantColor.isEmpty) continue;

      if (!_variantColorMatches(variantColor, equivalentNames)) continue;

      // Check stock conditions: inStock == true AND quantityAvailable > 0
      final double qty = combo.quantityAvailable ?? 0;
      final bool inStockAndPositiveQty = combo.inStock && qty > 0;
      if (!inStockAndPositiveQty) continue;

      // Found first matching variant with stock
      return combo;
    }

    return null;
  }

  /// Gets a map of all currently selected attribute values.
  /// Key: attribute name (or attribute_id if available), Value: selected value name.
  /// This is useful for debugging and displaying selected attributes.
  Map<String, String> getAllSelectedAttributes() {
    final Map<String, String> selected = {};
    
    for (final opt in variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      
      // Use attribute_id as key if available, otherwise use attribute name
      final key = opt.attributeId?.isNotEmpty == true 
          ? opt.attributeId! 
          : (opt.apiAttributeName?.isNotEmpty == true ? opt.apiAttributeName! : opt.attributeName);
      
      selected[key] = opt.selectedValue;
    }
    
    return selected;
  }
}

class ProductTag extends Equatable {
  final String id;
  final String name;

  const ProductTag({
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [id, name];
}

/// Image helpers for variant-based products
///
/// These functions centralize the logic of picking images for a given
/// `variantId` using the `variantImagesMap` that is already parsed on
/// `ProductDetails`. They are safe to call from BLoC/UI whenever a
/// variant is selected (color, size, material, or any other attribute)
/// and will always fall back to the current `images` list when no
/// specific mapping exists for that variant.
extension ProductDetailsImagesX on ProductDetails {
  /// Return all images for a specific variant.
  /// Falls back to the existing product images when there is no mapping.
  List<String> imagesForVariant(String variantId) {
    if (variantId.isEmpty) return images;

    final variantImages = variantImagesMap[variantId] ?? const <String>[];

    // Debug: inspect what we actually have for this variant
    // (helps understand "single image vs three images" issues).
    // Note: keep prints lightweight in production if needed.
    // ignore: avoid_print
    print(
      '🧪 ProductDetailsImagesX.imagesForVariant → variantId=$variantId, '
      'mappedCount=${variantImages.length}, mappedImages=$variantImages',
    );

    if (variantImages.isNotEmpty) return List<String>.from(variantImages);

    // Fallback: keep current images (already set by API parsing)
    return List<String>.from(images);
  }

  /// Convenience: return a new ProductDetails with images updated
  /// to match the given variant.
  ProductDetails withImagesForVariant(String variantId) {
    return copyWith(
      images: List<String>.from(imagesForVariant(variantId)),
    );
  }
}

class ColorOption extends Equatable {
  final String id;
  final String name; // English name for data/logic matching
  final String? displayName; // Localized display name (Arabic when language is Arabic)
  final String code;
  final List<String> images;
  final bool isSelected;
  final bool isAvailable;

  const ColorOption({
    required this.id,
    required this.name,
    this.displayName,
    required this.code,
    required this.images,
    required this.isSelected,
    this.isAvailable = true, // Default to available if not specified
  });

  /// Get the display name (localized) or fallback to English name
  String get displayNameOrName => displayName ?? name;

  @override
  List<Object?> get props => [id, name, displayName, code, images, isSelected, isAvailable];
}

class SizeOption extends Equatable {
  final String id;
  final String name;
  final bool isAvailable;
  final bool isRecommended;
  final bool isSelected;

  const SizeOption({
    required this.id,
    required this.name,
    required this.isAvailable,
    required this.isRecommended,
    required this.isSelected,
  });

  @override
  List<Object?> get props => [id, name, isAvailable, isRecommended, isSelected];
}

class RelatedProduct extends Equatable {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String type; // 'template' or 'variant'

  const RelatedProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, price, imageUrl, type];
}

class VariantCombination extends Equatable {
  final String variantId;
  final bool inStock;
  final List<VariantAttribute> attributes;
  final double? quantityAvailable;

  const VariantCombination({
    required this.variantId,
    required this.inStock,
    required this.attributes,
    this.quantityAvailable,
  });

  @override
  List<Object?> get props => [variantId, inStock, attributes, quantityAvailable];

  /// Get the value of a specific attribute
  String? getAttributeValue(String attributeName) {
    try {
      return attributes.firstWhere((attr) =>
          attr.attributeName.toLowerCase() == attributeName.toLowerCase())
          .valueName;
    } catch (e) {
      return null;
    }
  }

  /// Get the value_id of a specific attribute (for matching when value_name differs e.g. Arabic vs English).
  String? getAttributeValueId(String attributeName) {
    try {
      final attr = attributes.firstWhere((attr) =>
          attr.attributeName.toLowerCase() == attributeName.toLowerCase());
      return attr.valueId;
    } catch (e) {
      return null;
    }
  }

  /// Check if this variant has a specific attribute value (by name or by value_id).
  bool hasAttributeValue(String attributeName, String valueName) {
    return getAttributeValue(attributeName)?.toLowerCase() == valueName.toLowerCase();
  }

  /// True if this variant has this attribute with the given value (match by valueName or valueId).
  bool hasAttributeValueOrId(String attributeName, String valueName, String? valueId) {
    final v = getAttributeValue(attributeName);
    final id = getAttributeValueId(attributeName);
    if (valueName.isNotEmpty && v != null &&
        v.toLowerCase().trim() == valueName.toLowerCase().trim()) return true;
    if (valueId != null && valueId.isNotEmpty && id != null &&
        id.trim() == valueId.trim()) return true;
    return false;
  }

  /// Returns true if this variant's attributes match the given map of
  /// [attributeName] -> [valueId] (API attribute_name and value_id).
  /// Used to filter the exact variant combination for stock badge.
  bool matchesAttributesById(Map<String, String> attributeNameToValueId) {
    if (attributeNameToValueId.isEmpty) return false;
    for (final entry in attributeNameToValueId.entries) {
      final apiName = entry.key;
      final valueId = entry.value;
      if (valueId.isEmpty) continue;
      final attr = attributes.where((a) =>
          a.attributeName.toLowerCase().trim() == apiName.toLowerCase().trim()).toList();
      if (attr.isEmpty) return false;
      final match = attr.any((a) => a.valueId != null && a.valueId!.trim() == valueId.trim());
      if (!match) return false;
    }
    return true;
  }

  /// Returns true if this variant's attributes match the given map of
  /// [attributeName] -> [value_name] (string). Compares variant's attribute value_name
  /// with the selected value string (e.g. "BLACK", "36", "Synthetic Leather", "4.5").
  /// Keys are logical names (COLOR, SIZE, MATERIALS, HEIGHT); variant may use "COLOR NAME", "SIZE", etc.
  bool matchesAttributesByValueName(Map<String, String> attributeNameToValueName) {
    if (attributeNameToValueName.isEmpty) return false;
    String norm(String s) => s.toLowerCase().trim();
    bool attrNameMatches(String variantAttrName, String logicalKey) {
      final v = norm(variantAttrName);
      final k = norm(logicalKey);
      if (v == k) return true;
      if (k == 'color') return v == 'color' || v == 'color name' || v == 'colour' || v == 'اللون';
      if (k == 'size') return v == 'size' || v.contains('size');
      if (k == 'materials') return v == 'materials' || v == 'material name' || v == 'material';
      if (k == 'height') return v == 'height' || v.contains('heel');
      return false;
    }
    for (final entry in attributeNameToValueName.entries) {
      final logicalKey = entry.key;
      final selectedValue = entry.value;
      if (selectedValue.isEmpty) continue;
      final attrs = attributes.where((a) => attrNameMatches(a.attributeName, logicalKey)).toList();
      if (attrs.isEmpty) return false;
      final match = attrs.any((a) => norm(a.valueName) == norm(selectedValue));
      if (!match) return false;
    }
    return true;
  }

  /// Returns true if this variant's attributes match the given map of
  /// [attribute_id] -> [value_name]. Validates using variant_combinations
  /// attributes (attribute_id and value_name). Used when we have attribute ids
  /// from variant_attributes to filter the exact variant.
  bool matchesAttributesByAttributeIdAndValueName(Map<String, String> attributeIdToValueName) {
    if (attributeIdToValueName.isEmpty) return false;
    String norm(String s) => s.toLowerCase().trim();
    for (final entry in attributeIdToValueName.entries) {
      final attrId = entry.key.trim();
      final selectedValue = entry.value;
      if (attrId.isEmpty || selectedValue.isEmpty) continue;
      final attrs = attributes.where((a) =>
          (a.attributeId ?? '').trim() == attrId).toList();
      if (attrs.isEmpty) return false;
      final match = attrs.any((a) => norm(a.valueName) == norm(selectedValue));
      if (!match) return false;
    }
    return true;
  }
}

class VariantAttribute extends Equatable {
  final String attributeName;
  final String valueName; //size 42
  // Optional numeric identifiers coming from the API (attribute_id, value_id)
  final String? attributeId;
  final String? valueId; //

  const VariantAttribute({
    required this.attributeName,
    required this.valueName,
    this.attributeId,
    this.valueId,
  });

  @override
  List<Object?> get props => [attributeName, valueName, attributeId, valueId];
}

class VariantAttributeOption extends Equatable {
  final String attributeName;
  final List<VariantAttributeValue> values;
  final String selectedValue;
  /// API attribute name as returned in variant_combinations (e.g. MATERIALS, HEIGHT).
  /// Used for combo lookup so any attribute works without hardcoding names.
  final String? apiAttributeName;
  /// Attribute id from variant_attributes (e.g. 8=COLOR, 7=SIZE, 9=MATERIALS, 10=HEIGHT).
  /// Used to filter variants by attribute_id + value_name.
  final String? attributeId;

  const VariantAttributeOption({
    required this.attributeName,
    required this.values,
    required this.selectedValue,
    this.apiAttributeName,
    this.attributeId,
  });

  @override
  List<Object?> get props => [attributeName, values, selectedValue, apiAttributeName, attributeId];
}

class VariantAttributeValue extends Equatable {
  final String id;
  final String name; // English name for matching/logic
  final String? displayName; // Localized display name (Arabic when locale is Arabic)
  final bool isAvailable;
  final bool isSelected;

  const VariantAttributeValue({
    required this.id,
    required this.name,
    this.displayName,
    required this.isAvailable,
    required this.isSelected,
  });

  /// Get the display name (localized) or fallback to English name
  String get displayNameOrName => displayName ?? name;

  @override
  List<Object?> get props => [id, name, displayName, isAvailable, isSelected];
}
