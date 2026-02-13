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
    super.attributeVariantCombinations = const [],
    super.attributeValueCombinationsByKey = const {},
    super.primaryVariantLabel = 'Size',
    super.inStock = true,
    super.selectedVariantQuantityAvailable,
    super.tags = const [],
    super.variantImagesMap = const {},
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
      final variantCombinations = json['variant_combinations'] as List<dynamic>? ?? [];
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
      
      if (variantCombinations.isNotEmpty && variantAttributes.isNotEmpty) {
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
              
              // Check availability
              bool isAvailable = false;
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
              
              final String? colorDisplayName = 
                  (localizedName != englishName && localizedName.isNotEmpty && 
                   (_containsArabic(localizedName) || !_containsArabic(englishName)))
                  ? localizedName
                  : null;
              colorValues.add(VariantAttributeValueModel(
                id: valueId,
                name: englishName, // English name for matching/logic
                displayName: colorDisplayName, // Localized name for display
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
                  displayName: firstAvailable.displayName,
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
          
          // Process non-color attributes - ensure English names for matching
          // CRITICAL: Always use English names from variant combinations for internal logic
          // Display names can be Arabic, but matching must use English
          
          final attrValues = (attr['values'] as List<dynamic>? ?? []);
          final List<VariantAttributeValueModel> values = [];
          
          // Build a map of value ID to English name from variant combinations
          final Map<String, String> valueIdToEnglishName = {};
          for (final variant in variantCombinations) {
            final attrs = (variant['attributes'] as List<dynamic>? ?? const []);
            for (final a in attrs) {
              if (a is Map) {
                final variantAttrName = (a['attribute_name'] ?? '').toString();
                final variantValueId = (a['value_id'] ?? '').toString();
                final variantValueName = (a['value_name'] ?? '').toString();
                
                // Match by attribute name (case-insensitive, handle Arabic)
                final attrNameLower = attrName.toLowerCase();
                final variantAttrNameLower = variantAttrName.toLowerCase();
                final isMatchingAttribute = variantAttrNameLower == attrNameLower ||
                                          variantAttrNameLower.contains(attrNameLower) ||
                                          attrNameLower.contains(variantAttrNameLower);
                
                if (isMatchingAttribute && !_containsArabic(variantValueName)) {
                  // Found English name in variant combination - use it
                  valueIdToEnglishName[variantValueId] = variantValueName;
                }
              }
            }
          }
          
          // For each value, check availability and use English name
          for (final value in attrValues) {
            final valueId = (value['id'] ?? '').toString();
            final localizedName = (value['name'] ?? '').toString();
            
            // Get English name from our map, or use localized name if not Arabic
            String englishName = valueIdToEnglishName[valueId] ?? localizedName;
            
            // If we don't have English name yet and localized name is Arabic, try to find it
            if (_containsArabic(localizedName) && (englishName == localizedName || _containsArabic(englishName))) {
              // Try to find English name by matching ID across all variant combinations
              for (final variant in variantCombinations) {
                final attrs = (variant['attributes'] as List<dynamic>? ?? const []);
                for (final a in attrs) {
                  if (a is Map) {
                    final variantAttrName = (a['attribute_name'] ?? '').toString();
                    final variantValueId = (a['value_id'] ?? '').toString();
                    final variantValueName = (a['value_name'] ?? '').toString();
                    
                    final attrNameLower = attrName.toLowerCase();
                    final variantAttrNameLower = variantAttrName.toLowerCase();
                    final isMatchingAttribute = variantAttrNameLower == attrNameLower ||
                                              variantAttrNameLower.contains(attrNameLower) ||
                                              attrNameLower.contains(variantAttrNameLower);
                    
                    if (isMatchingAttribute && variantValueId == valueId && !_containsArabic(variantValueName)) {
                      englishName = variantValueName;
                      valueIdToEnglishName[valueId] = variantValueName;
                      break;
                    }
                  }
                }
                if (englishName != localizedName && !_containsArabic(englishName)) break;
              }
            }
            
            // If still no English name found, use localized name (fallback)
            if (englishName.isEmpty || (_containsArabic(localizedName) && _containsArabic(englishName))) {
              englishName = localizedName; // Last resort
            }
            
            // Check if this value is available in any variant using English name for matching
            bool isAvailable = false;
            for (final variant in variantCombinations) {
              final attrs = (variant['attributes'] as List<dynamic>? ?? const []);
              for (final a in attrs) {
                if (a is Map) {
                  final variantAttrName = (a['attribute_name'] ?? '').toString();
                  final variantValueName = (a['value_name'] ?? '').toString();
                  
                  // Match by attribute name (flexible)
                  final attrNameLower = attrName.toLowerCase();
                  final variantAttrNameLower = variantAttrName.toLowerCase();
                  final isMatchingAttribute = variantAttrNameLower == attrNameLower ||
                                            variantAttrNameLower.contains(attrNameLower) ||
                                            attrNameLower.contains(variantAttrNameLower);
                  
                  // Match by value name (use English name) or by ID
                  final variantValueId = (a['value_id'] ?? '').toString();
                  final valueMatch = variantValueName == englishName ||
                                   variantValueName.toLowerCase() == englishName.toLowerCase() ||
                                   (variantValueId == valueId && !_containsArabic(variantValueName));
                  
                  if (isMatchingAttribute && valueMatch) {
                    isAvailable = (variant['in_stock'] ?? false) as bool;
                    break;
                  }
                }
              }
              if (isAvailable) break;
            }
            
            // Store English name for matching, localized name for display (like ColorOption)
            final String? displayNameForValue = 
                (localizedName != englishName && localizedName.isNotEmpty && 
                 (_containsArabic(localizedName) || !_containsArabic(englishName)))
                ? localizedName
                : null;
            values.add(VariantAttributeValueModel(
              id: valueId,
              name: englishName, // English name for matching/logic
              displayName: displayNameForValue, // Localized name for display (Arabic when locale is Arabic)
              isAvailable: isAvailable,
              isSelected: false,
            ));
          }
          
          // Select the first value by default (initial stage shows first of each attribute)
          String selectedValue = '';
          if (values.isNotEmpty) {
            final firstValue = values.first;
            selectedValue = firstValue.name;
            // Mark as selected
            values[0] = VariantAttributeValueModel(
              id: firstValue.id,
              name: firstValue.name,
              displayName: firstValue.displayName,
              isAvailable: firstValue.isAvailable,
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

    // Always use first value of each attribute on initial load (already set above).
    // Capture heel height from the first HEIGHT value when present.
    double? selectedHeelHeightFromVariant;
    for (final opt in variantAttributeOptions) {
      if (opt.values.isEmpty) continue;
      final attrLower = opt.attributeName.toLowerCase();
      if (attrLower == 'height' || attrLower == 'heel height') {
        final firstVal = opt.values.first;
        final numeric = double.tryParse(
          firstVal.name.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (numeric != null) selectedHeelHeightFromVariant = numeric;
        break;
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
    for (final v in (json['variant_combinations'] as List<dynamic>? ?? const [])) {
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
    // Use first color on initial load (no selected_variant override)
    final variantAttrs = (json['variant_attributes'] as List<dynamic>?) ?? const [];
    final selectedVariant = json['selected_variant'] as Map<String, dynamic>?;
    String? selectedColorName; // Left null so first color is used
    Map<String, dynamic>? colorAttr;
    for (final a in variantAttrs) {
      if (a is Map) {
        final n = (a['name'] ?? '').toString().toLowerCase();
        if (n == 'color' || n == 'colour' || n == 'اللون' || n == 'color name') {
          colorAttr = a.cast<String, dynamic>();
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
        
        final colorOption = ColorOptionModel(
          id: colorId,
          name: nameForData, // English name for data/logic
          displayName: displayName, // Arabic name for display (if different)
          code: '#000000',
          images: imagesForColor,
          isSelected: selectedColorName != null ? (localizedName == selectedColorName || englishName == selectedColorName) : false,
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
      final List<dynamic> vc = json['variant_combinations'] as List<dynamic>? ?? const [];
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
          
          return ColorOptionModel(
            id: localizedName,
            name: nameForData,
            displayName: displayName,
            code: '#000000',
            images: colorToImages[localizedName] ?? colorToImages[englishName] ?? (templateImage != null ? [templateImage] : parsedImages),
            isSelected: selectedColorName != null ? (localizedName == selectedColorName || englishName == selectedColorName) : false,
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
        return arr.map((e) {
          final m = e as Map<String, dynamic>;
          final img = (m['image'] as String?) ?? '';
          final imageUrl = img.startsWith('/') ? '${AppConstants.baseUrl}${img.substring(1)}' : img;
          return RelatedProduct(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
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

      // Build normalized attributeVariantCombinations and attributeValueCombinationsByKey.
      final List<AttributeVariantCombination> attributeVariantCombinations = [];
      final Map<String, List<AttributeVariantCombination>> attributeValueCombinationsByKey = {};
      final rawAttrValueCombos = json['attribute_value_combinations'];
      AttributeVariantCombination? parseCombo(Map<String, dynamic> combo) {
        final variantIdRaw = combo['variant_id'];
        if (variantIdRaw == null) return null;
        final int variantId = variantIdRaw is int
            ? variantIdRaw
            : int.tryParse(variantIdRaw.toString()) ?? -1;
        if (variantId <= 0) return null;
        final quantityRaw = combo['quantity_available'];
        final double quantityAvailable = quantityRaw is num
            ? quantityRaw.toDouble()
            : (quantityRaw is String
                ? double.tryParse(quantityRaw) ?? 0.0
                : 0.0);
        final bool inStock = combo['in_stock'] == true;
        final List<dynamic> av =
            combo['available_combination_values'] as List<dynamic>? ?? const [];
        final values = <AttributeCombinationValue>[];
        for (final vRaw in av) {
          if (vRaw is! Map<String, dynamic>) continue;
          final idRaw = vRaw['id'];
          if (idRaw == null) continue;
          final int id = idRaw is int
              ? idRaw
              : int.tryParse(idRaw.toString()) ?? -1;
          if (id <= 0) continue;
          values.add(AttributeCombinationValue(
            id: id,
            value: (vRaw['value'] ?? '').toString(),
          ));
        }
        return AttributeVariantCombination(
          variantId: variantId,
          quantityAvailable: quantityAvailable,
          inStock: inStock,
          values: values,
        );
      }
      List<dynamic> extractCombosList(dynamic raw) {
        if (raw is List) return raw;
        if (raw is Map<String, dynamic>) {
          final direct = raw['combinations'] as List<dynamic>?;
          if (direct != null) return direct;
          final List<dynamic> acc = [];
          raw.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final list = value['combinations'] as List<dynamic>? ?? const [];
              acc.addAll(list);
            }
          });
          return acc;
        }
        return const [];
      }
      // Build byKey from top-level structure: key (value name) -> list of combos
      if (rawAttrValueCombos is Map<String, dynamic>) {
        rawAttrValueCombos.forEach((key, value) {
          if (value is! Map<String, dynamic>) return;
          final list = value['combinations'] as List<dynamic>? ?? const [];
          final combos = <AttributeVariantCombination>[];
          final variantMap = <int, AttributeVariantCombination>{};
          for (final comboRaw in list) {
            if (comboRaw is! Map<String, dynamic>) continue;
            final c = parseCombo(comboRaw);
            if (c != null) {
              variantMap.putIfAbsent(c.variantId, () => c);
            }
          }
          combos.addAll(variantMap.values);
          if (combos.isNotEmpty) {
            attributeValueCombinationsByKey[key] = combos;
          }
        });
      }
      final combosList = extractCombosList(rawAttrValueCombos);
      if (combosList.isNotEmpty) {
        final Map<int, AttributeVariantCombination> variantMap = {};
        for (final comboRaw in combosList) {
          if (comboRaw is! Map<String, dynamic>) continue;
          final c = parseCombo(comboRaw);
          if (c != null) variantMap.putIfAbsent(c.variantId, () => c);
        }
        attributeVariantCombinations.addAll(variantMap.values);
      }

      return ProductDetailsModel(
      id: json['id']?.toString() ?? '',
      brand: _parseBrand(json['brand']),
      name: json['name']?.toString() ?? '',
      description: _parseDescription(json),
      price: _parsePrice(json['price']),
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
      // Map raw variant combinations into entity models
      // Note: ProductDetails uses its own VariantCombination class (simpler version)
      variantCombinations: (json['variant_combinations'] as List<dynamic>? ?? const []).map((v) {
        final mv = v as Map<String, dynamic>;
        final attrs = (mv['attributes'] as List<dynamic>? ?? const []).map((a) {
          final ma = a as Map<String, dynamic>;
          return VariantAttribute(
            attributeName: (ma['attribute_name'] ?? '').toString(),
            valueName: (ma['value_name'] ?? '').toString(),
            attributeId: (ma['attribute_id'] ?? '').toString(),
            valueId: (ma['value_id'] ?? '').toString(),
          );
        }).toList();
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
        
        return VariantCombination(
          variantId: variantIdStr,
          inStock: inStock,
          attributes: attrs,
          quantityAvailable: quantityAvailableToStore,
        );
      }).toList(),
      attributeVariantCombinations: attributeVariantCombinations,
      attributeValueCombinationsByKey: attributeValueCombinationsByKey,
      primaryVariantLabel: primaryVariantLabel.isNotEmpty ? primaryVariantLabel : 'Size',
      inStock: _initialInStockFromAttributeCombos(
        attributeVariantCombinations,
        variantAttributeOptions,
        selectedVariant,
        variantCombinations,
        json,
      ),
      selectedVariantQuantityAvailable: _initialQuantityFromAttributeCombos(
        attributeVariantCombinations,
        variantAttributeOptions,
        selectedVariant,
        variantCombinations,
        json,
      ),
      // Parse product tags
      tags: (json['product_tag_ids'] as List<dynamic>? ?? const []).map((tag) {
        final tagMap = tag as Map<String, dynamic>;
        return ProductTag(
          id: (tagMap['id'] ?? '').toString(),
          name: (tagMap['name'] ?? '').toString(),
        );
      }).toList(),
      variantImagesMap: variantImagesMap,
    );
    } catch (e) {
      print('❌ ProductDetailsModel: Error parsing API response: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
  }

  /// Prefer selected_variant, else data block (json), else first variant_combinations.
  static Map<String, dynamic>? _initialStockSource(
    Map<String, dynamic>? selectedVariant,
    List<dynamic> variantCombinations,
    Map<String, dynamic> json,
  ) {
    if (selectedVariant != null) return selectedVariant;
    if (json['in_stock'] != null || json['quantity_available'] != null) return json;
    if (variantCombinations.isNotEmpty && variantCombinations.first is Map) {
      return variantCombinations.first as Map<String, dynamic>;
    }
    return null;
  }

  /// Builds initial selection map (attr slug -> value id) from first/selected value per attribute.
  /// Same logic as entity's getSelectedAttributeSlugToValueId for initial load (e.g. first color id).
  static Map<String, int> _initialSelectionByAttrSlugAndValueId(
    List<VariantAttributeOption> variantAttributeOptions,
  ) {
    final map = <String, int>{};
    String toValueKey(String value) =>
        value.trim().toLowerCase().replaceAll(' ', '-');
    for (final opt in variantAttributeOptions) {
      if (opt.values.isEmpty) continue;
      VariantAttributeValue? selectedVal;
      if (opt.selectedValue.isEmpty) {
        selectedVal = opt.values.first;
      } else {
        for (final v in opt.values) {
          if (toValueKey(v.name) == toValueKey(opt.selectedValue) ||
              (v.displayName != null &&
                  v.displayName!.isNotEmpty &&
                  toValueKey(v.displayName!) == toValueKey(opt.selectedValue))) {
            selectedVal = v;
            break;
          }
        }
        selectedVal ??= opt.values.first;
      }
      final idInt = int.tryParse(selectedVal.id.toString());
      if (idInt != null) {
        map[ProductDetails.attributeNameToComboSlug(opt.attributeName)] = idInt;
      }
    }
    return map;
  }

  /// Initial in_stock from attribute_value_combinations (same loop as attribute click) when possible.
  static bool _initialInStockFromAttributeCombos(
    List<AttributeVariantCombination> attributeVariantCombinations,
    List<VariantAttributeOption> variantAttributeOptions,
    Map<String, dynamic>? selectedVariant,
    List<dynamic> variantCombinations,
    Map<String, dynamic> json,
  ) {
    if (attributeVariantCombinations.isEmpty || variantAttributeOptions.isEmpty) {
      return _initialInStock(
          _initialStockSource(selectedVariant, variantCombinations, json));
    }
    final selection =
        _initialSelectionByAttrSlugAndValueId(variantAttributeOptions);
    if (selection.isEmpty) {
      return _initialInStock(
          _initialStockSource(selectedVariant, variantCombinations, json));
    }
    final matched = ProductDetails.findMatchingComboByValueIds(
        attributeVariantCombinations, selection);
    if (matched != null) {
      return matched.inStock && matched.quantityAvailable > 0;
    }
    return _initialInStock(
        _initialStockSource(selectedVariant, variantCombinations, json));
  }

  /// Initial quantity_available from attribute_value_combinations (same loop as attribute click).
  static int? _initialQuantityFromAttributeCombos(
    List<AttributeVariantCombination> attributeVariantCombinations,
    List<VariantAttributeOption> variantAttributeOptions,
    Map<String, dynamic>? selectedVariant,
    List<dynamic> variantCombinations,
    Map<String, dynamic> json,
  ) {
    if (attributeVariantCombinations.isEmpty || variantAttributeOptions.isEmpty) {
      return _initialQuantityAvailable(
          _initialStockSource(selectedVariant, variantCombinations, json));
    }
    final selection =
        _initialSelectionByAttrSlugAndValueId(variantAttributeOptions);
    if (selection.isEmpty) {
      return _initialQuantityAvailable(
          _initialStockSource(selectedVariant, variantCombinations, json));
    }
    final matched = ProductDetails.findMatchingComboByValueIds(
        attributeVariantCombinations, selection);
    if (matched != null) {
      return matched.quantityAvailable.toInt();
    }
    return _initialQuantityAvailable(
        _initialStockSource(selectedVariant, variantCombinations, json));
  }

  /// Initial stock from selected/first variant: in_stock && quantity_available > 0.
  static bool _initialInStock(Map<String, dynamic>? variant) {
    if (variant == null) return true;
    final inStock = variant['in_stock'] == true;
    final qtyRaw = variant['quantity_available'];
    final qty = qtyRaw is num
        ? qtyRaw.toDouble()
        : (qtyRaw is String ? double.tryParse(qtyRaw) ?? 0.0 : 0.0);
    return inStock && qty > 0;
  }

  /// Initial quantity available from selected/first variant.
  static int? _initialQuantityAvailable(Map<String, dynamic>? variant) {
    if (variant == null) return null;
    final qtyRaw = variant['quantity_available'];
    if (qtyRaw == null) return null;
    final qty = qtyRaw is num
        ? qtyRaw.toDouble()
        : (qtyRaw is String ? double.tryParse(qtyRaw) : null);
    return qty != null ? qty.toInt() : null;
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

  /// Check if a string contains Arabic characters
  static bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    // Arabic Unicode range: U+0600 to U+06FF
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
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
    super.displayName,
    required super.isAvailable,
    required super.isSelected,
  });

  factory VariantAttributeValueModel.fromJson(Map<String, dynamic> json) {
    return VariantAttributeValueModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] as String?,
      isAvailable: json['isAvailable'] ?? false,
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (displayName != null) 'displayName': displayName,
      'isAvailable': isAvailable,
      'isSelected': isSelected,
    };
  }
}
