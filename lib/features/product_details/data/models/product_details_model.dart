import 'package:flutter/foundation.dart';
import '../../domain/entities/product_details.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/image_cache_utils.dart';

class ProductDetailsModel extends ProductDetails {
  const ProductDetailsModel({
    required super.id,
    required super.brand,
    required super.name,
    required super.description,
    required super.price,
    super.originalPrice,
    required super.rating,
    required super.reviewCount,
    required super.images,
    required super.colorOptions,
    required super.sizeOptions,
    super.variantAttributeOptions = const [],
    required super.selectedColor,
    required super.selectedSize,
    required super.isFavorite,
    required super.hasDiscount,
    super.discountPercentage,
    required super.features,
    required super.material,
    super.materialsList = const [],
    super.materialOptions = const [],
    super.selectedMaterial,
    required super.careInstructions,
    super.websiteUrl,
    super.heelHeightCm,
    super.heelType,
    super.heelHeightOptions = const [],
    super.selectedHeelHeightCm,
    required super.isPlusMember,
    required super.pointsEarned,
    super.optionalProducts = const [],
    super.accessoryProducts = const [],
    super.alternativeProducts = const [],
    super.variantCombinations = const [],
    super.primaryVariantLabel = 'Size',
    super.inStock = true,
    super.selectedVariantQuantityAvailable,
    super.tags = const [],
    super.variantImagesMap = const {},
    super.attributeValueCombinations = const {},
  });

  factory ProductDetailsModel.fromJson(Map<String, dynamic> json) {
    return ProductDetailsModel(
      id: json['id'] ?? '',
      brand: json['brand'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      originalPrice: json['originalPrice'] != null ? (json['originalPrice'] as num).toDouble() : null,
      rating: json['rating'] ?? 0,
      reviewCount: json['reviewCount'] ?? 0,
      images: List<String>.from(json['images'] ?? []),
      colorOptions: (json['colorOptions'] as List<dynamic>?)
              ?.map((e) => ColorOptionModel.fromJson(e))
              .toList() ??
          [],
      sizeOptions: (json['sizeOptions'] as List<dynamic>?)
              ?.map((e) => SizeOptionModel.fromJson(e))
              .toList() ??
          [],
      selectedColor: json['selectedColor'] ?? '',
      selectedSize: json['selectedSize'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
      hasDiscount: json['hasDiscount'] ?? false,
      discountPercentage: json['discountPercentage'],
      features: List<String>.from(json['features'] ?? []),
      material: json['material'] ?? '',
      materialsList: (json['materialsList'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      materialOptions: (json['materialOptions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      selectedMaterial: json['selectedMaterial'] as String?,
      careInstructions: json['careInstructions'] ?? '',
      heelHeightCm: (json['heelHeightCm'] as num?)?.toDouble(),
      heelType: json['heelType'] as String?,
      heelHeightOptions: (json['heelHeightOptions'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      selectedHeelHeightCm: (json['selectedHeelHeightCm'] as num?)?.toDouble(),
      isPlusMember: json['isPlusMember'] ?? false,
      pointsEarned: json['pointsEarned'] ?? 0,
    );
  }

  factory ProductDetailsModel.fromApiJson(Map<String, dynamic> json) {
    try {
      print('🔍 ProductDetailsModel: Parsing API response for product: ${json['name']}');
      
      // Parse variant combinations and build options for all variant attributes
      // Backend can return variant_combinations either as a List or as a Map.
      // Normalize to a List for the rest of the logic.
      final variantCombinations = _normalizeVariantCombinations(json['variant_combinations']);
      final variantAttributes = json['variant_attributes'] as List<dynamic>? ?? [];
      
      List<SizeOptionModel> sizeOptions = [];
      List<VariantAttributeOptionModel> variantAttributeOptions = [];
      String primaryVariantLabel = 'Size';
      
      // First, build a map of color ID to English name from variant combinations
      // CRITICAL: Also build a map of Arabic name to English name, since IDs might not match
      // Variant combinations often have English names even when API language is Arabic
      final Map<String, String> colorIdToEnglishName = {};
      final Map<String, String> colorNameToEnglishName = {}; // Maps Arabic name -> English name
      final Map<String, String> colorNameToId = {}; // Maps Arabic name -> ID (from variant_attributes)
      
      print('🔍 ProductDetailsModel: Building colorIdToEnglishName from ${variantCombinations.length} variant combinations');
      
      // Log first few variant combinations to see what we're working with
      if (variantCombinations.isNotEmpty) {
        print('🔍 ProductDetailsModel: Sample variant combination structure:');
        final sample = variantCombinations.first;
        if (sample is Map) {
          final attrs = (sample['attributes'] as List<dynamic>? ?? const []);
          for (final a in attrs) {
            if (a is Map) {
              final attrName = (a['attribute_name'] ?? '').toString();
              final valueId = (a['value_id'] ?? '').toString();
              final valueName = (a['value_name'] ?? '').toString();
              print('   Attribute: "$attrName", value_id: $valueId, value_name: "$valueName" (isArabic: ${_containsArabic(valueName)})');
            }
          }
        }
      }
      
      // First pass: collect all color names and IDs from variant combinations
      for (final v in variantCombinations) {
        if (v is Map) {
          final attrs = (v['attributes'] as List<dynamic>? ?? const []);
          for (final a in attrs) {
            if (a is Map) {
              final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
              if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
                final valueId = (a['value_id'] ?? '').toString();
                final valueName = (a['value_name'] ?? '').toString();
                // Check if this looks like an English name (not Arabic characters)
                final isEnglish = !_containsArabic(valueName);
                if (isEnglish && valueId.isNotEmpty) {
                  if (!colorIdToEnglishName.containsKey(valueId)) {
                    colorIdToEnglishName[valueId] = valueName;
                    print('📝 ProductDetailsModel [variant_attributes section]: Added to colorIdToEnglishName - ID=$valueId, English="$valueName"');
                  }
                } else if (valueId.isNotEmpty) {
                  print('⚠️ ProductDetailsModel [variant_attributes section]: Found Arabic color in variant - ID=$valueId, name="$valueName"');
                  // Store Arabic name -> ID mapping
                  colorNameToId[valueName] = valueId;
                }
              }
            }
          }
        }
      }
      
      // Second pass: try to find English equivalents for Arabic names
      // Look for variants with same ID but English name
      for (final v in variantCombinations) {
        if (v is Map) {
          final attrs = (v['attributes'] as List<dynamic>? ?? const []);
          for (final a in attrs) {
            if (a is Map) {
              final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
              if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
                final valueId = (a['value_id'] ?? '').toString();
                final valueName = (a['value_name'] ?? '').toString();
                final isEnglish = !_containsArabic(valueName);
                
                // If this is English and we have an Arabic name with same ID, map them
                if (isEnglish && valueId.isNotEmpty) {
                  // Check if we already have this ID mapped
                  if (!colorIdToEnglishName.containsKey(valueId)) {
                    colorIdToEnglishName[valueId] = valueName;
                  }
                  // Also check if any Arabic name maps to this ID
                  for (final entry in colorNameToId.entries) {
                    if (entry.value == valueId) {
                      colorNameToEnglishName[entry.key] = valueName;
                      print('✅ ProductDetailsModel: Mapped Arabic "${entry.key}" (ID=$valueId) -> English "$valueName"');
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      print('🔍 ProductDetailsModel [variant_attributes section]: Built colorIdToEnglishName with ${colorIdToEnglishName.length} entries');
      print('🔍 ProductDetailsModel [variant_attributes section]: Built colorNameToEnglishName with ${colorNameToEnglishName.length} entries');
      
      // Use variant_attributes whenever present so all attribute values (e.g. all sizes) are shown.
      // When variant_combinations is empty (e.g. lite API), use attribute_value_combinations for availability.
      if (variantAttributes.isNotEmpty) {
        final avc = _parseAttributeValueCombinations(json);
        // Process each variant attribute
        for (final attr in variantAttributes) {
          final attrName = (attr['name'] ?? '').toString();
          if (attrName.isEmpty) continue;
          
          // Handle COLOR NAME attribute separately to ensure English names
          final isColorAttribute = attrName.toLowerCase() == 'color' || 
                                   attrName.toLowerCase() == 'colour' || 
                                   attrName.toLowerCase() == 'اللون' || 
                                   attrName.toLowerCase() == 'color name';
          
          if (isColorAttribute) {
            // Create COLOR NAME variantAttributeOption with English names only
            final attrValues = (attr['values'] as List<dynamic>? ?? []);
            final List<VariantAttributeValueModel> colorValues = [];
            
            for (final value in attrValues) {
              final valueId = (value['id'] ?? '').toString();
              final localizedName = (value['name'] ?? '').toString();
              
              // Get English name from our map - try multiple strategies
              String englishName = colorIdToEnglishName[valueId] ?? '';
              
              print('🔍 ProductDetailsModel [variantAttributeOptions]: Processing color - ID: $valueId, localized: "$localizedName", english from map: "$englishName"');
              
              // Strategy 1: Try by ID
              if (englishName.isEmpty || _containsArabic(englishName)) {
                // Strategy 2: Try by Arabic name -> English name mapping (if localized is Arabic)
                if (_containsArabic(localizedName) && colorNameToEnglishName.containsKey(localizedName)) {
                  englishName = colorNameToEnglishName[localizedName]!;
                  print('✅ ProductDetailsModel: Found English name via Arabic name mapping: "$localizedName" -> "$englishName"');
                } else {
                  // Strategy 3: Try to find English name by matching ID across all variant combinations
                  for (final v in variantCombinations) {
                    if (v is Map) {
                      final attrs = (v['attributes'] as List<dynamic>? ?? const []);
                      for (final a in attrs) {
                        if (a is Map) {
                          final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
                          final variantValueId = (a['value_id'] ?? '').toString();
                          final variantValueName = (a['value_name'] ?? '').toString();
                          if ((attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') &&
                              variantValueId == valueId && !_containsArabic(variantValueName)) {
                            englishName = variantValueName;
                            colorIdToEnglishName[valueId] = variantValueName;
                            print('✅ ProductDetailsModel: Found English name "$englishName" for color ID $valueId from variant combination');
                            break;
                          }
                        }
                      }
                      if (englishName.isNotEmpty && !_containsArabic(englishName)) break;
                    }
                  }
                }
              }
              
              // If still no English name found, use localized name (fallback) or log error
              if (englishName.isEmpty || _containsArabic(englishName)) {
                if (!_containsArabic(localizedName)) {
                  // Localized is already English
                  englishName = localizedName;
                  print('✅ ProductDetailsModel: Using localized name as English (not Arabic): "$englishName"');
                } else {
                  print('⚠️ ProductDetailsModel: Could not find English name for color ID $valueId (localized: $localizedName)');
                  print('   Available colorIdToEnglishName keys: ${colorIdToEnglishName.keys.toList()}');
                  print('   Available colorNameToEnglishName keys: ${colorNameToEnglishName.keys.toList()}');
                  // Don't use Arabic - this will cause matching issues
                  englishName = ''; // Will trigger UNKNOWN_COLOR fallback
                }
              } else {
                print('✅ ProductDetailsModel: Found English name "$englishName" for color ID $valueId (localized: $localizedName)');
              }
              
              // Check availability: variant_combinations when present, else attribute_value_combinations
              bool isAvailable = false;
              if (variantCombinations.isNotEmpty) {
                for (final variant in variantCombinations) {
                  final attrs = (variant['attributes'] as List<dynamic>? ?? const []);
                  for (final a in attrs) {
                    if (a is Map) {
                      final variantAttrName = (a['attribute_name'] ?? '').toString();
                      final variantValueId = (a['value_id'] ?? '').toString();
                      final variantValueName = (a['value_name'] ?? '').toString();
                      if ((variantAttrName.toLowerCase() == 'color name' ||
                           variantAttrName.toLowerCase() == 'color' ||
                           variantAttrName.toLowerCase() == 'colour' ||
                           variantAttrName.toLowerCase() == 'اللون') &&
                          (variantValueId == valueId ||
                           variantValueName.toLowerCase() == englishName.toLowerCase() ||
                           variantValueName.toLowerCase() == localizedName.toLowerCase())) {
                        isAvailable = (variant['in_stock'] ?? false) as bool;
                        break;
                      }
                    }
                  }
                  if (isAvailable) break;
                }
              } else {
                isAvailable = avc.isEmpty || avc.containsKey(valueId);
              }
              
              // Ensure we never add a color value with empty name (causes "value="" disabled in BLoC)
              final nameForOption = englishName.isEmpty ? 'COLOR_ID_$valueId' : englishName;
              colorValues.add(VariantAttributeValueModel(
                id: valueId,
                name: nameForOption, // Always use English name for variantAttributeOptions
                isAvailable: isAvailable,
                isSelected: false,
              ));
            }
            
            // Select first available
            String selectedColorValue = '';
            if (colorValues.isNotEmpty) {
              final firstAvailable = colorValues.firstWhere(
                (v) => v.isAvailable,
                orElse: () => colorValues.first,
              );
              selectedColorValue = firstAvailable.name;

              final selectedIdx = colorValues.indexWhere((v) => v.name == selectedColorValue);
              if (selectedIdx >= 0) {
                colorValues[selectedIdx] = VariantAttributeValueModel(
                  id: firstAvailable.id,
                  name: firstAvailable.name,
                  isAvailable: firstAvailable.isAvailable,
                  isSelected: true,
                );
              }
            }
            
            final attrId = (attr['id'] ?? '').toString();
            variantAttributeOptions.add(VariantAttributeOptionModel(
              attributeName: 'COLOR NAME', // Use standard English name
              values: colorValues,
              selectedValue: selectedColorValue,
              apiAttributeName: attrName, // API name for combo lookup (dynamic)
              attributeId: attrId.isEmpty ? null : attrId,
            ));
            
            continue; // Skip to next attribute
          }
          
          // Process non-color attributes: map dynamically from variant_attributes only
          final attrValues = (attr['values'] as List<dynamic>? ?? []);
          final List<VariantAttributeValueModel> values = [];

          // Value synchronization: use variant_attributes[].values[].name as the single
          // source of truth for labels. Do not substitute with value_name from
          // variant_combinations (which can cause "ghosting" e.g. showing 4.5 when only 9 exists).
          for (final value in attrValues) {
            final valueId = (value['id'] ?? '').toString();
            final localizedName = (value['name'] ?? '').toString().trim();
            if (localizedName.isEmpty) continue;

            // Canonical name from API: always use the name from variant_attributes
            final String canonicalName = localizedName;

            // Availability: variant_combinations when present, else attribute_value_combinations
            bool isAvailable = false;
            if (variantCombinations.isNotEmpty) {
              for (final variant in variantCombinations) {
                if (variant is! Map) continue;
                final inStock = (variant['in_stock'] ?? false) as bool;
                if (!inStock) continue;
                final attrs = (variant['attributes'] as List<dynamic>? ?? const []);
                for (final a in attrs) {
                  if (a is Map) {
                    final variantAttrName = (a['attribute_name'] ?? '').toString();
                    final variantValueId = (a['value_id'] ?? '').toString();
                    final variantValueName = (a['value_name'] ?? '').toString().trim();
                    final attrNameLower = attrName.toLowerCase();
                    final variantAttrNameLower = variantAttrName.toLowerCase();
                    final isMatchingAttribute = variantAttrNameLower == attrNameLower ||
                                              variantAttrNameLower.contains(attrNameLower) ||
                                              attrNameLower.contains(variantAttrNameLower);
                    final valueMatch = variantValueId == valueId ||
                        variantValueName.toLowerCase() == canonicalName.toLowerCase();
                    if (isMatchingAttribute && valueMatch) {
                      isAvailable = true;
                      break;
                    }
                  }
                }
                if (isAvailable) break;
              }
            } else {
              isAvailable = avc.isEmpty || avc.containsKey(valueId);
            }

            values.add(VariantAttributeValueModel(
              id: valueId,
              name: canonicalName,
              isAvailable: isAvailable,
              isSelected: false,
            ));
          }
          
          // Select the first available value by default
          String selectedValue = '';
          if (values.isNotEmpty) {
            final firstAvailable = values.firstWhere(
              (v) => v.isAvailable,
              orElse: () => values.first,
            );
            selectedValue = firstAvailable.name;
            // Mark as selected
            values[values.indexWhere((v) => v.name == selectedValue)] = VariantAttributeValueModel(
              id: firstAvailable.id,
              name: firstAvailable.name,
              isAvailable: firstAvailable.isAvailable,
              isSelected: true,
            );
          }
          
          // Use standard English attribute name for internal matching
          // Map common Arabic attribute names to English
          String englishAttrName = attrName;
          final attrNameLower = attrName.toLowerCase();
          if (attrNameLower == 'القياس' || attrNameLower.contains('size') || attrNameLower.contains('قياس')) {
            englishAttrName = 'SIZE';
          } else if (attrNameLower == 'المادة' || attrNameLower.contains('material')) {
            englishAttrName = 'MATERIAL NAME';
          } else if (attrNameLower == 'اللون' || attrNameLower.contains('color')) {
            englishAttrName = 'COLOR NAME';
          } else if (attrNameLower == 'الموسم' || attrNameLower.contains('season')) {
            englishAttrName = 'SEASON';
          } else if (attrNameLower == 'الجنس' || attrNameLower.contains('gender')) {
            englishAttrName = 'GENDER';
          }
          // Keep original if it's already in English or we can't determine
          
          final attrId = (attr['id'] ?? '').toString();
          variantAttributeOptions.add(VariantAttributeOptionModel(
            attributeName: englishAttrName, // Use English attribute name for consistency
            values: values,
            selectedValue: selectedValue,
            apiAttributeName: attrName, // API name as in variant_combinations (dynamic)
            attributeId: attrId.isEmpty ? null : attrId,
          ));
          
          // Set the first non-color attribute as primary for backward compatibility
          if (primaryVariantLabel == 'Size' && attrNameLower != 'color') {
            primaryVariantLabel = englishAttrName; // Use English name
          }
        }
      }

    // When lite API omits variant_attributes, build non-color attribute options from
    // selected_variant + variant_combinations so the full list of values is shown (not only selected).
    final hasNonColorOptions = variantAttributeOptions.any((o) => !_isColorAttributeName(o.attributeName));
    if (!hasNonColorOptions) {
      final selVariant = json['selected_variant'] as Map<String, dynamic>?;
      if (selVariant != null) {
        // Collect all unique (value_id, value_name) per attribute from variant_combinations
        // so we can show the full list of options, not just the selected value.
        final combos = _normalizeVariantCombinations(json['variant_combinations']);
        final Map<String, List<({String id, String name})>> valuesByAttrId = {};
        for (final v in combos) {
          if (v is! Map) continue;
          final attrs = (v['attributes'] as List<dynamic>?) ?? [];
          for (final a in attrs) {
            if (a is! Map) continue;
            final attrId = (a['attribute_id'] ?? '').toString();
            final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
            if (attrId.isEmpty) continue;
            if (attrName == 'color' || attrName == 'colour' ||
                attrName == 'اللون' || attrName == 'color name') continue;
            final valueId = (a['value_id'] ?? '').toString();
            final valueName = (a['value_name'] ?? '').toString().trim();
            if (valueId.isEmpty && valueName.isEmpty) continue;
            valuesByAttrId.putIfAbsent(attrId, () => []);
            final list = valuesByAttrId[attrId]!;
            if (!list.any((e) => e.id == valueId || e.name == valueName)) {
              list.add((id: valueId, name: valueName));
            }
          }
        }

        final selAttrs = (selVariant['attributes'] as List<dynamic>?) ?? [];
        for (final sa in selAttrs) {
          if (sa is! Map) continue;
          final attrName = (sa['attribute_name'] ?? '').toString().trim();
          final valueName = (sa['value_name'] ?? '').toString().trim();
          final valueId = (sa['value_id'] ?? '').toString();
          final attrId = (sa['attribute_id'] ?? '').toString();
          if (attrName.isEmpty) continue;
          final attrNameLower = attrName.toLowerCase();
          if (attrNameLower == 'color' || attrNameLower == 'colour' ||
              attrNameLower == 'اللون' || attrNameLower == 'color name') continue;
          String englishAttrName = attrName;
          if (attrNameLower.contains('size') || attrNameLower == 'القياس') {
            englishAttrName = 'SIZE';
          } else if (attrNameLower.contains('material')) {
            englishAttrName = 'MATERIAL NAME';
          } else if (attrNameLower.contains('height') || attrNameLower.contains('heel')) {
            englishAttrName = 'HEIGHT';
          }

          // Use all values from variant_combinations for this attribute when available
          final allValues = valuesByAttrId[attrId] ?? <({String id, String name})>[];
          final List<VariantAttributeValueModel> valueModels = allValues.isNotEmpty
              ? allValues.map((e) {
                  final isSelected = e.id == valueId || e.name == valueName;
                  return VariantAttributeValueModel(
                    id: e.id,
                    name: e.name,
                    isAvailable: true,
                    isSelected: isSelected,
                  );
                }).toList()
              : [
                  VariantAttributeValueModel(
                    id: valueId,
                    name: valueName,
                    isAvailable: true,
                    isSelected: true,
                  ),
                ];

          variantAttributeOptions.add(VariantAttributeOptionModel(
            attributeName: englishAttrName,
            apiAttributeName: attrName,
            attributeId: attrId.isEmpty ? null : attrId,
            values: valueModels,
            selectedValue: valueName,
          ));
        }
        if (variantAttributeOptions.isNotEmpty) {
          debugPrint(
            '📋 ProductDetailsModel: Built ${variantAttributeOptions.length} attribute option(s) from selected_variant + variant_combinations (lite fallback)',
          );
        }
      }
    }

    // Preselect attribute values from an initial variant:
    // 1) Prefer explicit selected_variant from the API when present.
    // 2) Otherwise, fall back to the first entry in variant_combinations.
    // This ensures that, on first load, the UI reflects a real variant
    // combination instead of arbitrary "first available" values per attribute.
    double? selectedHeelHeightFromVariant;
    Map<String, dynamic>? initialVariant =
        json['selected_variant'] as Map<String, dynamic>?;

    if (initialVariant == null) {
      final List<dynamic> combos =
          _normalizeVariantCombinations(json['variant_combinations']);
      if (combos.isNotEmpty && combos.first is Map<String, dynamic>) {
        initialVariant = combos.first as Map<String, dynamic>;
      }
    }

    // Preselect only values that exist in variant_attributes (no ghost values)
    if (initialVariant != null) {
      debugPrint('📥 [Step 2 - Model] selected_variant from API: $initialVariant');
      final List<dynamic> selAttrs =
          (initialVariant['attributes'] as List<dynamic>?) ?? const [];
      if (selAttrs.isNotEmpty && variantAttributeOptions.isNotEmpty) {
        for (final sa in selAttrs) {
          if (sa is! Map) continue;
          final String attrName = (sa['attribute_name'] ?? '').toString();
          final String valueName = (sa['value_name'] ?? '').toString().trim();
          final String valueIdFromVariant = (sa['value_id'] ?? '').toString();
          debugPrint(
            '   → [Step 2 - Model] selected_variant attr: "$attrName" '
            '(value_id=$valueIdFromVariant, value_name="$valueName")',
          );

          // Capture numeric heel height when available
          if (attrName.toLowerCase() == 'height' ||
              attrName.toLowerCase() == 'heel height') {
            final numeric = double.tryParse(
              valueName.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            if (numeric != null) {
              selectedHeelHeightFromVariant = numeric;
            }
          }

          final int optIdx = variantAttributeOptions.indexWhere(
            (o) =>
                o.attributeName.toLowerCase() == attrName.toLowerCase() ||
                (o.apiAttributeName?.toLowerCase() ==
                    attrName.toLowerCase()),
          );
          if (optIdx < 0) {
            debugPrint(
              '⚠️ [Step 2 - Model] No matching option for selected_variant attr "$attrName" '
              '(value_id=$valueIdFromVariant value_name="$valueName"). '
              'Available options: ${variantAttributeOptions.map((o) => '"${o.attributeName}" api="${o.apiAttributeName ?? ""}"').toList()}',
            );
          }
          if (optIdx >= 0) {
            final opt = variantAttributeOptions[optIdx];
            // Only use a selection that exists in this attribute's values (by id or name)
            String? selectedValueToApply;
            for (final v in opt.values) {
              if (v.id == valueIdFromVariant ||
                  v.name.toLowerCase().trim() == valueName.toLowerCase()) {
                selectedValueToApply = v.name;
                break;
              }
            }
            if (selectedValueToApply == null) {
              debugPrint(
                '⚠️ [Step 2 - Model] Could not match value for "$attrName": '
                'value_id=$valueIdFromVariant value_name="$valueName" '
                '(option values: ${opt.values.map((v) => '${v.id}:${v.name}').toList()})',
              );
              continue;
            }
            debugPrint(
              '   → [Step 2 - Model] Applying to option "${opt.attributeName}": '
              'selectedValue="$selectedValueToApply" (before: "${opt.selectedValue}")',
            );
            final updatedValues = opt.values.map((v) {
              return VariantAttributeValueModel(
                id: v.id,
                name: v.name,
                isAvailable: v.isAvailable,
                isSelected: v.name == selectedValueToApply,
              );
            }).toList();
            variantAttributeOptions[optIdx] = VariantAttributeOptionModel(
              attributeName: opt.attributeName,
              values: updatedValues,
              selectedValue: selectedValueToApply,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
          }
        }
        // Log final selectedValue per attribute option
        for (final opt in variantAttributeOptions) {
          debugPrint(
            '✅ [Step 2 - Model] Final initial selection → '
            '"${opt.attributeName}" selectedValue="${opt.selectedValue}"',
          );
        }
      }
    }

    // Create color options based on available data
    final productType = (json['type'] ?? 'variant').toString();
    final productId = (json['id'] ?? '').toString();
    final parsedImages = _parseImages(json['images'], productType: productType, productId: productId);
    final variantImagesMap = _buildVariantImagesMap(json['images'], productType: productType);
    print('📊 ProductDetailsModel: variantImagesMap keys for product $productId = ${variantImagesMap.keys.toList()}');
    // Build map: variant_id -> color name and choose ONE canonical variant per color
    final Map<String, String> variantIdToColor = {};
    final Map<String, String> canonicalVariantIdByColor = {};
    final Map<String, String> variantIdToImage = {};
    for (final v in _normalizeVariantCombinations(json['variant_combinations'])) {
      if (v is Map) {
        final id = (v['variant_id'] ?? '').toString();
        String colorName = '';
        final attrs = (v['attributes'] as List<dynamic>? ?? const []);
        for (final a in attrs) {
          if (a is Map) {
            final n = (a['attribute_name'] ?? '').toString().toLowerCase();
            // Support all color attribute naming variants used by the API,
            // including "COLOR NAME" as seen in the latest responses.
            if (n == 'color' || n == 'colour' || n == 'اللون' || n == 'color name') {
              colorName = (a['value_name'] ?? '').toString();
            }
          }
        }
        if (id.isNotEmpty && colorName.isNotEmpty) {
          variantIdToColor[id] = colorName;
          // First variant encountered for a color becomes the canonical one
          canonicalVariantIdByColor.putIfAbsent(colorName, () => id);
        }
      }
    }

    final Map<String, List<String>> colorToImages = {};
    // template image
    String? templateImage;
    for (final e in (json['images'] as List<dynamic>? ?? const [])) {
      if (e is Map) {
        String url = e['url']?.toString() ?? '';
        if (url.startsWith('/')) url = '${AppConstants.baseUrl}${url.substring(1)}';
        final type = (e['type'] ?? '').toString();
        if (type == 'template' && url.isNotEmpty) {
          templateImage = url;
        }
        // Variant-level images (main or gallery) are mapped to their color via variant_id
        if (type == 'variant' || type == 'variant_gallery') {
          final vid = (e['variant_id'] ?? '').toString();
          final color = variantIdToColor[vid];
          // Only use images from the canonical variant for this color to avoid
          // duplicating visually identical images across sizes.
          if (color != null &&
              url.isNotEmpty &&
              vid.isNotEmpty &&
              canonicalVariantIdByColor[color] == vid) {
            colorToImages.putIfAbsent(color, () => <String>[]);
            if (!colorToImages[color]!.contains(url)) {
              colorToImages[color]!.add(url);
              print('🖼️ Added variant image for color "$color" (variant_id: $vid): $url');
            }
          }
          if (vid.isNotEmpty && url.isNotEmpty) {
            variantIdToImage[vid] = url;
          }
        }
        // Handle template_gallery images - filter by variant_id
        if (type == 'template_gallery') {
          final vid = (e['variant_id'] ?? '').toString();
          final color = variantIdToColor[vid];
          if (color != null && url.isNotEmpty && vid.isNotEmpty) {
            colorToImages.putIfAbsent(color, () => <String>[]);
            if (!colorToImages[color]!.contains(url)) {
              colorToImages[color]!.add(url);
              print('🖼️ Added template_gallery image for color "$color" (variant_id: $vid): $url');
            }
          }
        }
      }
    }
    print('🔍 ProductDetailsModel: parsedImages.length = ${parsedImages.length}');
    print('🔍 ProductDetailsModel: parsedImages = $parsedImages');
    
    List<ColorOptionModel> colorOptions;
    // Prefer explicit color attribute from variant_attributes when present
    final variantAttrs = (json['variant_attributes'] as List<dynamic>?) ?? const [];
    final selectedVariant = json['selected_variant'] as Map<String, dynamic>?;
    String? selectedColorName;
    if (selectedVariant != null) {
      print('🎯 ProductDetailsModel: Processing selected_variant: $selectedVariant');
      final attrs = (selectedVariant['attributes'] as List<dynamic>?) ?? const [];
      for (final a in attrs) {
        final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
        if (attrName == 'color' || attrName == 'colour' || attrName == 'اللون' || attrName == 'color name') {
          selectedColorName = (a['value_name'] ?? '').toString();
          print('🎨 ProductDetailsModel: Found selected color: $selectedColorName');
        }
      }
    }
    Map<String, dynamic>? colorAttr;
    for (final a in variantAttrs) {
      if (a != null && a is Map<String, dynamic>) {
        final n = (a['name'] ?? '').toString().toLowerCase();
        if (n == 'color' || n == 'colour' || n == 'اللون' || n == 'color name') {
          colorAttr = a;
          break;
        }
      }
    }
    if (colorAttr != null) {
      final values = (colorAttr['values'] as List<dynamic>? ?? const []);
      
      // Build a map of color ID to English name from variant combinations
      // Variant combinations often have English names even when API language is Arabic
      final Map<String, String> colorIdToEnglishName = {};
      for (final v in variantCombinations) {
        if (v is Map) {
          final attrs = (v['attributes'] as List<dynamic>? ?? const []);
          for (final a in attrs) {
            if (a is Map) {
              final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
              if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
                final valueId = (a['value_id'] ?? '').toString();
                final valueName = (a['value_name'] ?? '').toString();
                // Check if this looks like an English name (not Arabic characters)
                final isEnglish = !_containsArabic(valueName);
                if (isEnglish && valueId.isNotEmpty) {
                  colorIdToEnglishName[valueId] = valueName;
                  print('📝 ProductDetailsModel: Added to colorIdToEnglishName map: ID=$valueId, English="$valueName"');
                } else if (valueId.isNotEmpty) {
                  print('⚠️ ProductDetailsModel: Found Arabic color name in variant combination: ID=$valueId, name="$valueName"');
                }
              }
            }
          }
        }
      }
      print('🔍 ProductDetailsModel: Built colorIdToEnglishName map with ${colorIdToEnglishName.length} entries: ${colorIdToEnglishName.entries.map((e) => '${e.key}:"${e.value}"').toList()}');
      
      colorOptions = values.map((v) {
        final localizedName = (v['name'] ?? '').toString();
        final colorId = (v['id'] ?? localizedName).toString();
        
        // Get English name from variant combinations if available
        String englishName = colorIdToEnglishName[colorId] ?? '';
        
        print('🔍 ProductDetailsModel: Processing color - ID: $colorId, localized: "$localizedName", english from map: "$englishName"');
        
        // If we couldn't find English name, try to find it by matching ID in variant combinations
        if (englishName.isEmpty || _containsArabic(englishName)) {
          print('🔍 ProductDetailsModel: Searching variant combinations for English name for color ID $colorId');
          // Try to find English name by matching ID in variant combinations
          for (final vc in variantCombinations) {
            if (vc is Map) {
              final attrs = (vc['attributes'] as List<dynamic>? ?? const []);
              for (final a in attrs) {
                if (a is Map) {
                  final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
                  final valueId = (a['value_id'] ?? '').toString();
                  final valueName = (a['value_name'] ?? '').toString();
                  if ((attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') &&
                      valueId == colorId && !_containsArabic(valueName)) {
                    englishName = valueName;
                    colorIdToEnglishName[colorId] = valueName; // Cache it
                    print('✅ ProductDetailsModel: Found English name "$englishName" for color ID $colorId from variant combination');
                    break;
                  }
                }
              }
              if (englishName.isNotEmpty && !_containsArabic(englishName)) break;
            }
          }
        }
        
        // If still no English name found, and localized is not Arabic, use localized
        if (englishName.isEmpty || _containsArabic(englishName)) {
          if (!_containsArabic(localizedName)) {
            englishName = localizedName; // Localized is already English
            print('✅ ProductDetailsModel: Using localized name as English (not Arabic): "$englishName"');
          } else {
            print('⚠️ ProductDetailsModel: Could not find English name for color ID $colorId, localized: "$localizedName"');
            print('   Available colorIdToEnglishName map: $colorIdToEnglishName');
          }
        }
        
        // Use English name for data/logic, localized name for display
        // CRITICAL: nameForData MUST be English for matching logic
        final displayName = _containsArabic(localizedName) ? localizedName : null;
        
        // Determine the final English name to use
        String finalEnglishName;
        if (englishName.isNotEmpty && !_containsArabic(englishName)) {
          finalEnglishName = englishName;
        } else if (!_containsArabic(localizedName)) {
          // Localized name is already English
          finalEnglishName = localizedName;
        } else {
          // Both are Arabic - try to find English name by matching Arabic name
          if (colorNameToEnglishName.containsKey(localizedName)) {
            finalEnglishName = colorNameToEnglishName[localizedName]!;
            print('✅ ProductDetailsModel: Found English name via Arabic name mapping: "$localizedName" -> "$finalEnglishName"');
          } else {
            // Last resort: use color ID as identifier (better than UNKNOWN_COLOR)
            // The BLoC matching logic should handle ID-based matching as fallback
            finalEnglishName = 'COLOR_ID_$colorId';
            print('⚠️ ProductDetailsModel: CRITICAL - No English name found for color ID $colorId');
            print('   localizedName: "$localizedName", englishName: "$englishName"');
            print('   colorIdToEnglishName map keys: ${colorIdToEnglishName.keys.toList()}');
            print('   colorNameToEnglishName map keys: ${colorNameToEnglishName.keys.toList()}');
            print('   Using color ID as fallback identifier: "$finalEnglishName"');
          }
        }
        
        final nameForData = finalEnglishName;
          
          List<String> imagesForColor = colorToImages[localizedName] ?? 
                                     colorToImages[englishName] ?? 
                                     (templateImage != null ? [templateImage] : parsedImages);
          print('🎨 Color: English="$nameForData", Display="${displayName ?? nameForData}", ID=$colorId');
        
        // If this is the selected color, and selected_variant image exists, prefer that single image
        if (selectedColorName != null && (localizedName == selectedColorName || englishName == selectedColorName)) {
          final selId = selectedVariant != null ? (selectedVariant['id']?.toString() ?? '') : '';
          final selImg = selId.isNotEmpty ? variantIdToImage[selId] : null;
          if (selImg != null && selImg.isNotEmpty) {
            imagesForColor = [selImg];
          }
        }
        
        // Match selected_variant color using normalized comparison (e.g. "BLACK 01" vs "Black")
        final sel = selectedColorName != null ? _norm(selectedColorName) : '';
        final locNorm = _norm(localizedName);
        final engNorm = englishName.isNotEmpty ? _norm(englishName) : '';
        final isSelectedColor = sel.isNotEmpty && (locNorm == sel || engNorm == sel ||
            sel.startsWith(locNorm) || (engNorm.isNotEmpty && sel.startsWith(engNorm)) ||
            locNorm.startsWith(sel) || (engNorm.isNotEmpty && engNorm.startsWith(sel)));
        final colorOption = ColorOptionModel(
          id: colorId,
          name: nameForData, // English name for data/logic
          displayName: displayName, // Arabic name for display (if different)
          code: '#000000',
          images: imagesForColor,
          isSelected: isSelectedColor,
        );
        print('🎨 Final ColorOption: id="${colorOption.id}", name="${colorOption.name}", displayName="${colorOption.displayName}", images=${colorOption.images.length}');
        return colorOption;
      }).toList();
      if (colorOptions.isNotEmpty && colorOptions.every((c) => !c.isSelected)) {
        // Default select first if none matched
        final first = colorOptions.first;
        colorOptions[0] = ColorOptionModel(
          id: first.id,
          name: first.name,
          displayName: first.displayName,
          code: first.code,
          images: first.images,
          isSelected: true,
        );
      }
    } else {
      // Fallback: derive colors from variant combinations' attributes named Color (supports localized synonyms)
      final List<dynamic> vc = _normalizeVariantCombinations(json['variant_combinations']);
      final Set<String> colors = {};
      for (final v in vc) {
        final attrs = (v is Map) ? (v['attributes'] as List<dynamic>? ?? const []) : const [];
        for (final a in attrs) {
          if (a is Map) {
            final n = (a['attribute_name'] ?? '').toString().toLowerCase();
            if (n == 'color' || n == 'colour' || n == 'اللون') {
              final val = (a['value_name'] ?? '').toString();
              if (val.isNotEmpty) colors.add(val);
            }
          }
        }
      }
      if (colors.isNotEmpty) {
        // Build English name map from variant combinations
        final Map<String, String> colorNameToEnglish = {};
        for (final v in variantCombinations) {
          if (v is Map) {
            final attrs = (v['attributes'] as List<dynamic>? ?? const []);
            for (final a in attrs) {
              if (a is Map) {
                final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
                if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
                  final valueName = (a['value_name'] ?? '').toString();
                  if (!_containsArabic(valueName)) {
                    colorNameToEnglish[valueName] = valueName;
                  }
                }
              }
            }
          }
        }
        
        colorOptions = colors.map((localizedName) {
          // Try to find English name
          String englishName = colorNameToEnglish[localizedName] ?? localizedName;
          if (_containsArabic(localizedName) && englishName == localizedName) {
            // Try to find by matching in variant combinations
            for (final vc in variantCombinations) {
              if (vc is Map) {
                final attrs = (vc['attributes'] as List<dynamic>? ?? const []);
                for (final a in attrs) {
                  if (a is Map) {
                    final attrName = (a['attribute_name'] ?? '').toString().toLowerCase();
                    if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
                      final valueName = (a['value_name'] ?? '').toString();
                      if (!_containsArabic(valueName)) {
                        // This might be the English equivalent
                        englishName = valueName;
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
          
          final displayName = _containsArabic(localizedName) ? localizedName : null;
          final nameForData = _containsArabic(localizedName) ? englishName : localizedName;
          
          final sel = selectedColorName != null ? _norm(selectedColorName) : '';
          final locNorm = _norm(localizedName);
          final engNorm = _norm(englishName);
          final isSelectedColor = sel.isNotEmpty && (locNorm == sel || engNorm == sel ||
              sel.startsWith(locNorm) || (engNorm.isNotEmpty && sel.startsWith(engNorm)) ||
              locNorm.startsWith(sel) || (engNorm.isNotEmpty && engNorm.startsWith(sel)));
          return ColorOptionModel(
            id: localizedName,
            name: nameForData,
            displayName: displayName,
            code: '#000000',
            images: colorToImages[localizedName] ?? colorToImages[englishName] ?? (templateImage != null ? [templateImage] : parsedImages),
            isSelected: isSelectedColor,
          );
        }).toList();
        if (colorOptions.isNotEmpty && colorOptions.every((c) => !c.isSelected)) {
          colorOptions[0] = ColorOptionModel(
            id: colorOptions[0].id,
            name: colorOptions[0].name,
            displayName: colorOptions[0].displayName,
            code: colorOptions[0].code,
            images: colorOptions[0].images,
            isSelected: true,
          );
        }
      } else {
        // Last resort default
        if (parsedImages.isNotEmpty) {
          colorOptions = [
            ColorOptionModel(
              id: 'default_color',
              name: 'Default',
              code: '#000000',
              images: parsedImages,
              isSelected: true,
            ),
          ];
        } else {
          colorOptions = [];
        }
      }
    }

    // Create default features based on product info
    final features = <String>[];
    if (json['description'] != null && json['description'].toString().isNotEmpty) {
      features.add(json['description'].toString());
    }
    if (json['short_description'] != null && json['short_description'].toString().isNotEmpty) {
      features.add(json['short_description'].toString());
    }
    // Do not inject demo fallback content; leave features empty when not provided

    print('🔍 ProductDetailsModel: Final colorOptions count: ${colorOptions.length}');
    print('🔍 ProductDetailsModel: Final sizeOptions count: ${sizeOptions.length}');
    
    // Determine selected size from API data
    String selectedSize = '';

    // 1) Prefer selected_variant.attributes → attribute_name contains "SIZE"
    //    Reuse the selectedVariant map declared earlier in this method.
    if (selectedVariant != null) {
      final attrs = (selectedVariant['attributes'] as List<dynamic>?) ?? const [];
      for (final attr in attrs) {
        if (attr is Map) {
          final name = (attr['attribute_name'] ?? '').toString();
          final valueName = (attr['value_name'] ?? '').toString();
          final lower = name.toLowerCase();
          if (lower == 'size' || lower.contains('size') || lower == 'القياس') {
            selectedSize = valueName;
            break;
          }
        }
      }
    }

    // 2) Fallback: use variantAttributeOptions where attributeName is SIZE
    if (selectedSize.isEmpty && variantAttributeOptions.isNotEmpty) {
      for (final opt in variantAttributeOptions) {
        final lower = opt.attributeName.toLowerCase();
        if (lower == 'size' || lower.contains('size') || lower == 'القياس') {
          selectedSize = opt.selectedValue;
          break;
        }
      }
    }

    // Debug: print initial SIZE from model when parsing API response
    print('########### "$selectedSize"');

      // Parse related products
      List<RelatedProduct> _parseRelated(List<dynamic>? arr) {
        if (arr == null) return const [];
        return arr
            .where((e) => e != null && e is Map<String, dynamic>)
            .map((e) {
          final m = e as Map<String, dynamic>;
          final img = (m['image'] as String?) ?? '';
          final imageUrl = img.startsWith('/') ? '${AppConstants.baseUrl}${img.substring(1)}' : img;
          
          // Parse brand - can be string or object with 'name' field
          String brand = '';
          final brandData = m['brand'];
          if (brandData is String && brandData.isNotEmpty) {
            brand = brandData;
          } else if (brandData is Map) {
            brand = (brandData['name'] ?? '').toString();
          }
          
          // Fallback to "Unknown Brand" if brand is empty
          if (brand.isEmpty) {
            brand = 'Unknown Brand';
          }
          
          return RelatedProduct(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            brand: brand,
            price: _parsePrice(m['price']),
            imageUrl: imageUrl,
            type: (m['type'] ?? 'template').toString(),
          );
        }).toList();
      }

      // Determine image list for the main viewer: prefer selected variant's image if available
      List<String> mainImages = parsedImages;
      if (selectedVariant != null) {
        final selId = selectedVariant['id']?.toString();
        final selImg = selId != null ? variantIdToImage[selId] : null;
      if (selImg != null && selImg.isNotEmpty) {
        mainImages = [selImg];
        }
      }

      // Build value_id -> attribute info so we can fill variant_combinations.attributes
      // from attribute_value_ids when the API sends that format (exact variant match by attribute value IDs).
      final valueIdToAttributeInfo = _buildValueIdToAttributeInfo(variantAttributes);

      // Initial values from lite response: price, in_stock, quantity_available.
      // Support both shapes: root-level (type: "variant" response) or nested selected_variant.
      double initialPrice = _parsePrice(json['price']);
      bool initialInStock = (json['in_stock'] ?? true) == true;
      int? initialSelectedVariantQuantityAvailable = _parseQuantityAvailable(json['quantity_available']);

      final selectedVariantMap = json['selected_variant'] as Map<String, dynamic>?;
      if (selectedVariantMap != null) {
        final svPrice = selectedVariantMap['sales_price'] ?? selectedVariantMap['price'];
        if (svPrice != null) initialPrice = _parsePrice(svPrice);
        final svInStock = selectedVariantMap['in_stock'];
        if (svInStock != null) initialInStock = svInStock == true;
        final svQty = _parseQuantityAvailable(selectedVariantMap['quantity_available']);
        if (svQty != null) {
          initialSelectedVariantQuantityAvailable = svQty;
          if (svQty <= 0) initialInStock = false;
        }
      } else {
        // Root-level variant response: "price", "quantity_available", "in_stock" at root
        if (initialSelectedVariantQuantityAvailable != null &&
            initialSelectedVariantQuantityAvailable! <= 0) {
          initialInStock = false;
        }
      }
      print(
        '📦 ProductDetailsModel: Initial from lite response → price=$initialPrice, '
        'inStock=$initialInStock, quantity_available=$initialSelectedVariantQuantityAvailable',
      );

      return ProductDetailsModel(
      id: json['id']?.toString() ?? '',
      brand: _parseBrand(json['brand']),
      name: json['name']?.toString() ?? '',
      description: _parseDescription(json),
      price: initialPrice,
      originalPrice: null,
      rating: 0,
      reviewCount: 0,
      images: mainImages,
      colorOptions: colorOptions.cast<ColorOption>(),
      sizeOptions: const [], // All attributes are now dynamic
      variantAttributeOptions: variantAttributeOptions.cast<VariantAttributeOption>(),
      selectedColor: colorOptions.isNotEmpty
          ? (selectedColorName ?? colorOptions.first.name)
          : '',
      selectedSize: selectedSize,
      isFavorite: json['favourite'] ?? false,
      hasDiscount: false,
      discountPercentage: null,
      features: features,
      material: '',
      materialsList: const [],
      materialOptions: const [],
      selectedMaterial: null,
      careInstructions: '',
      // ignore: unnecessary_cast
      websiteUrl: (json['website_url'] as String?)?.toString(),
      heelHeightCm: null,
      heelType: null,
      heelHeightOptions: const [],
      selectedHeelHeightCm: selectedHeelHeightFromVariant,
      isPlusMember: false,
      pointsEarned: 0,
      optionalProducts: _parseRelated(json['optional_product_ids'] as List<dynamic>?),
      accessoryProducts: _parseRelated(json['accessory_product_ids'] as List<dynamic>?),
      alternativeProducts: _parseRelated(json['alternative_product_ids'] as List<dynamic>?),
      // Map raw variant combinations into entity models.
      // Match exact variant by comparing ALL attribute value IDs: variant_combinations.attributes
      // (or attribute_value_ids) must contain attribute_id + value_id for each selected attribute.
      variantCombinations: _normalizeVariantCombinations(json['variant_combinations'])
          .where((v) => v != null && v is Map<String, dynamic>)
          .map((v) {
        final mv = v as Map<String, dynamic>;
        List<VariantAttribute> attrs;
        final rawAttrs = (mv['attributes'] as List<dynamic>? ?? const []);
        if (rawAttrs.isNotEmpty) {
          attrs = rawAttrs
              .where((a) => a != null && a is Map<String, dynamic>)
              .map((a) {
            final ma = a as Map<String, dynamic>;
            return VariantAttribute(
              attributeName: (ma['attribute_name'] ?? '').toString(),
              valueName: (ma['value_name'] ?? '').toString(),
              attributeId: (ma['attribute_id'] ?? '').toString(),
              valueId: (ma['value_id'] ?? '').toString(),
            );
          }).toList();
        } else {
          // API may send attribute_value_ids (list of value IDs) instead of attributes array.
          // Build attributes from variant_attributes so matching by attribute_id+value_id works.
          attrs = [];
          final valueIds = mv['attribute_value_ids'];
          if (valueIds is List) {
            for (final v in valueIds) {
              final valueId = (v ?? '').toString();
              if (valueId.isEmpty) continue;
              final info = valueIdToAttributeInfo[valueId];
              if (info != null) {
                attrs.add(VariantAttribute(
                  attributeName: info['attributeName'] ?? '',
                  valueName: info['valueName'] ?? '',
                  attributeId: info['attributeId'] ?? '',
                  valueId: valueId,
                ));
              } else {
                attrs.add(VariantAttribute(
                  attributeName: '',
                  valueName: '',
                  attributeId: '',
                  valueId: valueId,
                ));
              }
            }
          }
        }
        // Parse all stock fields from the API response
        final variantId = mv['variant_id'];
        final variantIdStr = variantId is String 
            ? variantId 
            : (variantId is num ? variantId.toString() : '0');
        final quantityAvailable = mv['quantity_available'];
        final quantityAvailableDouble = quantityAvailable is num 
            ? quantityAvailable.toDouble() 
            : (quantityAvailable is String 
                ? double.tryParse(quantityAvailable) ?? 0.0 
                : 0.0);
        // When quantity is 0, treat as out of stock; store 0 so bloc can show "Out of stock" not "Low stock"
        final inStock = (mv['in_stock'] ?? false) as bool && quantityAvailableDouble > 0;
        final bool hasQtyField = quantityAvailable != null;
        final double? quantityAvailableToStore = hasQtyField ? quantityAvailableDouble : null;
        
        // Parse variant price (sales_price or price field)
        final variantPrice = mv['sales_price'] ?? mv['price'];
        final double? priceToStore = variantPrice != null 
            ? (variantPrice is num 
                ? variantPrice.toDouble() 
                : (variantPrice is String 
                    ? double.tryParse(variantPrice) 
                    : null))
            : null;
        
        return VariantCombination(
          variantId: variantIdStr,
          inStock: inStock,
          attributes: attrs,
          quantityAvailable: quantityAvailableToStore,
          price: priceToStore,
        );
      }).toList(),
      primaryVariantLabel: primaryVariantLabel.isNotEmpty ? primaryVariantLabel : 'Size',
      inStock: initialInStock,
      selectedVariantQuantityAvailable: initialSelectedVariantQuantityAvailable,
      // Parse product tags
      tags: (json['product_tag_ids'] as List<dynamic>? ?? const [])
          .where((tag) => tag != null && tag is Map<String, dynamic>)
          .map((tag) {
        final tagMap = tag as Map<String, dynamic>;
        return ProductTag(
          id: (tagMap['id'] ?? '').toString(),
          name: (tagMap['name'] ?? '').toString(),
        );
      }).toList(),
      variantImagesMap: variantImagesMap,
      // Parse attribute_value_combinations for smart enable/disable logic
      // Structure: { value_id: [available_combination_value_ids] }
      attributeValueCombinations: _parseAttributeValueCombinations(json),
    );
    } catch (e) {
      print('❌ ProductDetailsModel: Error parsing API response: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
  }

  /// Parse attribute_value_combinations from API response.
  /// Supports two shapes:
  /// 1) New: value_id -> { name, combinations: [{ variant_id, quantity_available, in_stock, available_combination_values }] }
  ///    Only value_ids with at least one in-stock combination are added (chip active); value = list of compatible value_ids.
  /// 2) Legacy: value_id -> List<id> or value_id -> Map with available_combination_values.
  /// Returns map: value_id -> list of available combination value_ids (for compatibility checks).
  static Map<String, List<String>> _parseAttributeValueCombinations(Map<String, dynamic> json) {
    final Map<String, List<String>> combinations = {};
    
    try {
      final attrValueCombos = json['attribute_value_combinations'] as Map<String, dynamic>?;
      
      if (attrValueCombos == null || attrValueCombos.isEmpty) {
        print('⚠️ ProductDetailsModel: No attribute_value_combinations found in API response');
        return combinations;
      }
      
      print('🔍 ProductDetailsModel: Parsing attribute_value_combinations (${attrValueCombos.length} entries)');
      
      attrValueCombos.forEach((valueId, rawEntry) {
        final valueIdStr = valueId.toString();
        if (rawEntry is List) {
          final valueIds = rawEntry
              .map((v) => v.toString())
              .where((id) => id.isNotEmpty)
              .toList();
          if (valueIds.isNotEmpty) {
            combinations[valueIdStr] = valueIds;
          }
        } else if (rawEntry is Map) {
          final entry = rawEntry as Map<String, dynamic>;
          final combosList = entry['combinations'] as List<dynamic>?;
          if (combosList != null && combosList.isNotEmpty) {
            // New structure: only add value_id if at least one combination is in-stock
            final inStockCombos = combosList.where((c) {
              if (c is! Map) return false;
              final inStock = (c['in_stock'] ?? false) as bool;
              final qty = c['quantity_available'];
              final qtyNum = qty is num ? qty.toDouble() : (qty != null ? double.tryParse(qty.toString()) ?? 0 : 0.0);
              return inStock && (qty == null || qtyNum > 0);
            }).toList();
            if (inStockCombos.isEmpty) return; // no in-stock → do not add (chip disabled)
            final Set<String> allIds = {};
            for (final c in inStockCombos) {
              if (c is! Map) continue;
              final av = (c['available_combination_values'] as List<dynamic>?) ?? [];
              for (final item in av) {
                if (item is Map) {
                  final id = (item['id'] ?? '').toString();
                  if (id.isNotEmpty) allIds.add(id);
                }
              }
            }
            combinations[valueIdStr] = allIds.toList();
          } else {
            // Legacy nested map (e.g. single object with available_combination_values)
            final valueIds = <String>[];
            for (final item in (entry['available_combination_values'] as List<dynamic>? ?? [])) {
              if (item is Map) {
                final id = (item['id'] ?? '').toString();
                if (id.isNotEmpty) valueIds.add(id);
              } else {
                final id = item.toString();
                if (id.isNotEmpty) valueIds.add(id);
              }
            }
            if (valueIds.isNotEmpty) {
              combinations[valueIdStr] = valueIds;
            }
          }
        }
      });
      
      print('✅ ProductDetailsModel: Parsed ${combinations.length} attribute_value_combinations (value_ids with in-stock combos)');
    } catch (e) {
      print('❌ ProductDetailsModel: Error parsing attribute_value_combinations: $e');
    }
    
    return combinations;
  }

  // Helper methods for safe parsing
  static String _parseBrand(dynamic brand) {
    if (brand == null) return 'Unknown Brand';
    if (brand is String) return brand;
    if (brand is Map) return brand['name']?.toString() ?? 'Unknown Brand';
    return brand.toString();
  }

  static String _parseDescription(Map<String, dynamic> json) {
    final description = json['description'];
    final shortDescription = json['short_description'];
    
    if (description != null && description.toString().isNotEmpty) {
      return description.toString();
    }
    if (shortDescription != null && shortDescription.toString().isNotEmpty) {
      return shortDescription.toString();
    }
    return '';
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  /// Parses quantity_available from API (e.g. 2.0, "2", 2) to int? for initial display.
  static int? _parseQuantityAvailable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Builds value_id -> { attributeId, attributeName, valueName } from variant_attributes.
  /// Used to fill variant_combinations.attributes from attribute_value_ids when the API
  /// sends that format (list of value IDs) instead of full attributes array.
  static Map<String, Map<String, String>> _buildValueIdToAttributeInfo(List<dynamic> variantAttributes) {
    final map = <String, Map<String, String>>{};
    for (final attr in variantAttributes) {
      if (attr is! Map<String, dynamic>) continue;
      final attrId = (attr['id'] ?? '').toString();
      final attrName = (attr['name'] ?? '').toString();
      for (final val in (attr['values'] as List<dynamic>? ?? [])) {
        if (val is! Map<String, dynamic>) continue;
        final valueId = (val['id'] ?? '').toString();
        final valueName = (val['name'] ?? '').toString();
        if (valueId.isNotEmpty) {
          map[valueId] = {
            'attributeId': attrId,
            'attributeName': attrName,
            'valueName': valueName,
          };
        }
      }
    }
    return map;
  }

  /// Normalize backend variant_combinations payload into a List that the
  /// existing variant/stock/price logic can consume.
  ///
  /// Supports both the old list shape:
  ///   "variant_combinations": [ { ... }, { ... } ]
  /// and the new map shape:
  ///   "variant_combinations": { "2863": { ... }, "2864": { ... } }
  static List<dynamic> _normalizeVariantCombinations(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw;
    if (raw is Map) {
      try {
        return raw.values.toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  /// Check if a string contains Arabic characters
  static bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    // Arabic Unicode range: U+0600 to U+06FF
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  /// Normalize string for selected_variant matching (case-insensitive, trim).
  /// E.g. "BLACK 01" from API matches "Black" in variant_attributes.
  static String _norm(String s) => s.trim().toLowerCase();

  /// True if the attribute is a color (COLOR NAME, color, etc.).
  static bool _isColorAttributeName(String name) {
    final n = name.toLowerCase().trim();
    return n == 'color' || n == 'colour' || n == 'اللون' || n == 'color name';
  }

  static List<String> _parseImages(dynamic images, {String? productType, String? productId}) {
    if (images == null) return [];
    if (images is List) {
      // Helper function to normalize variant_id for comparison
      // Handles both string and int types from API
      String normalizeVariantId(dynamic variantId) {
        if (variantId == null) return '';
        if (variantId is int) return variantId.toString();
        if (variantId is String) return variantId.trim();
        return variantId.toString().trim();
      }

      // Normalize productId for comparison
      final normalizedProductId = productId != null ? productId.trim() : '';

      // For variant products, we need to collect images with proper ordering
      // Structure: {variant_id: [{url, type, sequence}, ...]}
      final Map<String, List<Map<String, dynamic>>> variantImagesMap = {};
      final seen = <String>{};
      final filteredImages = <String>[];

      // First pass: collect all images and group by variant_id
      for (final e in images) {
        if (e is Map) {
          final url = e['url']?.toString() ?? '';
          final image = e['image']?.toString() ?? '';
          final type = e['type']?.toString() ?? '';
          
          // Handle variant_id - can be int or string
          final variantIdRaw = e['variant_id'];
          final variantId = normalizeVariantId(variantIdRaw);
          
          // Use the 'image' field if available (new API format), otherwise use 'url'
          final imageUrl = image.isNotEmpty ? image : url;
          
          if (imageUrl.isNotEmpty) {
            // Use normalizeImageUrl to fix double slashes
            String fullImageUrl = ImageCacheUtils.normalizeImageUrl(imageUrl);
            
            // Filter images based on product type
            if (productType == 'template') {
              // For template products, only show template and template_gallery images
              if (type == 'template' || type == 'template_gallery') {
                if (!seen.contains(fullImageUrl)) {
                  seen.add(fullImageUrl);
                  filteredImages.add(fullImageUrl);
                  print('🖼️ Added template image (type: $type): $fullImageUrl');
                }
              }
            } else if (productType == 'variant') {
              // For variant products, group images by variant_id
              // Include both 'variant' and 'variant_gallery' types
              if (variantId.isNotEmpty && (type == 'variant' || type == 'variant_gallery')) {
                variantImagesMap.putIfAbsent(variantId, () => <Map<String, dynamic>>[]);
                
                // Store image info with sequence for proper sorting
                final sequence = e['sequence'];
                final sequenceValue = sequence is int 
                    ? sequence 
                    : (sequence is String ? int.tryParse(sequence) ?? 0 : 0);
                
                variantImagesMap[variantId]!.add({
                  'url': fullImageUrl,
                  'type': type,
                  'sequence': sequenceValue,
                });
              } else if (variantId.isEmpty && productType == 'variant') {
                // Skip images without variant_id for variant products
                print('⚠️ Skipping image with empty variant_id for variant product: $fullImageUrl');
              }
            } else {
              // Fallback: show all images (existing behavior)
              if (!seen.contains(fullImageUrl)) {
                seen.add(fullImageUrl);
                filteredImages.add(fullImageUrl);
              }
            }
          }
        }
      }

      // Second pass: for variant products, flatten ALL variant_id groups
      // instead of filtering by the single productId. Grouping by variant_id
      // itself is preserved in `variantImagesMap` and used later via
      // ProductDetails.variantImagesMap + variantCombinations.variantId.
      if (productType == 'variant') {
        for (final entry in variantImagesMap.entries) {
          final String vid = entry.key;
          final List<Map<String, dynamic>> currentVariantImages = entry.value;

          if (currentVariantImages.isEmpty) continue;

          // Sort images within this variant: main variant image first,
          // then gallery images by sequence.
          currentVariantImages.sort((a, b) {
            final aType = a['type'] as String;
            final bType = b['type'] as String;

            if (aType == 'variant' && bType != 'variant') return -1;
            if (aType != 'variant' && bType == 'variant') return 1;

            if (aType == 'variant_gallery' && bType == 'variant_gallery') {
              final aSeq = a['sequence'] as int;
              final bSeq = b['sequence'] as int;
              return aSeq.compareTo(bSeq);
            }

            return 0;
          });

          for (final imgData in currentVariantImages) {
            final imgUrl = imgData['url'] as String;
            if (!seen.contains(imgUrl)) {
              seen.add(imgUrl);
              filteredImages.add(imgUrl);
              print(
                  '🖼️ Added variant image (variant_id: $vid, type: ${imgData['type']}, sequence: ${imgData['sequence']}): $imgUrl');
            }
          }
        }
      }

      // Log grouped images for debugging
      if (productType == 'variant' && variantImagesMap.isNotEmpty) {
        print('📊 Images grouped by variant_id:');
        variantImagesMap.forEach((vid, imgList) {
          print('   variant_id: $vid → ${imgList.length} image(s)');
          for (final img in imgList) {
            print('      - type: ${img['type']}, sequence: ${img['sequence']}, url: ${(img['url'] as String).substring(0, (img['url'] as String).length > 50 ? 50 : (img['url'] as String).length)}...');
          }
        });
        print('🎯 Current productId: $normalizedProductId');
        print('✅ Total images for current variant: ${filteredImages.length}');
      }

      return filteredImages;
    }
    return [];
  }

  /// Build a map of variant_id -> list of image URLs for all variants
  static Map<String, List<String>> _buildVariantImagesMap(dynamic images, {String? productType}) {
    final Map<String, List<String>> variantImagesMap = {};
    
    if (images == null || images is! List) return variantImagesMap;
    if (productType != 'variant') return variantImagesMap;

    // Helper function to normalize variant_id for comparison
    String normalizeVariantId(dynamic variantId) {
      if (variantId == null) return '';
      if (variantId is int) return variantId.toString();
      if (variantId is String) return variantId.trim();
      return variantId.toString().trim();
    }

    // Group images by variant_id
    final Map<String, List<Map<String, dynamic>>> tempMap = {};

    for (final e in images) {
      if (e is Map) {
        final url = e['url']?.toString() ?? '';
        final image = e['image']?.toString() ?? '';
        final type = e['type']?.toString() ?? '';
        
        // Handle variant_id - can be int or string
        final variantIdRaw = e['variant_id'];
        final variantId = normalizeVariantId(variantIdRaw);
        
        // Use the 'image' field if available (new API format), otherwise use 'url'
        final imageUrl = image.isNotEmpty ? image : url;
        
        // Group ALL variant-bound images:
        // - type == 'variant'          → main image for that variant
        // - type == 'variant_gallery'  → extra gallery images for that variant
        // - type == 'template_gallery' → gallery images attached to a specific variant_id
        if (imageUrl.isNotEmpty &&
            variantId.isNotEmpty &&
            (type == 'variant' || type == 'variant_gallery' || type == 'template_gallery')) {
          // Use normalizeImageUrl to fix double slashes
          String fullImageUrl = ImageCacheUtils.normalizeImageUrl(imageUrl);
          
          tempMap.putIfAbsent(variantId, () => <Map<String, dynamic>>[]);
          
          // Store image info with sequence for proper sorting
          final sequence = e['sequence'];
          final sequenceValue = sequence is int 
              ? sequence 
              : (sequence is String ? int.tryParse(sequence) ?? 0 : 0);
          
          tempMap[variantId]!.add({
            'url': fullImageUrl,
            'type': type,
            'sequence': sequenceValue,
          });
        }
      }
    }

    // Sort and convert to final map format
    tempMap.forEach((variantId, imageList) {
      // Sort images: main variant image first, then gallery images by sequence
      imageList.sort((a, b) {
        final aType = a['type'] as String;
        final bType = b['type'] as String;
        
        // Main variant image comes first
        if (aType == 'variant' && bType != 'variant') return -1;
        if (aType != 'variant' && bType == 'variant') return 1;
        
        // If both are gallery images, sort by sequence
        if (aType == 'variant_gallery' && bType == 'variant_gallery') {
          final aSeq = a['sequence'] as int;
          final bSeq = b['sequence'] as int;
          return aSeq.compareTo(bSeq);
        }
        
        return 0;
      });
      
      // Extract URLs in sorted order
      variantImagesMap[variantId] = imageList.map((img) => img['url'] as String).toList();
    });

    print('📊 Built variantImagesMap with ${variantImagesMap.length} variants');
    variantImagesMap.forEach((vid, imgList) {
      print('   variant_id: $vid → ${imgList.length} image(s)');
    });

    return variantImagesMap;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'images': images,
      'colorOptions': colorOptions.map((e) => (e as ColorOptionModel).toJson()).toList(),
      'sizeOptions': sizeOptions.map((e) => (e as SizeOptionModel).toJson()).toList(),
      'selectedColor': selectedColor,
      'selectedSize': selectedSize,
      'isFavorite': isFavorite,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'features': features,
      'material': material,
      'materialsList': materialsList,
      'materialOptions': materialOptions,
      'selectedMaterial': selectedMaterial,
      'careInstructions': careInstructions,
      'website_url': websiteUrl,
      'heelHeightCm': heelHeightCm,
      'heelType': heelType,
      'heelHeightOptions': heelHeightOptions,
      'selectedHeelHeightCm': selectedHeelHeightCm,
      'isPlusMember': isPlusMember,
      'pointsEarned': pointsEarned,
    };
  }
}

class ColorOptionModel extends ColorOption {
  const ColorOptionModel({
    required super.id,
    required super.name,
    super.displayName,
    required super.code,
    required super.images,
    required super.isSelected,
  });

  factory ColorOptionModel.fromJson(Map<String, dynamic> json) {
    return ColorOptionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] as String?,
      code: json['code'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (displayName != null) 'displayName': displayName,
      'code': code,
      'images': images,
      'isSelected': isSelected,
    };
  }
}

class SizeOptionModel extends SizeOption {
  const SizeOptionModel({
    required super.id,
    required super.name,
    required super.isAvailable,
    required super.isRecommended,
    required super.isSelected,
  });

  factory SizeOptionModel.fromJson(Map<String, dynamic> json) {
    return SizeOptionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      isRecommended: json['isRecommended'] ?? false,
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isAvailable': isAvailable,
      'isRecommended': isRecommended,
      'isSelected': isSelected,
    };
  }
}

class VariantAttributeOptionModel extends VariantAttributeOption {
  const VariantAttributeOptionModel({
    required super.attributeName,
    required super.values,
    required super.selectedValue,
    super.apiAttributeName,
    super.attributeId,
  });

  factory VariantAttributeOptionModel.fromJson(Map<String, dynamic> json) {
    return VariantAttributeOptionModel(
      attributeName: json['attributeName'] ?? '',
      values: (json['values'] as List<dynamic>?)
          ?.map((e) => VariantAttributeValueModel.fromJson(e))
          .toList() ?? [],
      selectedValue: json['selectedValue'] ?? '',
      apiAttributeName: json['apiAttributeName'] as String?,
      attributeId: json['attributeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attributeName': attributeName,
      'values': values.map((e) => (e as VariantAttributeValueModel).toJson()).toList(),
      'selectedValue': selectedValue,
      if (apiAttributeName != null) 'apiAttributeName': apiAttributeName,
      if (attributeId != null) 'attributeId': attributeId,
    };
  }
}

class VariantAttributeValueModel extends VariantAttributeValue {
  const VariantAttributeValueModel({
    required super.id,
    required super.name,
    required super.isAvailable,
    required super.isSelected,
  });

  factory VariantAttributeValueModel.fromJson(Map<String, dynamic> json) {
    return VariantAttributeValueModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isAvailable': isAvailable,
      'isSelected': isSelected,
    };
  }
}
