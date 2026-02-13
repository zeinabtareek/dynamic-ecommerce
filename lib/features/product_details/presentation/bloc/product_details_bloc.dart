import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/product_details.dart';
import '../../domain/usecases/get_product_details.dart';
import '../../domain/usecases/toggle_favorite.dart';
import '../../domain/usecases/select_color.dart';
import '../../domain/usecases/select_size.dart';
import '../../domain/usecases/add_to_cart.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../../core/services/app_localization_service.dart';

part 'product_details_event.dart';
part 'product_details_state.dart';

class ProductDetailsBloc extends Bloc<ProductDetailsEvent, ProductDetailsState> {
  final GetProductDetails getProductDetails;
  final ToggleFavorite toggleFavorite;
  final SelectColor selectColor;
  final SelectSize selectSize;
  final AddToCart addToCart;
  final CartBloc cartBloc;

  ProductDetailsBloc({
    required this.getProductDetails,
    required this.toggleFavorite,
    required this.selectColor,
    required this.selectSize,
    required this.addToCart,
    required this.cartBloc,
  }) : super(ProductDetailsInitial()) {
    debugPrint('🏗️ ProductDetailsBloc constructed with CartBloc: ${cartBloc.runtimeType}');
    on<LoadProductDetails>(_onLoadProductDetails);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<SelectColorEvent>(_onSelectColor);
    on<SelectSizeEvent>(_onSelectSize);
    on<AddToCartEvent>(_onAddToCart);
    on<SelectMaterialEvent>(_onSelectMaterial);
    on<SelectHeelHeightEvent>(_onSelectHeelHeight);
    on<FilterVariantsByAttributeEvent>(_onFilterVariantsByAttribute);
    on<IncrementQuantityEvent>(_onIncrementQty);
    on<DecrementQuantityEvent>(_onDecrementQty);
    on<ResetAddingStateEvent>(_onResetAddingState);
    on<SelectVariantByIdEvent>(_onSelectVariantById);
  }

  /// Stock rule for variant combinations.
  /// Some backends don't send `quantityAvailable` consistently; when it's null we treat it as "unknown quantity"
  /// and allow selection as long as `inStock` is true.
  bool _isVariantInStock(VariantCombination v) {
    final qty = v.quantityAvailable;
    return v.inStock && (qty == null || qty > 0);
  }

  String _norm(String s) => s.toLowerCase().trim();

  static bool _isColorAttributeKey(String key) {
    final k = key.toLowerCase();
    return k == 'color name' || k == 'color' || k == 'colour' || k == 'اللون' || k == 'لون';
  }

  /// Get color value from a variant (tries common attribute names).
  String? _getVariantColorValue(VariantCombination v) {
    const colorAttrNames = [
      'COLOR NAME', 'color name', 'Color Name', 'color', 'Color', 'COLOR',
      'colour', 'Colour', 'اللون', 'لون',
    ];
    for (final attrName in colorAttrNames) {
      final value = v.getAttributeValue(attrName);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Returns true when variant's color value matches the selected value (handles Arabic/English).
  /// Variants from API typically have English; selectedValue may be Arabic when app is in Arabic.
  bool _colorValuesMatch(ProductDetails pd, String? variantValue, String selectedValue) {
    if (variantValue == null || variantValue.isEmpty) return false;
    final nV = _norm(variantValue);
    final nS = _norm(selectedValue);
    if (nV == nS) return true;
    for (final color in pd.colorOptions) {
      final nameNorm = _norm(color.name);
      final displayNorm = color.displayName != null ? _norm(color.displayName!) : '';
      if (nameNorm.isEmpty) continue;
      if (nameNorm != nV) continue;
      if (nS == nameNorm || nS == displayNorm) return true;
      if (displayNorm.isNotEmpty && (nS.contains(displayNorm) || displayNorm.contains(nS))) return true;
    }
    return false;
  }

  /// Maps UI/option attribute name to API attribute_name (COLOR, SIZE, MATERIALS, HEIGHT).
  static String? _optionAttributeNameToApiName(String attributeName, String primaryVariantLabel) {
    final l = attributeName.toLowerCase().trim();
    if (l.contains('color') || l == 'colour' || l == 'اللون' || l == 'لون') return 'COLOR';
    if (l == 'size' || (primaryVariantLabel.isNotEmpty && l == primaryVariantLabel.toLowerCase())) return 'SIZE';
    if (l.contains('material')) return 'MATERIALS';
    if (l == 'height' || l.contains('heel')) return 'HEIGHT';
    return null;
  }

  /// Builds map of API attribute_name -> value_id from current selection.
  /// Used to filter the exact variant combination by attributes (for inStock/quantity_available).
  Map<String, String> _buildSelectedAttributesByValueId(ProductDetails pd) {
    final Map<String, String> out = {};
    for (final opt in pd.variantAttributeOptions) {
      if (opt.selectedValue.isEmpty) continue;
      final selectedVal = opt.values.where((v) => v.name == opt.selectedValue || v.isSelected).toList();
      if (selectedVal.isEmpty) continue;
      final valueId = selectedVal.first.id.trim();
      if (valueId.isEmpty) continue;
      final apiName = _optionAttributeNameToApiName(opt.attributeName, pd.primaryVariantLabel);
      if (apiName != null) out[apiName] = valueId;
    }
    if (out['SIZE'] == null && pd.selectedSize.isNotEmpty) {
      final sel = pd.sizeOptions.where((s) => s.name.trim() == pd.selectedSize.trim() || s.isSelected).toList();
      if (sel.isNotEmpty && sel.first.id.trim().isNotEmpty) out['SIZE'] = sel.first.id.trim();
    }
    return out;
  }

  /// Attribute value lookup from a variant combination.
  /// Uses the product's variant attribute options to resolve the API attribute name
  /// (e.g. MATERIAL NAME → MATERIALS), so any attribute (material, height, size, etc.)
  /// works without hardcoding names.
  String? _getComboValueForAttribute(
    ProductDetails product,
    VariantCombination combo,
    String attributeName,
  ) {
    final lower = _norm(attributeName);

    // 1) Resolve API name from product options (dynamic: whatever the API uses).
    final matching = product.variantAttributeOptions.where((o) => _norm(o.attributeName) == lower).toList();
    final option = matching.isEmpty ? null : matching.first;
    final String? apiName = option?.apiAttributeName;
    final List<String> keysToTry = [
      if (apiName != null && apiName.isNotEmpty) apiName,
      attributeName,
    ];

    for (final k in keysToTry) {
      final v = combo.getAttributeValue(k);
      if (v != null && v.isNotEmpty) return v;
    }

    // 2) Fuzzy fallback: match by normalized name or by shared word (e.g. "material name" ↔ "materials").
    for (final attr in combo.attributes) {
      final a = _norm(attr.attributeName);
      if (a == lower || a.contains(lower) || lower.contains(a)) {
        final v = attr.valueName;
        if (v.isNotEmpty) return v;
      }
      // Match by significant word (length > 2) so any attribute name works
      final lowerWords = lower.split(RegExp(r'\s+')).where((w) => w.length > 2);
      final aWords = a.split(RegExp(r'\s+')).where((w) => w.length > 2);
      if (lowerWords.any((w) => a.contains(w)) || aWords.any((w) => lower.contains(w))) {
        final v = attr.valueName;
        if (v.isNotEmpty) return v;
      }
    }

    return null;
  }

  /// Same resolution as _getComboValueForAttribute but returns valueId (for matching when value_name is Arabic).
  String? _getComboValueIdForAttribute(
    ProductDetails product,
    VariantCombination combo,
    String attributeName,
  ) {
    final lower = _norm(attributeName);
    final matching = product.variantAttributeOptions.where((o) => _norm(o.attributeName) == lower).toList();
    final option = matching.isEmpty ? null : matching.first;
    final String? apiName = option?.apiAttributeName;
    final List<String> keysToTry = [
      if (apiName != null && apiName.isNotEmpty) apiName,
      attributeName,
    ];
    for (final k in keysToTry) {
      for (final attr in combo.attributes) {
        if (_norm(attr.attributeName) == _norm(k)) {
          final id = attr.valueId;
          if (id != null && id.isNotEmpty) return id;
          break;
        }
      }
    }
    for (final attr in combo.attributes) {
      final a = _norm(attr.attributeName);
      if (a == lower || a.contains(lower) || lower.contains(a)) {
        final id = attr.valueId;
        if (id != null && id.isNotEmpty) return id;
      }
      final lowerWords = lower.split(RegExp(r'\s+')).where((w) => w.length > 2);
      final aWords = a.split(RegExp(r'\s+')).where((w) => w.length > 2);
      if (lowerWords.any((w) => a.contains(w)) || aWords.any((w) => lower.contains(w))) {
        final id = attr.valueId;
        if (id != null && id.isNotEmpty) return id;
      }
    }
    return null;
  }

  /// On initial load, recompute material (and similar non-critical) option availability from
  /// variants: a value is available if any variant has selected size + selected color + this value,
  /// regardless of stock. Prevents all material buttons from being grey when everything is out of stock.
  ProductDetails _recomputeMaterialAvailabilityFromVariants(ProductDetails product) {
    final options = product.variantAttributeOptions;
    final List<VariantAttributeOption> newOptions = [];
    for (final opt in options) {
      final attrLower = opt.attributeName.toLowerCase();
      final isMaterialAttr = attrLower.contains('material');
      if (!isMaterialAttr) {
        newOptions.add(opt);
        continue;
      }
      final newValues = opt.values.map((value) {
        bool isAvailable = false;
        for (final combo in product.variantCombinations) {
          final comboVal = _getComboValueForAttribute(product, combo, opt.attributeName);
          final comboValId = _getComboValueIdForAttribute(product, combo, opt.attributeName);
          final valueMatches = (comboVal != null && _norm(comboVal) == _norm(value.name)) ||
              (comboValId != null && value.id.toString().trim() == comboValId.trim());
          if (!valueMatches) continue;
          final sizeVal = _getComboValueForAttribute(product, combo, product.primaryVariantLabel) ??
              _getComboValueForAttribute(product, combo, 'SIZE');
          final colorVal = _getComboValueForAttribute(product, combo, 'COLOR NAME') ??
              _getComboValueForAttribute(product, combo, 'COLOR') ??
              _getComboValueForAttribute(product, combo, 'اللون');
          final sizeMatch = product.selectedSize.isEmpty ||
              (sizeVal != null && _norm(sizeVal) == _norm(product.selectedSize));
          final colorMatch = product.selectedColor.isEmpty ||
              (colorVal != null && _norm(colorVal) == _norm(product.selectedColor));
          if (sizeMatch && colorMatch) {
            isAvailable = true;
            break;
          }
        }
        // Show as selected the value that matches current selectedValue (so one chip is clearly selected).
        final isSelected = opt.selectedValue.isNotEmpty &&
            (_norm(opt.selectedValue) == _norm(value.name) ||
                value.id.toString().trim() == opt.selectedValue.trim());
        return VariantAttributeValue(
          id: value.id,
          name: value.name,
          displayName: value.displayName,
          isAvailable: isAvailable,
          isSelected: isSelected,
        );
      }).toList();
      newOptions.add(VariantAttributeOption(
        attributeName: opt.attributeName,
        values: newValues,
        selectedValue: opt.selectedValue,
        apiAttributeName: opt.apiAttributeName,
        attributeId: opt.attributeId,
      ));
    }
    return product.copyWith(variantAttributeOptions: newOptions);
  }

  void _onResetAddingState(
    ResetAddingStateEvent event,
    Emitter<ProductDetailsState> emit,
  ) {
    if (state is ProductDetailsLoaded) {
      final currentState = state as ProductDetailsLoaded;
      emit(currentState.copyWith(isAdding: false));
    }
  }

  /// When a selector (color/material/other) knows the exact variantId that
  /// should be active, this handler updates the ProductDetails images using
  /// the shared helper on the entity and re-emits the loaded state.
  Future<void> _onSelectVariantById(
    SelectVariantByIdEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    final blocState = state;
    if (blocState is! ProductDetailsLoaded) return;

    final product = blocState.productDetails;
    final variantId = event.variantId;

    // Update only the images based on this concrete variantId; all other
    // selection state (color, size, material, etc.) stays as-is.
    final updatedProduct = product.withImagesForVariant(variantId);

    debugPrint(
      '🧪 _onSelectVariantById → variantId=$variantId, '
      'newImagesCount=${updatedProduct.images.length}, '
      'images=${updatedProduct.images}',
    );

    emit(ProductDetailsLoaded(
      updatedProduct,
      quantity: blocState.quantity,
      isAdding: blocState.isAdding,
    ));
  }
  Future<void> _onSelectMaterial(
    SelectMaterialEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state is ProductDetailsLoaded) {
      final s = state as ProductDetailsLoaded;
      final p = s.productDetails;
      
      // Check if this material has any in-stock variants with current selections
      bool hasInStockVariant = false;
      if (p.selectedSize.isNotEmpty && p.selectedColor.isNotEmpty) {
        for (final v in p.variantCombinations) {
          final bool sizeMatch = v.hasAttributeValue(p.primaryVariantLabel, p.selectedSize) ||
                               v.hasAttributeValue('size', p.selectedSize) ||
                               v.hasAttributeValue('SIZE', p.selectedSize);
          // Get actual color name from variantAttributeOptions
          String? actualColorName;
          for (final opt in p.variantAttributeOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if ((attrNameLower == 'color name' || 
                 attrNameLower == 'color' || 
                 attrNameLower == 'colour' ||
                 attrNameLower == 'اللون') && 
                opt.selectedValue.isNotEmpty) {
              actualColorName = opt.selectedValue;
              break;
            }
          }
          if (actualColorName == null && p.selectedColor.isNotEmpty) {
            actualColorName = p.selectedColor;
          }
          
          String normalize(String s) => s.toLowerCase().trim();
          final String? variantColorName = _getComboValueForAttribute(p, v, 'COLOR NAME');
          final bool colorMatch = actualColorName != null && 
                                variantColorName != null &&
                                normalize(variantColorName) == normalize(actualColorName);
          final bool materialMatch = _getComboValueForAttribute(p, v, 'MATERIAL NAME')?.toLowerCase() == event.material.toLowerCase();
          
          if (sizeMatch && colorMatch && materialMatch) {
            final isInStock = v.inStock && (v.quantityAvailable == null || v.quantityAvailable! > 0);
            if (isInStock) {
              hasInStockVariant = true;
              break;
            }
          }
        }
        
        // If no in-stock variant exists for this material combination, don't allow selection
        if (!hasInStockVariant) {
          debugPrint('⚠️ Cannot select material ${event.material}: no in-stock variants for size ${p.selectedSize} and color ${p.selectedColor}');
          return;
        }
      }
      
      var updated = ProductDetails(
        id: p.id,
        brand: p.brand,
        name: p.name,
        description: p.description,
        price: p.price,
        originalPrice: p.originalPrice,
        rating: p.rating,
        reviewCount: p.reviewCount,
        images: p.images,
        colorOptions: p.colorOptions,
        sizeOptions: p.sizeOptions,
        variantAttributeOptions: p.variantAttributeOptions,
        selectedColor: p.selectedColor,
        selectedSize: p.selectedSize,
        isFavorite: p.isFavorite,
        hasDiscount: p.hasDiscount,
        discountPercentage: p.discountPercentage,
        features: p.features,
        material: p.material,
        materialsList: p.materialsList,
        materialOptions: p.materialOptions,
        selectedMaterial: event.material,
        careInstructions: p.careInstructions,
        heelHeightCm: p.heelHeightCm,
        heelType: p.heelType,
        heelHeightOptions: p.heelHeightOptions,
        selectedHeelHeightCm: p.selectedHeelHeightCm,
        isPlusMember: p.isPlusMember,
        pointsEarned: p.pointsEarned,
        optionalProducts: p.optionalProducts,
        accessoryProducts: p.accessoryProducts,
        alternativeProducts: p.alternativeProducts,
        variantCombinations: p.variantCombinations,
        primaryVariantLabel: p.primaryVariantLabel,
        tags: p.tags,
        variantImagesMap: p.variantImagesMap,
      );
      
      // Sync stock & quantity with the newly selected variant combination
      int nextQuantity = s.quantity;
      final VariantCombination? selectedVariant = _findSelectedVariant(updated);
      if (selectedVariant != null) {
        final double? quantityAvailable = selectedVariant.quantityAvailable;
        bool variantInStock = selectedVariant.inStock;

        if (quantityAvailable != null) {
          // Check if there's already an item in cart with this variant ID
          int existingCartQuantity = 0;
          final variantIdToCheck = selectedVariant.variantId;
          // Convert variantId to String for comparison (cart items use String IDs)
          final variantIdStr = variantIdToCheck.toString();
          if (cartBloc.state is CartLoaded) {
            final cartState = cartBloc.state as CartLoaded;
            try {
              final existingItem = cartState.cartItems.firstWhere(
                (item) => item.product.id.toString() == variantIdStr,
              );
              existingCartQuantity = existingItem.quantity;
            } catch (e) {
              // Item not found in cart, existingCartQuantity remains 0
            }
          }
          
          final maxAllowed = quantityAvailable.toInt();
          final available = maxAllowed - existingCartQuantity;
          
          if (maxAllowed <= 0 || available <= 0) {
            variantInStock = false;
            nextQuantity = 1;
          } else {
            // Clamp to available quantity (accounting for cart items)
            if (nextQuantity > available) {
              nextQuantity = available;
            }
            if (nextQuantity <= 0) {
              nextQuantity = 1;
            }
          }
          
          debugPrint('🧵 Material selected: ${event.material}, variantId=${selectedVariant.variantId}, totalAvailable=$maxAllowed, inCart=$existingCartQuantity, available=$available, adjustedQty=$nextQuantity');
        }

        updated = updated.copyWith(
          inStock: variantInStock,
          selectedVariantQuantityAvailable: selectedVariant.quantityAvailable?.toInt(),
        );
        // Images update only on color change; do not change images when material is selected.
      }
      
      emit(ProductDetailsLoaded(updated, quantity: nextQuantity, isAdding: false));
    }
  }

  Future<void> _onSelectHeelHeight(
    SelectHeelHeightEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state is ProductDetailsLoaded) {
      final s = state as ProductDetailsLoaded;
      final p = s.productDetails;
      
      // Check if this heel height has any in-stock variants with current selections
      bool hasInStockVariant = false;
      final heightStr = event.heelHeightCm.toStringAsFixed(1);
      
      // Get actual color name from variantAttributeOptions
      String? actualColorName;
      for (final opt in p.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if ((attrNameLower == 'color name' || 
             attrNameLower == 'color' || 
             attrNameLower == 'colour' ||
             attrNameLower == 'اللون') && 
            opt.selectedValue.isNotEmpty) {
          actualColorName = opt.selectedValue;
          break;
        }
      }
      if (actualColorName == null && p.selectedColor.isNotEmpty) {
        actualColorName = p.selectedColor;
      }
      
      if (p.selectedSize.isNotEmpty && actualColorName != null && actualColorName.isNotEmpty) {
        String normalize(String s) => s.toLowerCase().trim();
        for (final v in p.variantCombinations) {
          final String? variantSize = _getComboValueForAttribute(p, v, p.primaryVariantLabel) ?? _getComboValueForAttribute(p, v, 'SIZE');
          final bool sizeMatch = variantSize != null && normalize(variantSize) == normalize(p.selectedSize);
          final String? variantColorName = _getComboValueForAttribute(p, v, 'COLOR NAME');
          final bool colorMatch = variantColorName != null && 
                                normalize(variantColorName) == normalize(actualColorName);
          final bool materialMatch = p.selectedMaterial == null || 
                                   p.selectedMaterial!.isEmpty ||
                                   _getComboValueForAttribute(p, v, 'MATERIAL NAME')?.toLowerCase() == p.selectedMaterial!.toLowerCase();
          final String? variantHeight = _getComboValueForAttribute(p, v, 'HEIGHT');
          final bool heightMatch = variantHeight != null && normalize(variantHeight) == normalize(heightStr);
          
          if (sizeMatch && colorMatch && materialMatch && heightMatch) {
            final isInStock = v.inStock && (v.quantityAvailable == null || v.quantityAvailable! > 0);
            if (isInStock) {
              hasInStockVariant = true;
              break;
            }
          }
        }
        
        // If no in-stock variant exists for this heel height combination, don't allow selection
        if (!hasInStockVariant) {
          debugPrint('⚠️ Cannot select heel height ${heightStr}cm: no in-stock variants for current selections');
          return;
        }
      }
      
      var updated = ProductDetails(
        id: p.id,
        brand: p.brand,
        name: p.name,
        description: p.description,
        price: p.price,
        originalPrice: p.originalPrice,
        rating: p.rating,
        reviewCount: p.reviewCount,
        images: p.images,
        colorOptions: p.colorOptions,
        sizeOptions: p.sizeOptions,
        variantAttributeOptions: p.variantAttributeOptions,
        selectedColor: p.selectedColor,
        selectedSize: p.selectedSize,
        isFavorite: p.isFavorite,
        hasDiscount: p.hasDiscount,
        discountPercentage: p.discountPercentage,
        features: p.features,
        material: p.material,
        materialsList: p.materialsList,
        materialOptions: p.materialOptions,
        selectedMaterial: p.selectedMaterial,
        careInstructions: p.careInstructions,
        heelHeightCm: event.heelHeightCm,
        heelType: p.heelType,
        heelHeightOptions: p.heelHeightOptions,
        selectedHeelHeightCm: event.heelHeightCm,
        isPlusMember: p.isPlusMember,
        pointsEarned: p.pointsEarned,
        optionalProducts: p.optionalProducts,
        accessoryProducts: p.accessoryProducts,
        alternativeProducts: p.alternativeProducts,
        variantCombinations: p.variantCombinations,
        primaryVariantLabel: p.primaryVariantLabel,
        tags: p.tags,
        variantImagesMap: p.variantImagesMap,
      );
      
      // Sync stock & quantity with the newly selected variant combination
      int nextQuantity = s.quantity;
      final VariantCombination? selectedVariant = _findSelectedVariant(updated);
      if (selectedVariant != null) {
        final double? quantityAvailable = selectedVariant.quantityAvailable;
        bool variantInStock = selectedVariant.inStock;

        if (quantityAvailable != null) {
          // Check if there's already an item in cart with this variant ID
          int existingCartQuantity = 0;
          final variantIdToCheck = selectedVariant.variantId;
          // Convert variantId to String for comparison (cart items use String IDs)
          final variantIdStr = variantIdToCheck.toString();
          if (cartBloc.state is CartLoaded) {
            final cartState = cartBloc.state as CartLoaded;
            try {
              final existingItem = cartState.cartItems.firstWhere(
                (item) => item.product.id.toString() == variantIdStr,
              );
              existingCartQuantity = existingItem.quantity;
            } catch (e) {
              // Item not found in cart, existingCartQuantity remains 0
            }
          }
          
          final maxAllowed = quantityAvailable.toInt();
          final available = maxAllowed - existingCartQuantity;
          
          if (maxAllowed <= 0 || available <= 0) {
            variantInStock = false;
            nextQuantity = 1;
          } else {
            // Clamp to available quantity (accounting for cart items)
            if (nextQuantity > available) {
              nextQuantity = available;
            }
            if (nextQuantity <= 0) {
              nextQuantity = 1;
            }
          }
          
          debugPrint('👠 Heel height selected: ${event.heelHeightCm}cm, variantId=${selectedVariant.variantId}, totalAvailable=$maxAllowed, inCart=$existingCartQuantity, available=$available, adjustedQty=$nextQuantity');
        }

        updated = updated.copyWith(
          inStock: variantInStock,
          selectedVariantQuantityAvailable: selectedVariant.quantityAvailable?.toInt(),
        );
        // Images update only on color change; do not change images when heel height is selected.
      }
      
      emit(ProductDetailsLoaded(updated, quantity: nextQuantity, isAdding: false));
    }
  }

  /// Handles attribute selection for ALL dynamic attributes (material, height, width, measurements, etc.).
  /// This is the generic handler that works for any attribute added in the future.
  /// Uses validation logic: loop with clicked id → get available combination → validate against full selection.
  Future<void> _onFilterVariantsByAttribute(
    FilterVariantsByAttributeEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    final blocState = state;
    if (blocState is! ProductDetailsLoaded) return;

    final currentProduct = blocState.productDetails;

    debugPrint('🔴 [FilterVariantsByAttribute] ═══════════════════════════════════════');
    debugPrint('🔴 [FilterVariantsByAttribute] EVENT RECEIVED (USER TAPPED BUTTON)');
    debugPrint('🔴 [FilterVariantsByAttribute] attributeName="${event.attributeName}" value="${event.attributeValue}" valueId=${event.attributeValueId}');
    debugPrint('🔴 [FilterVariantsByAttribute] BEFORE state: selectedSize="${currentProduct.selectedSize}" selectedColor="${currentProduct.selectedColor}"');
    for (final opt in currentProduct.variantAttributeOptions) {
      debugPrint('🔴 [FilterVariantsByAttribute]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
    }
    debugPrint('🔴 [FilterVariantsByAttribute] ═══════════════════════════════════════');

    if (event.attributeValueId.trim().isEmpty) {
      debugPrint('🟢 [_onFilterVariantsByAttribute] attributeValueId is empty, ignoring');
      return;
    }
    final tappedValueId = event.attributeValueId.trim();
    debugPrint(
      '🟢 [_onFilterVariantsByAttribute] valueId=$tappedValueId (sent to loop)',
    );

    // Find the option and value ONLY by value id (no name used for the loop).
    VariantAttributeOption? tappedOption;
    VariantAttributeValue? tappedValue;
    for (final opt in currentProduct.variantAttributeOptions) {
      for (final v in opt.values) {
        if (v.id.toString().trim() == tappedValueId) {
          tappedOption = opt;
          tappedValue = v;
          break;
        }
      }
      if (tappedOption != null) break;
    }
    if (tappedOption == null || tappedValue == null) {
      debugPrint('⚠️ [_onFilterVariantsByAttribute] No option/value found for valueId=$tappedValueId');
      return;
    }
    final tappedAttrSlug = ProductDetails.attributeNameToComboSlug(tappedOption.attributeName);
    debugPrint(
      '   🧬 [Filter][Tap] attribute="${tappedOption.attributeName}" (slug=$tappedAttrSlug) valueId=$tappedValueId',
    );

    // Same value already selected? Check only by id.
    try {
      final currentSelected = tappedOption.values.firstWhere(
        (v) => v.isSelected ||
            _norm(v.name) == _norm(tappedOption!.selectedValue) ||
            (v.displayName != null && _norm(v.displayName!) == _norm(tappedOption!.selectedValue)),
      );
      if (currentSelected.id.toString().trim() == tappedValueId) {
        debugPrint('🧩 FilterVariantsByAttributeEvent: same value id already selected, skipping');
        return;
      }
    } catch (_) {}

    debugPrint(
      '   Variants: count=${currentProduct.variantCombinations.length}',
    );

    // Step 1: Build selection by value IDs only (slug -> id). This is what we send to the loop.
    final Map<String, int> selectedByAttributeById = {};
    final tappedIdInt = int.tryParse(tappedValueId);
    if (tappedIdInt != null) {
      selectedByAttributeById[tappedAttrSlug] = tappedIdInt;
    }
    for (final opt in currentProduct.variantAttributeOptions) {
      if (opt.attributeName == tappedOption.attributeName) continue; // already set
      if (opt.selectedValue.isEmpty) continue;
      try {
        final matchedValue = opt.values.firstWhere(
          (v) => _norm(v.name) == _norm(opt.selectedValue) ||
              _norm(v.displayName ?? '') == _norm(opt.selectedValue) ||
              v.isSelected,
        );
        final idInt = int.tryParse(matchedValue.id.toString());
        if (idInt != null) {
          final slug = ProductDetails.attributeNameToComboSlug(opt.attributeName);
          if (slug.isNotEmpty) selectedByAttributeById[slug] = idInt;
        }
      } catch (_) {}
    }
    debugPrint(
      '   🧬 [Filter][Ids] selectedByAttributeById (slug->id, sent to loop) = $selectedByAttributeById',
    );

    // Derived name map only for variant_combinations fallback and debug (loop uses ids only).
    final Map<String, String> selectedByAttribute = {};
    for (final opt in currentProduct.variantAttributeOptions) {
      String name = opt.selectedValue;
      if (opt.attributeName == tappedOption.attributeName) {
        name = tappedValue.name;
      } else if (opt.selectedValue.isNotEmpty) {
        try {
          final v = opt.values.firstWhere(
            (v) => _norm(v.name) == _norm(opt.selectedValue) ||
                _norm(v.displayName ?? '') == _norm(opt.selectedValue) ||
                v.isSelected,
          );
          name = v.name;
        } catch (_) {}
      }
      if (name.isNotEmpty) selectedByAttribute[opt.attributeName] = name;
    }

    // Step 2: compute availability per attribute value using variant_combinations,
    // and OR it with id-based availability from attribute_value_combinations.
    final List<VariantAttributeOption> recomputedOptions = [];
    final bool eventIsForHeight = tappedOption.attributeName.toLowerCase().trim() == 'height' ||
        tappedOption.attributeName.toLowerCase().trim() == 'heel height';
    for (final attrOption in currentProduct.variantAttributeOptions) {
      final String attributeName = attrOption.attributeName;
      final bool isHeightAttr = attributeName.toLowerCase() == 'height' || attributeName.toLowerCase() == 'heel height';

      // When user changed MATERIAL (or anything other than HEIGHT), don't recompute HEIGHT at all:
      // keep the existing HEIGHT option so height selection and availability are not removed/changed.
      if (isHeightAttr && !eventIsForHeight) {
        recomputedOptions.add(attrOption);
        continue;
      }

      // Debug: Log when checking Material availability
      final bool isMaterialAttr = attributeName.toLowerCase().contains('material');
      if (isMaterialAttr) {
        debugPrint(
          '🔍 Checking Material availability for size="${selectedByAttribute[currentProduct.primaryVariantLabel] ?? selectedByAttribute['SIZE'] ?? 'none'}", '
          'color="${selectedByAttribute['COLOR NAME'] ?? selectedByAttribute['color'] ?? 'none'}"',
        );
      }

      // For the current attribute, fetch enabled ids/slugs from attribute_value_combinations (if present).
      ({Set<int> ids, Set<String> slugs}) enabledFromAttrCombos = (ids: <int>{}, slugs: <String>{});
      if (currentProduct.attributeVariantCombinations.isNotEmpty ||
          currentProduct.attributeValueCombinationsByKey.isNotEmpty) {
        try {
          enabledFromAttrCombos =
              currentProduct.getEnabledIdsAndSlugsForAttribute(
            attributeName,
            selectedByAttribute,
            currentProduct.primaryVariantLabel,
            selectedByAttributeById: selectedByAttributeById,
          );
          debugPrint(
            '   🧬 [AttrCombos] attr="$attributeName": '
            'enabledIds=${enabledFromAttrCombos.ids.toList()} '
            'enabledSlugs=${enabledFromAttrCombos.slugs.toList()}',
          );
          if (attributeName == tappedOption.attributeName && tappedIdInt != null) {
            debugPrint(
              '   🧬 [AttrCombos] tappedId=$tappedValueId '
              '→ inEnabledIds=${enabledFromAttrCombos.ids.contains(tappedIdInt)}',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [AttrCombos] Error computing enabled ids for "$attributeName": $e');
        }
      }

      final List<VariantAttributeValue> newValues = attrOption.values.map((value) {
        // If attribute_value_combinations says this value id is enabled, we must
        // NEVER disable this button in any scenario (Arabic & English behave the same).
        final int? valueIdInt = int.tryParse(value.id.toString());
        final bool guaranteedAvailableById = valueIdInt != null &&
            enabledFromAttrCombos.ids.contains(valueIdInt);

        bool isAvailable = guaranteedAvailableById;
        int matchesTried = 0;
        int matchesStock = 0;

        // HEIGHT: for now do not disable height options - keep all height buttons enabled
        final bool isHeightAttrForAvailability = attributeName.toLowerCase() == 'height' || attributeName.toLowerCase() == 'heel height';
        if (isHeightAttrForAvailability) {
          isAvailable = true; // Force height button to always be enabled (disabling logic commented out below)
        } else if (!guaranteedAvailableById) {
        for (final combo in currentProduct.variantCombinations) {
          bool matchesSelections = true;

          // CRITICAL FIX: Only require critical attributes (Size and Color) when checking availability
          // Optional attributes (Material, Height, Brand) should NOT block availability checks
          // This allows users to change sizes/colors even when other attributes are selected
          
          // Helper to check if an attribute is critical (Size or Color)
          bool isCriticalAttribute(String attrName) {
            final attrLower = attrName.toLowerCase();
            return attrLower == 'size' ||
                   attrLower == 'القياس' ||
                   attrLower == currentProduct.primaryVariantLabel.toLowerCase() ||
                   attrLower == 'color' ||
                   attrLower == 'colour' ||
                   attrLower == 'color name' ||
                   attrLower == 'اللون';
          }
          
          // First, check if the candidate value for this attribute matches (by name or by valueId for e.g. Arabic vs English).
          final String? comboValForThisAttr = _getComboValueForAttribute(
            currentProduct,
            combo,
            attributeName,
          );
          final String? comboValIdForThisAttr = _getComboValueIdForAttribute(
            currentProduct,
            combo,
            attributeName,
          );
          final bool valueMatches = (comboValForThisAttr != null &&
                  _norm(comboValForThisAttr) == _norm(value.name)) ||
              (comboValIdForThisAttr != null &&
                  value.id.toString().trim() == comboValIdForThisAttr.trim());
          if (!valueMatches) {
            matchesSelections = false;
            if (isMaterialAttr && matchesTried < 3) {
              debugPrint(
                '   Material value "${value.name}" (id=${value.id}): combo has name="${comboValForThisAttr ?? 'null'}" id=${comboValIdForThisAttr ?? 'null'} → no match',
              );
            }
          }
          
          // Then, only check critical attributes (Size and Color) if they are selected
          // CRITICAL: When checking availability for non-critical attributes (Material, Height),
          // we should NOT require other non-critical attributes to match. This allows users to
          // freely switch between materials/heights without disabling each other.
          // Only Size and Color are required to match.
          if (matchesSelections) {
            // Check if the attribute we're evaluating is non-critical
            final bool isEvaluatingNonCritical = !isCriticalAttribute(attributeName);
            
            for (final entry in selectedByAttribute.entries) {
              final String selAttr = entry.key;
              final String selValue = entry.value;

              // Skip if this is the attribute we're evaluating (already checked above)
              if (selAttr == attributeName) continue;
              
              // CRITICAL FIX: If we're evaluating a non-critical attribute (e.g., Material),
              // and another non-critical attribute is selected (e.g., Height), skip it.
              // This prevents Material from being disabled when Height is selected, and vice versa.
              // Only require critical attributes (Size, Color) to match.
              if (isEvaluatingNonCritical && !isCriticalAttribute(selAttr)) {
                continue; // Skip non-critical attributes when evaluating non-critical attributes
              }
              
              // Only check critical attributes (Size and Color) when evaluating critical attributes
              if (!isCriticalAttribute(selAttr)) continue;
              
              // When evaluating availability, allow trying the candidate value for this attribute
              // CRITICAL: selectedByAttribute now contains English names, so matching should work
              // For color attributes, use bilingual matching
              final String mustMatchValue = selValue; // This is now English from selectedByAttribute
              final String? comboVal = _getComboValueForAttribute(
                currentProduct,
                combo,
                selAttr,
              );
              if (comboVal == null) {
                matchesSelections = false;
                break;
              }
              
              // For color attributes, use bilingual matching
              if (_isColorAttributeKey(selAttr)) {
                if (!_colorValuesMatch(currentProduct, comboVal, mustMatchValue)) {
                  matchesSelections = false;
                  break;
                }
              } else {
                // For other attributes, use exact match (both should be English)
                if (_norm(comboVal) != _norm(mustMatchValue)) {
                  matchesSelections = false;
                  break;
                }
              }
            }
          }

          // Check if variant is in stock
          final isInStock = _isVariantInStock(combo);
          if (matchesSelections) {
            matchesTried += 1;
            if (isInStock) {
              matchesStock += 1;
            }
            // For Material (and other non-critical attributes): enable the button if a variant
            // EXISTS for this value (size+color+material), regardless of stock. User can still
            // select and we show "Out of Stock" for that combination. Prevents all material
            // buttons from being grey when every variant is out of stock.
            if (isMaterialAttr) {
              isAvailable = true;
              debugPrint(
                '   ✅ Material value "${value.name}" ENABLED (variant exists, variantId=${combo.variantId}, inStock=$isInStock)',
              );
              break;
            }
            if (isInStock) {
              isAvailable = true;
              break;
            }
          }
        }

        // If attribute_value_combinations already guaranteed this id, keep it available
        // regardless of the per-variant loop outcome.
        if (!isAvailable && guaranteedAvailableById) {
          isAvailable = true;
          debugPrint(
            '   ✅ [AttrCombos] attr="$attributeName" value="${value.name}" (id=${value.id}) '
            'forced available by attribute_value_combinations (id match)',
          );
        }
        } // end else-if: skip variant-combo availability loop for height

        // For material: only preserve availability when the value was ALREADY available before
        // (so we don't enable e.g. Synthetic Leather when it's not available for this combination).
        if (!isAvailable && isMaterialAttr) {
          final originalValues = attrOption.values.where(
            (v) => v.name.toLowerCase().trim() == value.name.toLowerCase().trim(),
          ).toList();
          if (originalValues.isNotEmpty && originalValues.first.isAvailable) {
            isAvailable = true;
            if (matchesTried < 2) {
              debugPrint(
                '   ✅ Material value "${value.name}" kept available (was already available)',
              );
            }
          }
        }

        // [HEIGHT DISABLING - commented out so height button stays enabled]
        // Preserve HEIGHT availability so changing height never hides other height options:
        // if this height value was available before, keep it available after recompute.
        // final bool isHeightAttr = attributeName.toLowerCase() == 'height' || attributeName.toLowerCase() == 'heel height';
        // if (!isAvailable && isHeightAttr) {
        //   final originalHeightValues = attrOption.values.where(
        //     (v) => v.name.toLowerCase().trim() == value.name.toLowerCase().trim(),
        //   ).toList();
        //   if (originalHeightValues.isNotEmpty && originalHeightValues.first.isAvailable) {
        //     isAvailable = true;
        //   }
        // }

        if (!isAvailable && !guaranteedAvailableById) {
          // Very useful signal when everything becomes disabled:
          // it tells us whether it's selection mismatch or stock mismatch.
          if (isMaterialAttr) {
            debugPrint(
              '   🔻 Material value "${value.name}" DISABLED: matched=$matchesTried variants, inStockMatched=$matchesStock',
            );
          } else {
            debugPrint(
              '   🔻 Disabled value: attr="$attributeName" value="${value.name}" '
              '(matched=$matchesTried, inStockMatched=$matchesStock)',
            );
          }
        }

        // Selection: always show which value is selected (by name or id); only disable when no variant exists.
        // So selected chip stays selected (orange) even if that combo is out of stock; only unavailable chips are grey.
        // CRITICAL: selectedByAttribute now contains English names, so compare with value.name (also English)
        final String? selVal = selectedByAttribute[attributeName];
        final bool selectedMatch = selVal != null && selVal.isNotEmpty &&
            (_norm(selVal) == _norm(value.name) || value.id.toString().trim() == selVal.trim());
        // Tapped value is identified by id only (no name used)
        final bool isJustTappedValue = (tappedOption?.attributeName == attributeName) &&
            value.id.toString().trim() == tappedValueId;
        // FINAL availability used for UI:
        // - Never turn an originally-available value into unavailable.
        // - Always keep values enabled when attribute_value_combinations says so.
        final bool effectiveIsAvailable =
            value.isAvailable || guaranteedAvailableById || isAvailable;

        final bool isSelected = selectedMatch || isJustTappedValue;
        return VariantAttributeValue(
          id: value.id,
          name: value.name,
          displayName: value.displayName,
          isAvailable: effectiveIsAvailable,
          isSelected: isSelected,
        );
      }).toList();

      // Do NOT re-enable options that were correctly computed as unavailable.
      // Previously a "safety net" enabled all when all were disabled; that caused
      // unavailable options (e.g. Synthetic Leather) to appear enabled after
      // changing selection (e.g. to translucent leather). Unavailable stays unavailable.

      // CRITICAL: For Material/Height/Brand, if only one option exists, ensure it's available and selected
      final attrNameLower = attributeName.toLowerCase();
      final bool isMaterialHeightOrBrand = attrNameLower == 'material' ||
                                           attrNameLower == 'material name' ||
                                           attrNameLower == 'height' ||
                                           attrNameLower == 'heel height' ||
                                           attrNameLower == 'brand';

      if (isMaterialHeightOrBrand && newValues.length == 1) {
        // Only one option exists - always make it available and selected
        final singleValue = newValues.first;
        if (!singleValue.isAvailable || !singleValue.isSelected) {
          newValues[0] = VariantAttributeValue(
            id: singleValue.id,
            name: singleValue.name,
            displayName: singleValue.displayName,
            isAvailable: true, // Force available for single option
            isSelected: true, // Auto-select single option
          );
          debugPrint('🔴 [FilterVariantsByAttribute] AUTO-SELECT (no user tap): Single option for ${attributeName}: "${singleValue.name}" - marked as available and selected. selectedByAttribute["$attributeName"] = "${singleValue.name}"');
        }
        // Update selectedValue to match the single option
        selectedByAttribute[attributeName] = singleValue.name;
      }

      recomputedOptions.add(VariantAttributeOption(
        attributeName: attributeName,
        values: newValues,
        selectedValue: selectedByAttribute[attributeName] ?? '',
        apiAttributeName: attrOption.apiAttributeName,
        attributeId: attrOption.attributeId,
      ));

      final disabledCountAfter = newValues.where((v) => !v.isAvailable).length;
      if (isMaterialAttr) {
        debugPrint(
          '📊 Material summary: total=${newValues.length} enabled=${newValues.length - disabledCountAfter} disabled=$disabledCountAfter '
          'selected="${selectedByAttribute[attributeName] ?? ''}"',
        );
      } else {
        debugPrint(
          '   Attr "$attributeName": total=${newValues.length} enabled=${newValues.length - disabledCountAfter} disabled=$disabledCountAfter '
          'selected="${selectedByAttribute[attributeName] ?? ''}"',
        );
      }
    }

    // Debug: after recompute, log selected attributes by attribute_id (from variant_attributes)
    try {
      final debugProductForIds = currentProduct.copyWith(
        variantAttributeOptions: recomputedOptions,
      );
      final byAttrId =
          debugProductForIds.getSelectedAttributesByAttributeIdAndValueName();
      debugPrint(
        '   🧬 [Filter][AfterRecompute] attribute_id -> value_name = $byAttrId',
      );
    } catch (e) {
      debugPrint('⚠️ [Filter][AfterRecompute] Error building attribute_id map: $e');
    }

    // Step 3: matching variants for stock/availability (images update only on color change; do not set images here)
    // CRITICAL: selectedByAttribute now contains English names, so matching should work correctly
    // For color attributes, use bilingual matching to handle Arabic display names
    final matching = currentProduct.variantCombinations.where((combo) {
      for (final entry in selectedByAttribute.entries) {
        final v = _getComboValueForAttribute(currentProduct, combo, entry.key);
        if (v == null) return false;
        
        // For color attributes, use bilingual matching (handles Arabic display names)
        if (_isColorAttributeKey(entry.key)) {
          if (!_colorValuesMatch(currentProduct, v, entry.value)) {
            return false;
          }
        } else {
          // For other attributes, use exact match (both should be English now)
          if (_norm(v) != _norm(entry.value)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    // Step 4: compute selectedSize/selectedColor from recomputed options
    // CRITICAL: When event is for HEIGHT/MATERIAL (non-size), preserve current size.
    // Otherwise size can wrongly change (e.g. 39→40) due to attribute ordering or
    // multiple attributes matching the size condition.
    // CRITICAL: Use English names (value.name) from selected value, not selectedValue which might be Arabic
    String newSelectedSize = currentProduct.selectedSize;
    String newSelectedColor = currentProduct.selectedColor;
    final isSizeChangeEvent = tappedOption.attributeName.toLowerCase() == 'size' ||
        tappedOption.attributeName.toLowerCase() == currentProduct.primaryVariantLabel.toLowerCase() ||
        tappedOption.attributeName.toLowerCase().contains('size');

    debugPrint('🔴 [FilterVariantsByAttribute] Step 4 BEFORE loop: newSelectedSize="$newSelectedSize" newSelectedColor="$newSelectedColor" isSizeChangeEvent=$isSizeChangeEvent (tapped="${tappedOption.attributeName}")');

    for (final opt in recomputedOptions) {
      if (opt.attributeName.toLowerCase() == currentProduct.primaryVariantLabel.toLowerCase() ||
          opt.attributeName.toLowerCase() == 'size') {
        if (isSizeChangeEvent) {
          // Find the English name for the selected value
          String englishSizeName = opt.selectedValue;
          if (opt.selectedValue.isNotEmpty) {
            try {
              final matchedValue = opt.values.firstWhere(
                (v) => v.isSelected || _norm(v.name) == _norm(opt.selectedValue) || 
                       _norm(v.displayName ?? '') == _norm(opt.selectedValue),
              );
              englishSizeName = matchedValue.name; // Use English name
            } catch (e) {
              // If not found, check if selectedValue is already English
              bool containsArabic(String text) {
                if (text.isEmpty) return false;
                final arabicRegex = RegExp(r'[\u0600-\u06FF]');
                return arabicRegex.hasMatch(text);
              }
              if (!containsArabic(opt.selectedValue)) {
                englishSizeName = opt.selectedValue; // Already English
              }
            }
          }
          newSelectedSize = englishSizeName;
        }
        // When changing height/material: keep currentProduct.selectedSize unchanged
      }
      if (['color','colour','اللون','color name'].contains(opt.attributeName.toLowerCase())) {
        // Find the English name for the selected color value
        String englishColorName = opt.selectedValue;
        if (opt.selectedValue.isNotEmpty) {
          try {
            final matchedValue = opt.values.firstWhere(
              (v) => v.isSelected || _norm(v.name) == _norm(opt.selectedValue) || 
                     _norm(v.displayName ?? '') == _norm(opt.selectedValue),
            );
            englishColorName = matchedValue.name; // Use English name
          } catch (e) {
            // If not found, check if selectedValue is already English
            bool containsArabic(String text) {
              if (text.isEmpty) return false;
              final arabicRegex = RegExp(r'[\u0600-\u06FF]');
              return arabicRegex.hasMatch(text);
            }
            if (!containsArabic(opt.selectedValue)) {
              englishColorName = opt.selectedValue; // Already English
            }
          }
        }
        newSelectedColor = englishColorName;
        debugPrint('🔴 [FilterVariantsByAttribute] Step 4 IN LOOP: color opt "${opt.attributeName}" selectedValue="${opt.selectedValue}" → newSelectedColor="$englishColorName"');
      }
    }

    debugPrint('🔴 [FilterVariantsByAttribute] Step 4 AFTER loop: newSelectedSize="$newSelectedSize" newSelectedColor="$newSelectedColor"');
    if (newSelectedSize != currentProduct.selectedSize || newSelectedColor != currentProduct.selectedColor) {
      debugPrint('🔴 [FilterVariantsByAttribute] ⚠️ SELECTION CHANGED WITHOUT USER TAP! size: "${currentProduct.selectedSize}" → "$newSelectedSize", color: "${currentProduct.selectedColor}" → "$newSelectedColor"');
    }

    // Step 5: update overall availability based on the *currently selected* combination.
    // Prefer the normalized attribute_value_combinations (attributeVariantCombinations)
    // for in_stock + quantity_available when available, so every attribute click
    // updates stock from the same filter source used for enabling values.
    bool newInStock;
    AttributeVariantCombination? matchedAttrCombo;

    if (currentProduct.attributeVariantCombinations.isNotEmpty ||
        currentProduct.attributeValueCombinationsByKey.isNotEmpty) {
      try {
        // Step 1: Send only the clicked attribute value id to the loop; get available combination.
        debugPrint(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
        debugPrint(
          '🎯 [FilterVariantsByAttribute] Attribute: "${tappedOption.attributeName}" | Selected ID: $tappedValueId',
        );
        debugPrint(
          '📤 [Send to Loop] Clicked attribute value id: $tappedValueId',
        );
        final comboFromLoop = currentProduct.findMatchingComboByClickedValueId(tappedValueId);
        debugPrint(
          '📥 [Get from Loop] Matched: ${comboFromLoop != null} | Variant ID: ${comboFromLoop?.variantId}',
        );

        if (comboFromLoop != null) {
          // Step 2: Extract available combination ids from the combo (list of value ids in this combo).
          final availableCombinationIds = comboFromLoop.values.map((v) => v.id).toSet();
          debugPrint(
            '📋 [Available Combination IDs] From loop response: $availableCombinationIds',
          );
          // Show detailed breakdown of each attribute in the combo
          debugPrint(
            '   📋 [Combo Details]',
          );
          for (final comboVal in comboFromLoop.values) {
            final attrSlug = ProductDetails.attributeNameToComboSlug(
              comboVal.value.split('-').first.trim(),
            );
            debugPrint(
              '      - Attribute: $attrSlug | Value ID: ${comboVal.id} | Value: "${comboVal.value}"',
            );
          }

          // Step 3: Normalize ONLY the clicked attribute id from combo - don't change other attributes.
          // This ensures only the clicked attribute is updated, other attributes stay as user selected them.
          var productWithNewSelection = currentProduct.copyWith(variantAttributeOptions: recomputedOptions);
          productWithNewSelection = _normalizeAttributeIdsFromCombo(productWithNewSelection, comboFromLoop, clickedAttributeSlug: tappedAttrSlug);

          // Step 4: Get full current selection (all selected attribute ids) with normalized ids.
          // Build selection that includes ALL attributes from combo, even if selectedValue is empty.
          final fullSelection = productWithNewSelection.getSelectedAttributeSlugToValueId();
          // Also include attributes from combo that might not be in selectedValue (use isSelected flag)
          final comboBasedSelection = <String, int>{};
          for (final comboVal in comboFromLoop.values) {
            final comboValueStr = comboVal.value;
            final idx = comboValueStr.indexOf('-');
            if (idx <= 0) continue;
            final attrPart = comboValueStr.substring(0, idx).trim();
            final attrSlug = ProductDetails.attributeNameToComboSlug(attrPart);
            if (attrSlug.isEmpty) continue;
            comboBasedSelection[attrSlug] = comboVal.id;
          }
          // Merge: combo-based selection takes precedence (source of truth), then add any other selected
          final mergedSelection = <String, int>{...comboBasedSelection, ...fullSelection};
          final selectedIds = mergedSelection.values.toSet();
          debugPrint(
            '📋 [Selected IDs] Current selection (all attributes): $selectedIds',
          );
          // Show detailed breakdown of each selected attribute
          debugPrint(
            '   📋 [Selection Details]',
          );
          debugPrint(
            '   📋 [From Combo] Combo-based selection: $comboBasedSelection',
          );
          debugPrint(
            '   📋 [From Options] variantAttributeOptions selection: $fullSelection',
          );
          debugPrint(
            '   📋 [Merged] Final merged selection: $mergedSelection',
          );
          for (final entry in mergedSelection.entries) {
            final source = comboBasedSelection.containsKey(entry.key) ? 'combo' : 'options';
            debugPrint(
              '      - Attribute: ${entry.key} | Selected ID: ${entry.value} (from $source)',
            );
          }

          // Step 5: Validate: compare selected ids (with normalized attribute ids) with available combination ids.
          // Exclude the clicked attribute from validation (we're validating OTHER attributes match)
          // Get clicked attribute slug
          final clickedAttrSlug = tappedAttrSlug; // Already computed earlier in the function
          // Remove clicked attribute from mergedSelection for validation
          final selectedForValidation = Map<String, int>.from(mergedSelection);
          selectedForValidation.remove(clickedAttrSlug);
          final selectedIdsForValidation = selectedForValidation.values.toSet();
          // Remove clicked attribute ID from available combination IDs
          final clickedAttributeIdInCombo = comboBasedSelection[clickedAttrSlug];
          final availableIdsForValidation = clickedAttributeIdInCombo != null
              ? availableCombinationIds.where((id) => id != clickedAttributeIdInCombo).toSet()
              : availableCombinationIds;
          
          final idsMatch = selectedIdsForValidation.length == availableIdsForValidation.length &&
              selectedIdsForValidation.containsAll(availableIdsForValidation);
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );
          debugPrint(
            '✅ [Validate] Comparing (excluding clicked attribute "$clickedAttrSlug", ID: $clickedAttributeIdInCombo):',
          );
          debugPrint(
            '   Selected IDs (all):     $selectedIds',
          );
          debugPrint(
            '   Selected IDs (for validation, excluding clicked):     $selectedIdsForValidation',
          );
          debugPrint(
            '   Available IDs (all):    $availableCombinationIds',
          );
          debugPrint(
            '   Available IDs (for validation, excluding clicked):    $availableIdsForValidation',
          );
          debugPrint(
            '   Match Result:     ${idsMatch ? "✅ MATCH" : "❌ NO MATCH"}',
          );
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );

          if (idsMatch) {
            // Exact match → use combo for stock badge (in stock, low stock, etc.)
            matchedAttrCombo = comboFromLoop;
            final qty = comboFromLoop.quantityAvailable;
            final hasStock = comboFromLoop.inStock && qty > 0;
            newInStock = hasStock;
            debugPrint(
              '📦 [AttrCombos] ✅ Match! variantId=${comboFromLoop.variantId}, '
              'qty=$qty, inStock=${comboFromLoop.inStock} → newInStock=$newInStock',
            );
          } else {
            // No match → out of stock
            matchedAttrCombo = null;
            newInStock = false;
            debugPrint(
              '📦 [AttrCombos] ❌ No match: selectedIdsForValidation=$selectedIdsForValidation ≠ availableIdsForValidation=$availableIdsForValidation → out of stock',
            );
          }
        } else {
          // Fallback to variant_combinations when no matching attribute combo is found.
          if (matching.isEmpty) {
            newInStock = false;
            debugPrint(
              '📦 No matching variants for current selection (size="$newSelectedSize", color="$newSelectedColor"). '
              'Marking inStock = false for this combination.',
            );
          } else {
            // Don't set inStock from variant matches - only set from combination validation
            // Keep newInStock as false until combination matches exactly
            newInStock = false; // Don't show in stock until combination matches
            debugPrint(
              '📦 Found ${matching.length} matching variants for current selection '
              '(size="$newSelectedSize", color="$newSelectedColor"), '
              'but inStock=false until combination matches exactly',
            );
          }
        }
      } catch (e) {
        debugPrint(
          '⚠️ [AttrCombos] Error resolving selection from attribute combinations: $e',
        );
        // On error, fall back to previous variant_combinations based logic.
        if (matching.isEmpty) {
          newInStock = false;
          debugPrint(
            '📦 No matching variants for current selection (size="$newSelectedSize", color="$newSelectedColor"). '
            'Marking inStock = false for this combination.',
          );
        } else {
          // Don't set inStock from variant matches - only set from combination validation
          // Keep newInStock as false until combination matches exactly
          newInStock = false; // Don't show in stock until combination matches
          debugPrint(
            '⚠️ [AttrCombos] Error: Found ${matching.length} matching variants, '
            'but inStock=false until combination matches exactly',
          );
        }
      }
    } else {
      // No normalized attribute combinations present → keep existing logic.
      if (matching.isEmpty) {
        newInStock = false;
        debugPrint(
          '📦 No matching variants for current selection (size="$newSelectedSize", color="$newSelectedColor"). '
          'Marking inStock = false for this combination.',
        );
      } else {
        final hasAvailable = matching.any(_isVariantInStock);
        newInStock = hasAvailable;
        debugPrint(
          '📦 Found ${matching.length} matching variants for current selection '
          '(size="$newSelectedSize", color="$newSelectedColor"), '
          'availableMatches=$hasAvailable → inStock=$newInStock',
        );
      }
    }
    
    // Step 6: If size was changed, update color availability
    
    List<ColorOption> updatedColorOptions = currentProduct.colorOptions;
    final isSizeAttribute = tappedOption.attributeName.toLowerCase() == 'size' ||
                           tappedOption.attributeName.toLowerCase() == currentProduct.primaryVariantLabel.toLowerCase() ||
                           tappedOption.attributeName.toLowerCase().contains('size');
    
    if (isSizeAttribute && newSelectedSize.isNotEmpty) {
      debugPrint('🔍 ========== UPDATING COLOR AVAILABILITY FOR SIZE ==========');
      debugPrint('🔍 Selected size: "$newSelectedSize"');
      
      // Helper functions
      bool _containsArabic(String text) {
        if (text.isEmpty) return false;
        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        return arabicRegex.hasMatch(text);
      }
      
      String normalize(String s) => s.toLowerCase().trim();
      
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
      
      // Get English name for selected size from variantAttributeOptions
      // CRITICAL: Must match SIZE attribute, not BRAND or other attributes
      String? selectedSizeEnglishName;
      for (final opt in recomputedOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        // Only match actual SIZE attributes, not BRAND or other attributes
        final isSizeAttribute = (attrNameLower == 'size' || 
                                attrNameLower == 'القياس' ||
                                (currentProduct.primaryVariantLabel.isNotEmpty && 
                                 attrNameLower == currentProduct.primaryVariantLabel.toLowerCase())) &&
                               attrNameLower != 'brand' &&
                               attrNameLower != 'العلامة التجارية';
        
        if (isSizeAttribute && opt.selectedValue.isNotEmpty) {
          selectedSizeEnglishName = opt.selectedValue; // Should be English from model
          debugPrint('📏 Found size name from variantAttributeOptions: attribute="$attrNameLower", value="$selectedSizeEnglishName"');
          break;
        }
      }
      
      // If not found, use the tapped value name when this event was for size
      if (selectedSizeEnglishName == null || selectedSizeEnglishName.isEmpty) {
        if (tappedOption.attributeName.toLowerCase().contains('size') &&
            tappedValue.name.isNotEmpty && !_containsArabic(tappedValue.name)) {
          selectedSizeEnglishName = tappedValue.name;
          debugPrint('📏 Using tapped value name as size: "$selectedSizeEnglishName"');
        } else {
          selectedSizeEnglishName = newSelectedSize;
          debugPrint('📏 Fallback: Using newSelectedSize: "$selectedSizeEnglishName"');
        }
      }
      
      final String selectedSizeForMatching = selectedSizeEnglishName;
      debugPrint('📏 Using size for matching: "$selectedSizeForMatching"');
      
      // Build color availability map for this size
      final Map<String, bool> colorAvailabilityMap = {};
      for (final v in currentProduct.variantCombinations) {
        // Check if variant matches the selected size
        bool primaryMatch = v.hasAttributeValue('SIZE', selectedSizeForMatching) ||
                           v.hasAttributeValue('size', selectedSizeForMatching) ||
                           v.hasAttributeValue('Size', selectedSizeForMatching);
        
        if (!primaryMatch && currentProduct.primaryVariantLabel.isNotEmpty) {
          primaryMatch = v.hasAttributeValue(currentProduct.primaryVariantLabel, selectedSizeForMatching);
        }
        
        if (!primaryMatch) {
          primaryMatch = v.hasAttributeValue('BRAND', selectedSizeForMatching) ||
                        v.hasAttributeValue('brand', selectedSizeForMatching) ||
                        v.hasAttributeValue('Brand', selectedSizeForMatching);
        }
        
        if (!primaryMatch) {
          for (final attr in v.attributes) {
            final attrName = attr.attributeName.toLowerCase();
            final attrValue = attr.valueName;
            final isSizeAttribute = attrName.contains('size') ||
                                   attrName == currentProduct.primaryVariantLabel.toLowerCase() ||
                                   attrName == 'brand' ||
                                   attrName == 'القياس';
            if (isSizeAttribute && normalize(attrValue) == normalize(selectedSizeForMatching)) {
              primaryMatch = true;
              break;
            }
          }
        }
        
        if (!primaryMatch) continue;
        
        final colorValue = getVariantColorValue(v);
        if (colorValue != null && colorValue.isNotEmpty) {
          final normalizedColor = normalize(colorValue);
          final isInStock = _isVariantInStock(v);
          
          if (!colorAvailabilityMap.containsKey(normalizedColor)) {
            colorAvailabilityMap[normalizedColor] = isInStock;
          } else if (isInStock) {
            colorAvailabilityMap[normalizedColor] = true;
          }
          
          // CRITICAL: Store by ColorOption ID (not variant value_id)
          // The variant has value_id (e.g., 5418), but ColorOption has id (e.g., 224)
          // We need to map the variant's color value name to ColorOption.id
          String? variantColorValueId;
          String? variantColorValueName;
          for (final attr in v.attributes) {
            final attrName = attr.attributeName.toLowerCase();
            if (attrName == 'color name' || attrName == 'color' || attrName == 'colour' || attrName == 'اللون') {
              variantColorValueId = attr.valueId;
              variantColorValueName = attr.valueName;
              break;
            }
          }
          
          // Find the ColorOption that matches this variant's color value
          if (variantColorValueName != null) {
            final normalizedVariantColorName = normalize(variantColorValueName);
            for (final colorOpt in currentProduct.colorOptions) {
              // Match by checking if variant color value name matches ColorOption's displayName or name
              final colorOptDisplayNormalized = colorOpt.displayName != null ? normalize(colorOpt.displayName!) : '';
              final colorOptNameNormalized = normalize(colorOpt.name);
              
              // If variant color value matches ColorOption displayName (Arabic) or name (English)
              if (normalizedVariantColorName == colorOptDisplayNormalized || 
                  normalizedVariantColorName == colorOptNameNormalized ||
                  (colorOpt.name.startsWith('COLOR_ID_') && colorOptDisplayNormalized == normalizedVariantColorName)) {
                // Use ColorOption.id (e.g., 224) not variant value_id (e.g., 5418)
                final colorIdKey = 'COLOR_ID_${colorOpt.id}';
                if (!colorAvailabilityMap.containsKey(colorIdKey)) {
                  colorAvailabilityMap[colorIdKey] = isInStock;
                } else if (isInStock) {
                  colorAvailabilityMap[colorIdKey] = true;
                }
                debugPrint('🔍 Mapped variant color "$variantColorValueName" (variant_value_id=$variantColorValueId) to ColorOption ID ${colorOpt.id}');
                break;
              }
            }
            
            // Also store by variant's value_id as fallback (in case we can't match by name)
            if (variantColorValueId != null) {
              final variantColorIdKey = 'COLOR_ID_$variantColorValueId';
              if (!colorAvailabilityMap.containsKey(variantColorIdKey)) {
                colorAvailabilityMap[variantColorIdKey] = isInStock;
              } else if (isInStock) {
                colorAvailabilityMap[variantColorIdKey] = true;
              }
            }
          }
        }
      }
      
      debugPrint('🔍 Color availability map for size "$selectedSizeForMatching": ${colorAvailabilityMap.entries.map((e) => '${e.key}:${e.value}').toList()}');
      
        // Update color options with availability
        updatedColorOptions = currentProduct.colorOptions.map((color) {
        String colorNameForMatching = color.name; // Use English name from ColorOption
        
        // If name is COLOR_ID_X, try to get from variantAttributeOptions
        if (colorNameForMatching.startsWith('COLOR_ID_')) {
          for (final opt in recomputedOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if (attrNameLower == 'color name' || attrNameLower == 'color' || attrNameLower == 'colour' || attrNameLower == 'اللون') {
              try {
                final matchedValue = opt.values.firstWhere((v) => v.id == color.id);
                if (!_containsArabic(matchedValue.name)) {
                  colorNameForMatching = matchedValue.name;
                  break;
                }
              } catch (e) {
                // ID not found, continue
              }
            }
          }
        }
        
        // Try multiple matching strategies (works for both English and Arabic)
        final normalizedColorName = normalize(colorNameForMatching);
        bool isAvailable = false;
        
        // Strategy 1: Direct name match (normalized)
        isAvailable = colorAvailabilityMap[normalizedColorName] ?? false;
        if (isAvailable) {
          debugPrint('🎨 Color "${color.displayNameOrName}" (ID: ${color.id}): Found via direct name match "$normalizedColorName"');
        }
        
        // Strategy 2: ID-based matching for COLOR_ID_X (CRITICAL for Arabic)
        if (!isAvailable && color.name.startsWith('COLOR_ID_')) {
          isAvailable = colorAvailabilityMap[color.name] ?? false;
          if (isAvailable) {
            debugPrint('🎨 Color "${color.displayNameOrName}" (ID: ${color.id}): Found via ID key "${color.name}"');
          }
        }
        
        // Strategy 3: Match by displayName (Arabic) if name is COLOR_ID_X
        if (!isAvailable && color.name.startsWith('COLOR_ID_') && color.displayName != null) {
          final normalizedDisplayName = normalize(color.displayName!);
          isAvailable = colorAvailabilityMap[normalizedDisplayName] ?? false;
          if (isAvailable) {
            debugPrint('🎨 Color "${color.displayNameOrName}" (ID: ${color.id}): Found via displayName match "$normalizedDisplayName"');
          }
        }
        
        // Strategy 4: Flexible name matching (partial/contains)
        if (!isAvailable && colorAvailabilityMap.isNotEmpty) {
          for (final entry in colorAvailabilityMap.entries) {
            final normalizedMapColor = entry.key;
            // Skip ID-based keys for name matching (already tried above)
            if (normalizedMapColor.startsWith('COLOR_ID_')) continue;
            // Try exact match, partial match, or contains match
            if (normalizedColorName == normalizedMapColor ||
                normalizedColorName.contains(normalizedMapColor) ||
                normalizedMapColor.contains(normalizedColorName)) {
              isAvailable = entry.value;
              if (isAvailable) {
                debugPrint('🎨 Color "${color.displayNameOrName}" (ID: ${color.id}): Found via flexible matching "$normalizedColorName" ~= "$normalizedMapColor"');
                break;
              }
            }
          }
        }
        
        // Strategy 5: Try matching displayName (Arabic) with variant color names
        if (!isAvailable && color.displayName != null) {
          final normalizedDisplayName = normalize(color.displayName!);
          for (final entry in colorAvailabilityMap.entries) {
            final normalizedMapColor = entry.key;
            if (normalizedMapColor.startsWith('COLOR_ID_')) continue;
            if (normalizedDisplayName == normalizedMapColor ||
                normalizedDisplayName.contains(normalizedMapColor) ||
                normalizedMapColor.contains(normalizedDisplayName)) {
              isAvailable = entry.value;
              if (isAvailable) {
                debugPrint('🎨 Color "${color.displayNameOrName}" (ID: ${color.id}): Found via displayName flexible matching "$normalizedDisplayName" ~= "$normalizedMapColor"');
                break;
              }
            }
          }
        }
        
        // CRITICAL: Only mark as selected if it's available AND matches newSelectedColor
        // Unavailable colors should NEVER be selected
        final bool isSelected = isAvailable && 
                               newSelectedColor.isNotEmpty &&
                               normalize(colorNameForMatching) == normalize(newSelectedColor);
        
        return ColorOption(
          id: color.id,
          name: color.name,
          displayName: color.displayName,
          code: color.code,
          images: color.images,
          isSelected: isSelected, // CRITICAL: Only true if available AND matches newSelectedColor
          isAvailable: isAvailable,
        );
      }).toList();
      
      debugPrint('🔍 Updated ${updatedColorOptions.length} color options for size "$selectedSizeForMatching"');
      
      // If current selected color is unavailable, find first available color
      if (newSelectedColor.isNotEmpty) {
        final normalizedCurrentColor = normalize(newSelectedColor);
        bool currentColorIsAvailable = false;
        for (final colorOpt in updatedColorOptions) {
          final colorNameFromOpt = colorOpt.name;
          if (normalize(colorNameFromOpt) == normalizedCurrentColor && colorOpt.isAvailable) {
            currentColorIsAvailable = true;
            break;
          }
        }
        
        if (!currentColorIsAvailable) {
          debugPrint('⚠️ Current color "$newSelectedColor" is not available for size "$selectedSizeForMatching", but keeping selected color (no auto-switch)');
          // Keep the selected color even if not available - don't auto-switch to first available
        }
      }
    }

    // CRITICAL: Sync selectedHeelHeightCm and selectedMaterial from recomputedOptions.
    // When user taps HEIGHT (e.g. 2.8 cm), FilterVariantsByAttributeEvent updates
    // variantAttributeOptions but previously did NOT update selectedHeelHeightCm.
    // _findSelectedVariant then overwrote HEIGHT with old selectedHeelHeightCm (e.g. 4.0),
    // matching the wrong variant and showing wrong stock. Same for material.
    double? newSelectedHeelHeightCm = currentProduct.selectedHeelHeightCm;
    String? newSelectedMaterial = currentProduct.selectedMaterial;
    for (final opt in recomputedOptions) {
      final attrLower = opt.attributeName.toLowerCase();
      if ((attrLower == 'height' || attrLower == 'heel height') &&
          opt.selectedValue.isNotEmpty) {
        final parsed = double.tryParse(
          opt.selectedValue.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (parsed != null) {
          newSelectedHeelHeightCm = parsed;
          debugPrint(
            '👠 FilterVariantsByAttribute: synced selectedHeelHeightCm=$parsed from HEIGHT option',
          );
          break;
        }
      }
      if ((attrLower == 'material' || attrLower == 'material name') &&
          opt.selectedValue.isNotEmpty) {
        newSelectedMaterial = opt.selectedValue;
        break;
      }
    }

    // Step 7: build updated product with new selections (keep current images; they change only on color)
    var updatedProduct = currentProduct.copyWith(
      variantAttributeOptions: recomputedOptions,
      colorOptions: updatedColorOptions,
      images: List<String>.from(currentProduct.images),
      selectedSize: newSelectedSize,
      selectedColor: newSelectedColor,
      selectedHeelHeightCm: newSelectedHeelHeightCm,
      selectedMaterial: newSelectedMaterial,
      inStock: newInStock,
    );
    
    // Step 7: sync quantity & stock with the matched variant (if any).
    // Prefer matchedAttrCombo from attribute_value_combinations when available so
    // every attribute click drives quantity from the same filter source.
    int nextQuantity = blocState.quantity;
    final VariantCombination? selectedVariant = _findSelectedVariant(updatedProduct);

    // When Step 5 has already determined that the current combination has NO
    // in-stock variants (newInStock == false), we must respect that decision
    // and force the UI to show this combination as out of stock, even if a
    // fallback variant is found by _findSelectedVariant (which may ignore
    // non-primary attributes such as WIDTH/MEASUREMENT).
    if (!newInStock) {
      nextQuantity = 1;
      updatedProduct = updatedProduct.copyWith(
        inStock: false,
        // Explicitly treat this combination as having zero available quantity
        // so badges/buttons behave correctly.
        selectedVariantQuantityAvailable: 0,
      );
    } else if (matchedAttrCombo != null) {
      // Use normalized attribute combination as single source of truth for stock,
      // and also sync images to this concrete variant (same behavior as color flow).
      final double? quantityAvailable = matchedAttrCombo.quantityAvailable;
      bool variantInStock = matchedAttrCombo.inStock;

      // Update images to match this exact variant so the whole page clearly
      // reflects the newly selected combination without requiring a color change.
      final String variantIdForImages = matchedAttrCombo.variantId.toString();
      updatedProduct = updatedProduct.withImagesForVariant(variantIdForImages);

      if (quantityAvailable != null) {
        // Check if there's already an item in cart with this variant ID
        int existingCartQuantity = 0;
        final variantIdToCheck = matchedAttrCombo.variantId;
        if (cartBloc.state is CartLoaded) {
          final cartState = cartBloc.state as CartLoaded;
          try {
            final existingItem = cartState.cartItems.firstWhere(
              (item) => item.product.id.toString() == variantIdToCheck.toString(),
            );
            existingCartQuantity = existingItem.quantity;
          } catch (e) {
            // Item not found in cart, existingCartQuantity remains 0
          }
        }

        final maxAllowed = quantityAvailable.toInt();
        final available = maxAllowed - existingCartQuantity;

        if (maxAllowed <= 0 || available <= 0) {
          // No stock for this combination
          variantInStock = false;
          nextQuantity = 1;
        } else {
          // Clamp to available quantity (accounting for cart items)
          if (nextQuantity > available) {
            nextQuantity = available;
          }
          if (nextQuantity <= 0) {
            nextQuantity = 1;
          }
        }

        debugPrint(
          '🔍 [AttrCombos] Filter variant: variantId=${matchedAttrCombo.variantId}, '
          'totalAvailable=$maxAllowed, inCart=$existingCartQuantity, available=$available, '
          'adjustedQty=$nextQuantity',
        );
      }

      updatedProduct = updatedProduct.copyWith(
        inStock: variantInStock,
        selectedVariantQuantityAvailable:
            variantInStock ? matchedAttrCombo.quantityAvailable.toInt() : 0,
      );
      // Images update only on color change; do not change images in FilterVariantsByAttribute.
    } else if (selectedVariant != null) {
      final double? quantityAvailable = selectedVariant.quantityAvailable;
      bool variantInStock = selectedVariant.inStock;
      
      if (quantityAvailable != null) {
        // Check if there's already an item in cart with this variant ID
        int existingCartQuantity = 0;
        final variantIdToCheck = selectedVariant.variantId;
        if (cartBloc.state is CartLoaded) {
          final cartState = cartBloc.state as CartLoaded;
          try {
            final existingItem = cartState.cartItems.firstWhere(
              (item) => item.product.id == variantIdToCheck,
            );
            existingCartQuantity = existingItem.quantity;
          } catch (e) {
            // Item not found in cart, existingCartQuantity remains 0
          }
        }
        
        final maxAllowed = quantityAvailable.toInt();
        final available = maxAllowed - existingCartQuantity;
        
        if (maxAllowed <= 0 || available <= 0) {
          // No stock for this combination
          variantInStock = false;
          nextQuantity = 1;
        } else {
          // Clamp to available quantity (accounting for cart items)
          if (nextQuantity > available) {
            nextQuantity = available;
          }
          if (nextQuantity <= 0) {
            nextQuantity = 1;
          }
        }
        
        debugPrint('🔍 Filter variant: variantId=${selectedVariant.variantId}, totalAvailable=$maxAllowed, inCart=$existingCartQuantity, available=$available, adjustedQty=$nextQuantity');
      }
      
      updatedProduct = updatedProduct.copyWith(
        inStock: variantInStock,
        selectedVariantQuantityAvailable: variantInStock
            ? selectedVariant.quantityAvailable?.toInt()
            : 0,
      );
      // Images update only on color change; do not change images in FilterVariantsByAttribute.
    } else {
      // No specific variant matched but newInStock is true (rare fallback case).
      // Keep inStock as computed in Step 5 and clear badge quantity.
      updatedProduct = updatedProduct.copyWith(
        inStock: newInStock,
        selectedVariantQuantityAvailable: null,
      );
    }

    // Debug: log final stock/quantity before emitting so we can verify UI sync
    debugPrint(
      '📦 [Filter][Emit] prev.inStock=${currentProduct.inStock}, '
      'prev.qty=${currentProduct.selectedVariantQuantityAvailable} → '
      'new.inStock=${updatedProduct.inStock}, '
      'new.qty=${updatedProduct.selectedVariantQuantityAvailable}, '
      'nextQuantity=$nextQuantity',
    );
    debugPrint('🔴 [FilterVariantsByAttribute] EMITTING state: selectedSize="${updatedProduct.selectedSize}" selectedColor="${updatedProduct.selectedColor}"');
    for (final opt in updatedProduct.variantAttributeOptions) {
      debugPrint('🔴 [FilterVariantsByAttribute]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
    }
    debugPrint('🔴 [FilterVariantsByAttribute] ═══════════════════════════════════════');

    emit(ProductDetailsLoaded(updatedProduct, quantity: nextQuantity, isAdding: false));
  }

  Future<void> _onLoadProductDetails(
    LoadProductDetails event,
    Emitter<ProductDetailsState> emit,
  ) async {
    emit(ProductDetailsLoading());
    
    debugPrint('🔄 ProductDetailsBloc: Loading product details');
    debugPrint('  - Product ID: ${event.productId}');
    debugPrint('  - Product Type: ${event.productType}');
    debugPrint('  - Product ID Type: ${event.productId.runtimeType}');
    debugPrint('  - Product Type Type: ${event.productType.runtimeType}');
    
    final result = await getProductDetails(event.productId, productType: event.productType);
    
    result.fold(
      (failure) => emit(ProductDetailsError(failure.message)),
      (productDetails) {
        debugPrint('🔴 [_onLoadProductDetails] ═══════════════════════════════════════');
        debugPrint('🔴 [_onLoadProductDetails] PRODUCT LOADED - setting initial selection (NO USER TAP)');
        debugPrint('🔢 Setting initial quantity to 1 for product: ${productDetails.name}');
        
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
        
        String normalize(String s) => s.toLowerCase().trim();
        
        // Update size options to reflect availability based on ALL variant combinations
        final updatedSizeOptions = productDetails.sizeOptions.map((size) {
          bool hasInStockVariant = false;
          
          for (final v in productDetails.variantCombinations) {
            final bool sizeMatch = v.hasAttributeValue(productDetails.primaryVariantLabel, size.name) ||
                                  v.hasAttributeValue('size', size.name) ||
                                  v.hasAttributeValue('SIZE', size.name);
            if (!sizeMatch) continue;
            
            // Check stock (treat null quantity as available when inStock=true)
            final isInStock = _isVariantInStock(v);
            if (isInStock) {
              hasInStockVariant = true;
              break;
            }
          }
          
          return SizeOption(
            id: size.id,
            name: size.name,
            isAvailable: hasInStockVariant,
            isRecommended: size.isRecommended,
            isSelected: size.isSelected,
          );
        }).toList();
        
        // Stored selection: at initial load use first value of each attribute when empty.
        // These variables are used to filter and get the variant (inStock, quantity_available).
        // On any attribute click we update only the clicked attribute and keep the rest.
        String? initialSelectedSize = productDetails.selectedSize;
        if (initialSelectedSize.isEmpty) {
          for (final opt in productDetails.variantAttributeOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if ((attrNameLower == 'size' ||
                 attrNameLower == productDetails.primaryVariantLabel.toLowerCase()) &&
                opt.selectedValue.isNotEmpty) {
              initialSelectedSize = opt.selectedValue;
              break;
            }
          }
        }
        if ((initialSelectedSize ?? '').isEmpty && productDetails.sizeOptions.isNotEmpty) {
          initialSelectedSize = productDetails.sizeOptions.first.name;
        }
        if ((initialSelectedSize ?? '').isEmpty) {
          for (final opt in productDetails.variantAttributeOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if ((attrNameLower == 'size' ||
                 attrNameLower == productDetails.primaryVariantLabel.toLowerCase()) &&
                opt.values.isNotEmpty) {
              initialSelectedSize = opt.values.first.name;
              break;
            }
          }
        }

        String initialSelectedColor = productDetails.selectedColor;
        if (initialSelectedColor.isEmpty && productDetails.colorOptions.isNotEmpty) {
          initialSelectedColor = productDetails.colorOptions.first.name;
        }
        if (initialSelectedColor.isEmpty) {
          for (final opt in productDetails.variantAttributeOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if ((attrNameLower == 'color name' || attrNameLower == 'color' ||
                 attrNameLower == 'colour' || attrNameLower == 'اللون') &&
                opt.values.isNotEmpty) {
              initialSelectedColor = opt.values.first.name;
              break;
            }
          }
        }

        // Declare material/height early so we can log them; they are updated in the loop below.
        String? initialSelectedMaterial = productDetails.selectedMaterial;
        double? initialSelectedHeelHeight = productDetails.selectedHeelHeightCm;

        debugPrint(
          '🔴 [_onLoadProductDetails] Initial stored selection (first value of each attribute): '
          'color="$initialSelectedColor", size="${initialSelectedSize ?? ''}", '
          'material="${initialSelectedMaterial ?? ''}", height=${initialSelectedHeelHeight?.toStringAsFixed(1) ?? "null"}',
        );
        debugPrint('🔴 [_onLoadProductDetails] ═══════════════════════════════════════');
        
        // Align variantAttributeOptions (SIZE attribute) with the initial selected size
        final List<VariantAttributeOption> updatedVariantAttributeOptions =
            productDetails.variantAttributeOptions.map((opt) {
          final attrNameLower = opt.attributeName.toLowerCase();
          final bool isSizeAttribute =
              attrNameLower == 'size' ||
              attrNameLower == 'القياس' ||
              attrNameLower == productDetails.primaryVariantLabel.toLowerCase();
          final bool isColorAttribute =
              attrNameLower == 'color name' ||
              attrNameLower == 'color' ||
              attrNameLower == 'colour' ||
              attrNameLower == 'اللون';

          // 1) For SIZE: align selection with initialSelectedSize from model
          if (isSizeAttribute &&
              initialSelectedSize != null &&
              initialSelectedSize.isNotEmpty) {
            final normalizedTarget = initialSelectedSize.toLowerCase().trim();
            final newValues = opt.values.map((v) {
              final isSelected =
                  v.name.toLowerCase().trim() == normalizedTarget;
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: isSelected,
              );
            }).toList();

            return VariantAttributeOption(
              attributeName: opt.attributeName,
              values: newValues,
              selectedValue: initialSelectedSize,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
          }

          // 1b) For COLOR: align selection with initialSelectedColor (stored selection)
          if (isColorAttribute &&
              initialSelectedColor.isNotEmpty &&
              opt.values.isNotEmpty) {
            final normalizedTarget = initialSelectedColor.toLowerCase().trim();
            final newValues = opt.values.map((v) {
              final isSelected =
                  v.name.toLowerCase().trim() == normalizedTarget;
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: isSelected,
              );
            }).toList();
            return VariantAttributeOption(
              attributeName: opt.attributeName,
              values: newValues,
              selectedValue: initialSelectedColor,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
          }

          // 2) For non-color attributes with ONLY ONE option (e.g. MATERIAL, HEIGHT, BRAND):
          //    auto-select that single option by default.
          if (!isColorAttribute && opt.values.length == 1) {
            final v = opt.values.first;
            final singleSelected = VariantAttributeValue(
              id: v.id,
              name: v.name,
              displayName: v.displayName,
              isAvailable: true,
              isSelected: true,
            );

            return VariantAttributeOption(
              attributeName: opt.attributeName,
              values: [singleSelected],
              selectedValue: v.name,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
          }

          // 3) Otherwise, keep as-is
          return opt;
        }).toList();
        
        // Update color options to reflect availability
        // If a size is selected, check availability for that size; otherwise check all variants
        List<ColorOption> updatedColorOptions = productDetails.colorOptions.map((color) {
          // Get the actual color name from variantAttributeOptions (for matching)
          String? colorNameForMatching;
          for (final opt in productDetails.variantAttributeOptions) {
            final attrNameLower = opt.attributeName.toLowerCase();
            if (attrNameLower == 'color name' || 
                attrNameLower == 'color' || 
                attrNameLower == 'colour' ||
                attrNameLower == 'اللون') {
              try {
                final matchedValue = opt.values.firstWhere(
                  (v) => v.id == color.id,
                );
                colorNameForMatching = matchedValue.name;
                break;
              } catch (e) {
                // ID not found, continue
              }
            }
          }
          if (colorNameForMatching == null || colorNameForMatching.isEmpty) {
            colorNameForMatching = color.name;
          }
          // Fallback for Arabic: use displayName when name is placeholder/empty
          if ((colorNameForMatching == null || colorNameForMatching.isEmpty || colorNameForMatching.startsWith('COLOR_ID_')) &&
              color.displayName != null && color.displayName!.isNotEmpty) {
            colorNameForMatching = color.displayName;
          }
          
          // Check if this color has any in-stock variants
          bool hasInStockVariant = false;
          final normalizedColorName = normalize(colorNameForMatching ?? '');
          // CRITICAL: Empty string causes "x".contains("") = true, incorrectly matching all variants (Arabic bug)
          final hasValidColorName = normalizedColorName.isNotEmpty;
          
          for (final v in productDetails.variantCombinations) {
            final variantColorName = getVariantColorValue(v);
            if (variantColorName == null) continue;
            
            final normalizedVariant = normalize(variantColorName);
            final colorMatch = hasValidColorName && normalizedVariant.isNotEmpty &&
                (normalizedVariant == normalizedColorName ||
                 (normalizedColorName.isNotEmpty && normalizedVariant.contains(normalizedColorName)) ||
                 (normalizedVariant.isNotEmpty && normalizedColorName.contains(normalizedVariant)));
            
            if (!colorMatch) continue;
            
            // If a size is selected, check if this variant matches that size
            if (initialSelectedSize != null && initialSelectedSize.isNotEmpty) {
              final bool sizeMatch = v.hasAttributeValue(productDetails.primaryVariantLabel, initialSelectedSize) ||
                                   v.hasAttributeValue('size', initialSelectedSize) ||
                                   v.hasAttributeValue('SIZE', initialSelectedSize);
              if (!sizeMatch) continue;
            }
            
            // Check stock (treat null quantity as available when inStock=true)
            final qty = v.quantityAvailable;
            final isInStock = _isVariantInStock(v);
            if (isInStock) {
              hasInStockVariant = true;
              break;
            }
          }
          
          debugPrint('🎨 Initial load: Color "${color.displayNameOrName}" (${colorNameForMatching}) - Available: $hasInStockVariant${initialSelectedSize != null && initialSelectedSize.isNotEmpty ? " (for size $initialSelectedSize)" : ""}');
          
          return ColorOption(
            id: color.id,
            name: color.name,
            displayName: color.displayName,
            code: color.code,
            images: color.images,
            isSelected: color.isSelected,
            isAvailable: hasInStockVariant,
          );
        }).toList();

        // UX rule: when there is ONLY one color option, do not disable it.
        // Even if stock heuristics consider it unavailable, we always want
        // the single color to remain selectable and not visually greyed out.
        if (updatedColorOptions.length == 1) {
          final only = updatedColorOptions.first;
          updatedColorOptions = [
            ColorOption(
              id: only.id,
              name: only.name,
              displayName: only.displayName,
              code: only.code,
              images: only.images,
              // Force it to be both available and selected for better UX.
              isSelected: true,
              isAvailable: true,
            ),
          ];
          debugPrint(
            '🎨 Single color detected on initial load → forcing available & selected: "${only.displayNameOrName}"',
          );
        }
        
        // Derive defaults for Material and Height: use first value when empty (stored selection).
        for (final opt in updatedVariantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();

          // MATERIAL: first value when empty
          final bool isMaterialAttribute =
              attrNameLower == 'material' ||
              attrNameLower == 'material name';
          if (isMaterialAttribute && opt.values.isNotEmpty) {
            if (initialSelectedMaterial == null || initialSelectedMaterial.isEmpty) {
              initialSelectedMaterial = opt.values.first.name;
            }
          }

          // HEIGHT: first value when empty, or from option's selectedValue
          final bool isHeightAttribute =
              attrNameLower == 'height' || attrNameLower == 'heel height';
          if (isHeightAttribute) {
            if (initialSelectedHeelHeight == null) {
              if (opt.selectedValue.isNotEmpty) {
                final numeric = double.tryParse(
                  opt.selectedValue.replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                if (numeric != null) {
                  initialSelectedHeelHeight = numeric;
                  debugPrint(
                    '👠 Initial HEIGHT from variantAttributeOptions.selectedValue: $numeric',
                  );
                }
              }
              if (initialSelectedHeelHeight == null && opt.values.isNotEmpty) {
                final raw = opt.values.first.name;
                final numeric = double.tryParse(
                  raw.replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                if (numeric != null) {
                  initialSelectedHeelHeight = numeric;
                }
              }
            }
          }
        }

        // Stored selection: use these four for variant filter (findVariantMatchingSelectionByValueName).
        // On attribute click we update only the clicked attribute and keep the rest.
        var updatedProduct = productDetails.copyWith(
          sizeOptions: updatedSizeOptions,
          colorOptions: updatedColorOptions,
          variantAttributeOptions: updatedVariantAttributeOptions,
          selectedColor: initialSelectedColor,
          selectedSize: initialSelectedSize ?? productDetails.selectedSize,
          selectedMaterial:
              initialSelectedMaterial ?? productDetails.selectedMaterial,
          selectedHeelHeightCm:
              initialSelectedHeelHeight ?? productDetails.selectedHeelHeightCm,
        );

        // On initial load, set material (and similar) availability from variants: enable if a variant
        // EXISTS (size+color+material), not only when in stock, so buttons are not all grey when out of stock.
        updatedProduct = _recomputeMaterialAvailabilityFromVariants(updatedProduct);

        // Debug: values we send to the filter at initial (first value of all attributes)
        final initialFilterInput = updatedProduct.getSelectedAttributesByValueName();
        debugPrint(
          '🔍 [Initial] Calling filter (findVariantMatchingSelectionByValueName) with: $initialFilterInput '
          '(at initial we use first value of all attributes: color, size, material, height)',
        );
        debugPrint(
          '########### initial selected size:"${updatedProduct.selectedSize}", '
          'material:"${updatedProduct.selectedMaterial}", heelHeight:${updatedProduct.selectedHeelHeightCm?.toStringAsFixed(1) ?? "null"}',
        );
        int initialQuantity = 1;
        
        final VariantCombination? selectedVariant = _findSelectedVariant(updatedProduct);
        if (selectedVariant != null) {
          final double? quantityAvailable = selectedVariant.quantityAvailable;
          bool variantInStock = selectedVariant.inStock;
          
          debugPrint('📦 Initial variant: variantId=${selectedVariant.variantId}, inStock=$variantInStock, quantityAvailable=$quantityAvailable');
          
          // Check stock: if quantity is known, require > 0. If unknown (null), rely on inStock flag.
          final qty = quantityAvailable;
          if (qty != null) {
            variantInStock = variantInStock && qty > 0;
          }
          
          if (qty != null && qty > 0) {
            final int maxAllowed = qty.toInt();
            // Ensure initial quantity doesn't exceed available stock
            initialQuantity = initialQuantity > maxAllowed ? maxAllowed : initialQuantity;
            if (initialQuantity <= 0) {
              initialQuantity = 1;
            }
          } else {
            initialQuantity = 1;
          }
          
          updatedProduct = updatedProduct.copyWith(
            inStock: variantInStock,
            selectedVariantQuantityAvailable: selectedVariant.quantityAvailable?.toInt(),
          );
          // Set initial images by color only (variant_id from first variant matching selected color)
          if (updatedProduct.variantImagesMap.isNotEmpty) {
            final vid = updatedProduct.variantIdForImagesByColor;
            if (vid != null && vid.isNotEmpty) {
              updatedProduct = updatedProduct.withImagesForVariant(vid);
            }
          }
        }
        
        emit(ProductDetailsLoaded(updatedProduct, quantity: initialQuantity, isAdding: false));
      },
    );
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state is ProductDetailsLoaded) {
      final currentState = state as ProductDetailsLoaded;
      final currentProduct = currentState.productDetails;
      
      // Optimistically update UI
      final updatedProduct = ProductDetails(
        id: currentProduct.id,
        brand: currentProduct.brand,
        name: currentProduct.name,
        description: currentProduct.description,
        price: currentProduct.price,
        originalPrice: currentProduct.originalPrice,
        rating: currentProduct.rating,
        reviewCount: currentProduct.reviewCount,
        images: currentProduct.images,
        colorOptions: currentProduct.colorOptions,
        sizeOptions: currentProduct.sizeOptions,
        variantAttributeOptions: currentProduct.variantAttributeOptions,
        selectedColor: currentProduct.selectedColor,
        selectedSize: currentProduct.selectedSize,
        isFavorite: !currentProduct.isFavorite,
        hasDiscount: currentProduct.hasDiscount,
        discountPercentage: currentProduct.discountPercentage,
        features: currentProduct.features,
        material: currentProduct.material,
        materialsList: currentProduct.materialsList,
        materialOptions: currentProduct.materialOptions,
        selectedMaterial: currentProduct.selectedMaterial,
        careInstructions: currentProduct.careInstructions,
        heelHeightCm: currentProduct.heelHeightCm,
        heelType: currentProduct.heelType,
        heelHeightOptions: currentProduct.heelHeightOptions,
        selectedHeelHeightCm: currentProduct.selectedHeelHeightCm,
        isPlusMember: currentProduct.isPlusMember,
        pointsEarned: currentProduct.pointsEarned,
        optionalProducts: currentProduct.optionalProducts,
        accessoryProducts: currentProduct.accessoryProducts,
        alternativeProducts: currentProduct.alternativeProducts,
        variantCombinations: currentProduct.variantCombinations,
        primaryVariantLabel: currentProduct.primaryVariantLabel,
        tags: currentProduct.tags,
      );
      
      emit(ProductDetailsLoaded(updatedProduct, quantity: currentState.quantity, isAdding: currentState.isAdding));
      
      final result = await toggleFavorite(event.productId);
      result.fold(
        (failure) {
          // Revert on failure
          emit(ProductDetailsLoaded(currentProduct, quantity: currentState.quantity, isAdding: currentState.isAdding));
          emit(ProductDetailsError(failure.message));
        },
        (_) => emit(ProductDetailsLoaded(updatedProduct, quantity: currentState.quantity, isAdding: currentState.isAdding)),
      );
    }
  }

  Future<void> _onSelectColor(
    SelectColorEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    debugPrint('🔴 [_onSelectColor] ═══════════════════════════════════════');
    debugPrint('🔴 [_onSelectColor] EVENT RECEIVED (USER TAPPED COLOR BUTTON) colorId=${event.colorId}');
    if (state is ProductDetailsLoaded) {
      final currentState = state as ProductDetailsLoaded;
      final currentProduct = currentState.productDetails;
      debugPrint('🔴 [_onSelectColor] BEFORE: selectedSize="${currentProduct.selectedSize}" selectedColor="${currentProduct.selectedColor}"');
      for (final opt in currentProduct.variantAttributeOptions) {
        debugPrint('🔴 [_onSelectColor]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
      }
      
      // Find the selected color option from colorOptions (for display purposes)
      final selectedColorOption = currentProduct.colorOptions.firstWhere(
        (color) => color.id == event.colorId,
        orElse: () => currentProduct.colorOptions.first,
      );
      
      // CRITICAL: Always use English names for matching (same logic for Arabic & English).
      // Root cause of English-only bugs: ColorOption.name can be "COLOR_ID_XXX" when API
      // doesn't fill it for English; id comparison can fail (string vs number). Fix: build
      // colorId→EnglishName from variantAttributeOptions once with robust id keys and use it first.
      String? actualColorName;

      bool containsArabic(String text) {
        if (text.isEmpty) return false;
        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        return arabicRegex.hasMatch(text);
      }

      String? getVariantColorValue(VariantCombination v) {
        const colorAttrNames = ['COLOR NAME', 'color name', 'Color Name', 'color', 'Color', 'COLOR', 'colour', 'Colour', 'اللون', 'لون'];
        for (final attrName in colorAttrNames) {
          final value = v.getAttributeValue(attrName);
          if (value != null && value.isNotEmpty) return value;
        }
        return null;
      }

      // ZERO (permanent fix): Build colorId→English name from variantAttributeOptions with robust id keys.
      // Works for both languages; avoids wrong "first" color when English API sends placeholder names.
      final Map<String, String> colorIdToEnglishName = {};
      for (final opt in currentProduct.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if (attrNameLower != 'color name' && attrNameLower != 'color' && attrNameLower != 'colour' && attrNameLower != 'اللون') continue;
        for (final val in opt.values) {
          final idStr = val.id.toString().trim();
          if (idStr.isEmpty) continue;
          if (!containsArabic(val.name) && val.name.trim().isNotEmpty) {
            colorIdToEnglishName[idStr] = val.name.trim();
          }
        }
        break;
      }
      actualColorName = colorIdToEnglishName[event.colorId] ?? colorIdToEnglishName[event.colorId.toString().trim()];
      if (actualColorName != null && actualColorName.isNotEmpty) {
        debugPrint('✅ Using colorId→name from variantAttributeOptions (locale-agnostic): "$actualColorName" for colorId=${event.colorId}');
      }

      // PRIMARY: ColorOption.name when not placeholder (e.g. English API sometimes fills it)
      if ((actualColorName == null || actualColorName.isEmpty) && selectedColorOption.name.isNotEmpty && !containsArabic(selectedColorOption.name) && !selectedColorOption.name.startsWith('COLOR_ID_')) {
        actualColorName = selectedColorOption.name;
        debugPrint('✅ Using ColorOption.name: "$actualColorName" for color ID ${event.colorId}');
      }

      // SECONDARY: Single-value lookup from variantAttributeOptions (keep for compatibility)
      if (actualColorName == null || actualColorName.isEmpty) {
        VariantAttributeOption? colorAttrOption;
        for (final opt in currentProduct.variantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();
          if (attrNameLower == 'color name' || attrNameLower == 'color' || attrNameLower == 'colour' || attrNameLower == 'اللون') {
            colorAttrOption = opt;
            break;
          }
        }
        if (colorAttrOption != null) {
          try {
            final matchedValue = colorAttrOption.values.firstWhere(
              (v) => v.id.toString().trim() == event.colorId.toString().trim(),
            );
            if (!containsArabic(matchedValue.name) && matchedValue.name.isNotEmpty) {
              actualColorName = matchedValue.name;
              debugPrint('✅ Using variantAttributeOptions (secondary): "$actualColorName" for color ID ${event.colorId}');
            }
          } catch (_) {}
        }
      }

      // TERTIARY: From variant combinations – match display name to variant color, or use colorId map (no .first)
      if (actualColorName == null || actualColorName.isEmpty || containsArabic(actualColorName)) {
        final Set<String> uniqueEnglishColorNames = {};
        for (final v in currentProduct.variantCombinations) {
          final String? variantColorName = getVariantColorValue(v);
          if (variantColorName != null && variantColorName.isNotEmpty && !containsArabic(variantColorName)) {
            uniqueEnglishColorNames.add(variantColorName);
          }
        }
        if (uniqueEnglishColorNames.isNotEmpty) {
          String? matchedEnglishName;
          final displayNorm = selectedColorOption.displayNameOrName.toLowerCase().trim();
          final isPlaceholder = selectedColorOption.name.startsWith('COLOR_ID_') || displayNorm.isEmpty;
          if (!isPlaceholder) {
            for (final v in currentProduct.variantCombinations) {
              final String? variantColorName = getVariantColorValue(v);
              if (variantColorName == null || variantColorName.isEmpty) continue;
              final vNorm = variantColorName.toLowerCase().trim();
              if (vNorm == displayNorm || vNorm.contains(displayNorm) || displayNorm.contains(vNorm)) {
                matchedEnglishName = variantColorName;
                debugPrint('✅ Matched display to variant color: "$matchedEnglishName"');
                break;
              }
            }
          }
          // When display is placeholder or no match, use colorId map (same source as ZERO) – never .first
          if (matchedEnglishName == null) {
            matchedEnglishName = colorIdToEnglishName[event.colorId] ?? colorIdToEnglishName[event.colorId.toString().trim()];
          }
          if (matchedEnglishName == null && uniqueEnglishColorNames.length == 1) {
            matchedEnglishName = uniqueEnglishColorNames.first;
          } else if (matchedEnglishName == null) {
            matchedEnglishName = uniqueEnglishColorNames.first;
            debugPrint('⚠️ Fallback to first English color (no id match): "$matchedEnglishName"');
          }
          actualColorName = matchedEnglishName;
        }
      }
      
      // Ensure we have a real English name for variant/image matching (never leave as placeholder).
      if (actualColorName == null || actualColorName.isEmpty || actualColorName.startsWith('COLOR_ID_')) {
        final fromMap = colorIdToEnglishName[event.colorId] ?? colorIdToEnglishName[event.colorId.toString().trim()];
        final fallback = selectedColorOption.name.isNotEmpty && !selectedColorOption.name.startsWith('COLOR_ID_')
            ? selectedColorOption.name
            : selectedColorOption.displayNameOrName;
        actualColorName = fromMap ?? fallback;
        if (fromMap != null) {
          debugPrint('✅ Using colorId map for final name (no placeholder): "$actualColorName"');
        } else {
          debugPrint('⚠️ Fallback name for color ID ${event.colorId}: "$actualColorName"');
        }
      }
      if (actualColorName != null && containsArabic(actualColorName)) {
        // If still Arabic, keep it but log a warning – we still allow selection for UX.
        debugPrint(
          '⚠️ actualColorName appears to be Arabic: "$actualColorName". '
          'Proceeding anyway so selection works; matching may be approximate.',
        );
      }
      
      debugPrint(
        '✅ Final color name for matching/selection: "$actualColorName" '
        '(ID: ${event.colorId}, Display: "${selectedColorOption.displayNameOrName}")',
      );
      
      final String colorNameForMatching = actualColorName;
      
      // Get the actual SIZE value from variantAttributeOptions
      // CRITICAL: variantAttributeOptions always uses English names for matching
      String? actualSize;
      for (final opt in currentProduct.variantAttributeOptions) {
        final attrNameUpper = opt.attributeName.toUpperCase();
        if ((attrNameUpper == 'SIZE' || 
             attrNameUpper.contains('SIZE') ||
             opt.attributeName.toLowerCase() == currentProduct.primaryVariantLabel.toLowerCase()) && 
            opt.selectedValue.isNotEmpty) {
          // variantAttributeOptions.selectedValue is always English (per model parsing)
          actualSize = opt.selectedValue;
          break;
        }
      }
      // Fallback: check if selectedSize is actually a size (numeric or English name)
      if (actualSize == null && currentProduct.selectedSize.isNotEmpty) {
        final sizeValue = currentProduct.selectedSize;
        // If it's numeric, it's likely English (sizes are usually numbers)
        // If it contains Arabic, try to find English equivalent from sizeOptions
        if (RegExp(r'^\d+').hasMatch(sizeValue)) {
          actualSize = sizeValue;
        } else if (containsArabic(sizeValue)) {
          // Try to find English name from sizeOptions
          for (final sizeOpt in currentProduct.sizeOptions) {
            // SizeOption.name should be English (it's used for matching)
            if (sizeOpt.name == sizeValue || sizeOpt.name.contains(sizeValue) || sizeValue.contains(sizeOpt.name)) {
              actualSize = sizeOpt.name;
              break;
            }
          }
        } else {
          // Already English
          actualSize = sizeValue;
        }
      }
      
      // Check if this color has any in-stock variants using the actual color name
      // Match using multiple possible attribute names (COLOR NAME, color, colour, اللون)
      bool hasInStockVariant = false;
      String normalize(String s) => s.toLowerCase().trim();
      
      if (actualSize != null && actualSize.isNotEmpty) {
        // Size is selected - check if this color has stock with this size
        // CRITICAL: Make size matching flexible - check multiple attribute names and use case-insensitive matching
        for (final v in currentProduct.variantCombinations) {
          // Try multiple ways to match size
          bool sizeMatch = false;
          
          // Check standard SIZE attribute
          sizeMatch = v.hasAttributeValue('SIZE', actualSize) ||
                     v.hasAttributeValue('size', actualSize) ||
                     v.hasAttributeValue('Size', actualSize);
          
          // Check primaryVariantLabel (e.g., "BRAND" for some products)
          if (!sizeMatch && currentProduct.primaryVariantLabel.isNotEmpty) {
            sizeMatch = v.hasAttributeValue(currentProduct.primaryVariantLabel, actualSize);
          }
          
          // Also check BRAND attribute (some products use brand as primary variant, e.g., "BEIRA RIO")
          if (!sizeMatch) {
            sizeMatch = v.hasAttributeValue('BRAND', actualSize) ||
                       v.hasAttributeValue('brand', actualSize) ||
                       v.hasAttributeValue('Brand', actualSize);
          }
          
          // Also try case-insensitive matching by checking all attributes
          if (!sizeMatch) {
            // Get all attribute values and check if any match (case-insensitive)
            for (final attr in v.attributes) {
              final attrName = attr.attributeName.toLowerCase();
              final attrValue = attr.valueName;
              
              // Check if this attribute is a size-related attribute
              final isSizeAttribute = attrName.contains('size') ||
                                     attrName == currentProduct.primaryVariantLabel.toLowerCase() ||
                                     attrName == 'brand' || // Some products use BRAND as primary variant
                                     attrName == 'القياس';
              
              if (isSizeAttribute && normalize(attrValue) == normalize(actualSize)) {
                sizeMatch = true;
                debugPrint('🔍 Size match found via flexible matching: attribute="$attrName", value="$attrValue" == "$actualSize"');
                break;
              }
            }
          }
          
          // Try multiple attribute name variations to find color
          final String? variantColorName = getVariantColorValue(v);
          bool colorMatch = false;
          if (variantColorName != null) {
            final normalizedVariant = normalize(variantColorName);
            final normalizedMatching = normalize(colorNameForMatching);
            // Exact match
            colorMatch = normalizedVariant == normalizedMatching;
            // If no exact match, try partial match (for cases like "بحري/بحري" vs "بحري")
            if (!colorMatch) {
              colorMatch = normalizedVariant.contains(normalizedMatching) || 
                          normalizedMatching.contains(normalizedVariant);
            }
          }
          
          if (colorMatch && !sizeMatch) {
            debugPrint('🔍 Color matches but size does not: variantColorName="$variantColorName", actualSize="$actualSize"');
            // Log variant attributes for debugging
            final sizeAttrs = v.attributes.where((attr) {
              final attrName = attr.attributeName.toLowerCase();
              return attrName.contains('size') || 
                     attrName == currentProduct.primaryVariantLabel.toLowerCase() ||
                     attrName == 'brand' ||
                     attrName == 'القياس';
            }).map((attr) => '${attr.attributeName}: ${attr.valueName}').toList();
            debugPrint('   Variant size attributes: $sizeAttrs');
          }
          
          if (sizeMatch && colorMatch) {
            // Check stock (treat null quantity as available when inStock=true)
            final qty = v.quantityAvailable;
            final isInStock = _isVariantInStock(v);
            debugPrint('🔍 Checking variant: sizeMatch=$sizeMatch, colorMatch=$colorMatch, inStock=${v.inStock}, qty=$qty, available=$isInStock');
            if (isInStock) {
              hasInStockVariant = true;
              debugPrint('✅ Found in-stock variant for color $colorNameForMatching with size/primary="$actualSize"');
              break;
            } else {
              debugPrint('⚠️ Variant found but out of stock: inStock=${v.inStock}, qty=$qty');
            }
          }
        }
        
        // If size is selected but no in-stock variant exists for this color,
        // we still allow selection for better UX (user can see images / details),
        // but we log a warning for diagnostics.
        if (!hasInStockVariant) {
          debugPrint(
            '⚠️ No in-stock variants for color $colorNameForMatching (display: ${selectedColorOption.displayNameOrName}) with size $actualSize. '
            'Proceeding with selection but product may be effectively out of stock for this combination.',
          );
        }
      } else {
        // No size selected - check if color has any in-stock variants (will adjust size later)
        for (final v in currentProduct.variantCombinations) {
          final String? variantColorName = getVariantColorValue(v);
          bool colorMatch = false;
          if (variantColorName != null) {
            final normalizedVariant = normalize(variantColorName);
            final normalizedMatching = normalize(colorNameForMatching);
            // Exact match
            colorMatch = normalizedVariant == normalizedMatching;
            // If no exact match, try partial match (for cases like "بحري/بحري" vs "بحري")
            if (!colorMatch) {
              colorMatch = normalizedVariant.contains(normalizedMatching) || 
                          normalizedMatching.contains(normalizedVariant);
            }
          }
          
          if (colorMatch) {
            debugPrint('🔍 Found color match (no size): variantColorName="$variantColorName" == colorNameForMatching="$colorNameForMatching"');
            // Check stock: must have quantity_available > 0 AND in_stock = true
            final qty = v.quantityAvailable ?? 0.0;
            final isInStock = v.inStock && qty > 0;
            debugPrint('🔍 Checking variant: colorMatch=$colorMatch, inStock=${v.inStock}, qty=$qty, available=$isInStock');
            if (isInStock) {
              hasInStockVariant = true;
              debugPrint('✅ Found in-stock variant for color $colorNameForMatching');
              break;
            }
          } else if (variantColorName != null) {
            debugPrint('🔍 Color mismatch (no size): variantColorName="$variantColorName" != colorNameForMatching="$colorNameForMatching"');
          }
        }
        
        // If no in-stock variant exists for this color at all, still allow selection
        // so the user can view the color, but log a warning.
        if (!hasInStockVariant) {
          debugPrint(
            '⚠️ No in-stock variants for color $colorNameForMatching (display: ${selectedColorOption.displayNameOrName}) with any size. '
            'Proceeding with selection but product may be effectively out of stock for this color.',
          );
        }
      }
      
      // CRITICAL: Recalculate color availability based on currently selected size
      // When color changes, we need to check if each color is available for the selected size
      List<ColorOption> updatedColorOptions = currentProduct.colorOptions.map((color) {
        // Get the English color name for matching
        String? colorNameForMatching;
        for (final opt in currentProduct.variantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();
          if (attrNameLower == 'color name' || 
              attrNameLower == 'color' || 
              attrNameLower == 'colour' ||
              attrNameLower == 'اللون') {
            try {
              final matchedValue = opt.values.firstWhere(
                (v) => v.id == color.id,
              );
              if (!containsArabic(matchedValue.name)) {
                colorNameForMatching = matchedValue.name;
                break;
              }
            } catch (e) {
              // ID not found, continue
            }
          }
        }
        if (colorNameForMatching == null || colorNameForMatching.isEmpty) {
          colorNameForMatching = color.name;
        }
        // Fallback for Arabic: use displayName when name is placeholder/empty
        if ((colorNameForMatching == null || colorNameForMatching.isEmpty || colorNameForMatching.startsWith('COLOR_ID_')) &&
            color.displayName != null && color.displayName!.isNotEmpty) {
          colorNameForMatching = color.displayName;
        }
        
        final normalizedColor = normalize(colorNameForMatching ?? '');
        // CRITICAL: Empty string causes "x".contains("") = true, incorrectly matching all variants (Arabic bug)
        final hasValidColorName = normalizedColor.isNotEmpty;
        
        // Check if this color is available for the currently selected size
        bool hasInStockVariant = false;
        if (actualSize != null && actualSize.isNotEmpty) {
          // Size is selected - check if this color has stock with this size
          for (final v in currentProduct.variantCombinations) {
            final bool sizeMatch = v.hasAttributeValue('SIZE', actualSize) ||
                                 v.hasAttributeValue('size', actualSize) ||
                                 v.hasAttributeValue(currentProduct.primaryVariantLabel, actualSize);
            if (!sizeMatch) continue;
            
            final variantColorName = getVariantColorValue(v);
            if (variantColorName == null) continue;
            
            final normalizedVariant = normalize(variantColorName);
            
            final bool colorMatch = hasValidColorName && normalizedVariant.isNotEmpty &&
                (normalizedVariant == normalizedColor ||
                 (normalizedColor.isNotEmpty && normalizedVariant.contains(normalizedColor)) ||
                 (normalizedVariant.isNotEmpty && normalizedColor.contains(normalizedVariant)));
            
            if (colorMatch) {
              final isInStock = _isVariantInStock(v);
              if (isInStock) {
                hasInStockVariant = true;
                break;
              }
            }
          }
        } else {
          // No size selected - check if color has any in-stock variants
          for (final v in currentProduct.variantCombinations) {
            final variantColorName = getVariantColorValue(v);
            if (variantColorName == null) continue;
            
            final normalizedVariant = normalize(variantColorName);
            
            final bool colorMatch = hasValidColorName && normalizedVariant.isNotEmpty &&
                (normalizedVariant == normalizedColor ||
                 (normalizedColor.isNotEmpty && normalizedVariant.contains(normalizedColor)) ||
                 (normalizedVariant.isNotEmpty && normalizedColor.contains(normalizedVariant)));
            
            if (colorMatch) {
              final isInStock = _isVariantInStock(v);
              if (isInStock) {
                hasInStockVariant = true;
                break;
              }
            }
          }
        }
        
        return ColorOption(
          id: color.id,
          name: color.name,
          displayName: color.displayName,
          code: color.code,
          images: color.images,
          isSelected: color.id == event.colorId,
          isAvailable: hasInStockVariant, // Recalculate based on selected size
        );
      }).toList();

      // CRITICAL: Recompute ALL variant attribute options based on selected color
      // This ensures all attributes (size, material, heel height, etc.) are properly
      // enabled/disabled based on what's available for the selected color
      final Map<String, String> selectedByAttribute = {};
      
      // Build current selections map (preserve existing selections except color)
      for (final opt in currentProduct.variantAttributeOptions) {
        if (opt.selectedValue.isNotEmpty) {
          final attrNameLower = opt.attributeName.toLowerCase();
          // Skip color attributes - we'll set the new color below
          if (attrNameLower != 'color name' && 
              attrNameLower != 'color' && 
              attrNameLower != 'colour' &&
              attrNameLower != 'اللون') {
            selectedByAttribute[opt.attributeName] = opt.selectedValue;
          }
        }
      }
      
      // Add selected material and heel height if they exist
      if (currentProduct.selectedMaterial != null && currentProduct.selectedMaterial!.isNotEmpty) {
        selectedByAttribute['MATERIAL NAME'] = currentProduct.selectedMaterial!;
        selectedByAttribute['material name'] = currentProduct.selectedMaterial!;
      }
      if (currentProduct.selectedHeelHeightCm != null) {
        final heightStr = currentProduct.selectedHeelHeightCm!.toStringAsFixed(1);
        selectedByAttribute['HEIGHT'] = heightStr;
        selectedByAttribute['height'] = heightStr;
      }
      
      // Update color selection in the map
      for (final opt in currentProduct.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if (attrNameLower == 'color name' || 
            attrNameLower == 'color' || 
            attrNameLower == 'colour' ||
            attrNameLower == 'اللون') {
          selectedByAttribute[opt.attributeName] = colorNameForMatching;
          // Also add common variations
          selectedByAttribute['COLOR NAME'] = colorNameForMatching;
          selectedByAttribute['color name'] = colorNameForMatching;
          selectedByAttribute['color'] = colorNameForMatching;
          selectedByAttribute['colour'] = colorNameForMatching;
          selectedByAttribute['اللون'] = colorNameForMatching;
          break;
        }
      }
      
      // Find the clicked color option and value for dynamic attribute checking
      VariantAttributeOption? clickedColorOption;
      VariantAttributeValue? clickedColorValue;
      for (final opt in currentProduct.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if (attrNameLower == 'color name' || attrNameLower == 'color' || attrNameLower == 'colour' || attrNameLower == 'اللون') {
          try {
            clickedColorValue = opt.values.firstWhere(
              (v) => v.id.toString().trim() == event.colorId.toString().trim(),
            );
            clickedColorOption = opt;
            break;
          } catch (_) {}
        }
      }
      
      // Recompute availability for ALL variant attribute options
      // CRITICAL: Only require matching on attributes that actually vary (color, size)
      // Don't require matching on attributes that are the same for all variants (material, height, brand)
      final List<VariantAttributeOption> recomputedOptions = [];
      for (final attrOption in currentProduct.variantAttributeOptions) {
        final String attributeName = attrOption.attributeName;
        final attrNameLower = attributeName.toLowerCase();

        List<VariantAttributeValue> newValues = attrOption.values.map((value) {
          bool isAvailable = false;

          // Check if this value is available in any variant combination
          // CRITICAL: Height availability must respect selected color+size - only enable
          // a height option if there exists an in-stock variant for (color, size, height).
          // This prevents incorrectly enabling e.g. "4.5" when selecting a color that has
          // no in-stock variants for that height.
          for (final combo in currentProduct.variantCombinations) {
            bool matchesRequiredAttributes = true;

            // For Height: require variant to match selected color + size AND be in stock
            // Use flexible color matching (Black/BLACK, contains) to avoid false mismatches
            final bool isHeightAttr = attrNameLower == 'height' || attrNameLower == 'heel height';
            if (isHeightAttr && colorNameForMatching.isNotEmpty && currentProduct.selectedSize.isNotEmpty) {
              final variantColor = getVariantColorValue(combo);
              final variantSize = _getComboValueForAttribute(
                currentProduct, combo, currentProduct.primaryVariantLabel,
              ) ?? _getComboValueForAttribute(currentProduct, combo, 'SIZE');
              final nvc = variantColor != null ? normalize(variantColor) : '';
              final ncm = normalize(colorNameForMatching);
              final colorMatch = variantColor != null && (nvc == ncm || nvc.contains(ncm) || ncm.contains(nvc));
              final sizeMatch = variantSize != null &&
                  normalize(variantSize) == normalize(currentProduct.selectedSize);
              if (!colorMatch || !sizeMatch || !_isVariantInStock(combo)) {
                continue; // Skip - variant doesn't match selection or is out of stock
              }
            }

            // CRITICAL FIX: Size availability should NOT be restricted by selected color.
            // Sizes should be available if they exist in ANY color variant (since stock exists for all colors).
            // Only Material/Height are product-level attributes that should be available regardless of color.
            final bool isSizeOrBrandAttribute = attrNameLower == 'size' ||
                                               attrNameLower == currentProduct.primaryVariantLabel.toLowerCase() ||
                                               attrNameLower == 'brand';
            
            // IMPORTANT: Do NOT require color matching for sizes - allow all sizes to be available
            // regardless of selected color, since stock exists for all color variants.
            // This prevents sizes from being disabled when switching colors.
            if (colorNameForMatching.isNotEmpty && isSizeOrBrandAttribute) {
              // Skip color matching for sizes - sizes should be available for all colors
              // matchesRequiredAttributes stays true, allowing size to be checked without color restriction
            }
            
            if (!matchesRequiredAttributes) continue;

            // 2. Must match the candidate value for the attribute we're checking
            String? comboVal;
            if (attrNameLower == 'color name' || 
                attrNameLower == 'color' || 
                attrNameLower == 'colour' ||
                attrNameLower == 'اللون') {
              comboVal = getVariantColorValue(combo);
            } else {
              // Use dynamic lookup (resolves API attribute name from product options)
              comboVal = _getComboValueForAttribute(currentProduct, combo, attributeName);
            }
            
            if (comboVal == null) {
              matchesRequiredAttributes = false;
            } else {
              final normalizedCombo = normalize(comboVal);
              final normalizedValue = normalize(value.name);
              
              // For color, use flexible matching
              if (attrNameLower == 'color name' || 
                  attrNameLower == 'color' || 
                  attrNameLower == 'colour' ||
                  attrNameLower == 'اللون') {
                matchesRequiredAttributes = normalizedCombo == normalizedValue ||
                                          normalizedCombo.contains(normalizedValue) ||
                                          normalizedValue.contains(normalizedCombo);
              } else if (isHeightAttr) {
                // Height: "2 CM" and "2.0" must match - use numeric comparison to prevent
                // height from being incorrectly marked unavailable and deselected on color change
                final comboNum = double.tryParse(comboVal.replaceAll(RegExp(r'[^0-9.]'), ''));
                final valueNum = double.tryParse(value.name.replaceAll(RegExp(r'[^0-9.]'), ''));
                matchesRequiredAttributes = comboNum != null && valueNum != null && comboNum == valueNum;
              } else {
                matchesRequiredAttributes = normalizedCombo == normalizedValue;
              }
            }
            
            if (!matchesRequiredAttributes) continue;

            // Check if variant is in stock (both inStock flag and quantityAvailable > 0)
            // CRITICAL: Material and Height are product-level attributes - don't require stock check
            // They should be available if they exist in any variant, regardless of stock
            final bool isMaterialOrHeight = attrNameLower == 'material' ||
                                           attrNameLower == 'material name' ||
                                           attrNameLower == 'height' ||
                                           attrNameLower == 'heel height';
            
            if (isMaterialOrHeight) {
              // Material/Height: Available if value matches (no stock check needed)
              if (matchesRequiredAttributes) {
                isAvailable = true;
                break;
              }
            } else {
              // Size/Brand/Color: Require stock check
            final qty = combo.quantityAvailable;
            final isInStock = _isVariantInStock(combo);
            if (matchesRequiredAttributes && isInStock) {
              isAvailable = true;
              break;
            }
            }
          }

          // FALLBACK: For Material/Height, if not found in variants, check if it exists in original options
          // Skip fallback for Height when color+size are selected - availability must be based on
          // actual in-stock variants for that combination (prevents incorrectly enabling e.g. 4.5)
          final bool isMaterialOrHeight = attrNameLower == 'material' ||
                                         attrNameLower == 'material name' ||
                                         attrNameLower == 'height' ||
                                         attrNameLower == 'heel height';
          final bool isHeightWithSelection = (attrNameLower == 'height' || attrNameLower == 'heel height') &&
              colorNameForMatching.isNotEmpty && currentProduct.selectedSize.isNotEmpty;
          
          if (!isAvailable && isMaterialOrHeight && !isHeightWithSelection) {
            // Check if this value exists in the original attribute options
            final originalAttrOption = currentProduct.variantAttributeOptions.firstWhere(
              (opt) => opt.attributeName == attributeName,
              orElse: () => const VariantAttributeOption(attributeName: '', values: [], selectedValue: ''),
            );
            if (originalAttrOption.attributeName.isNotEmpty) {
              // Check if this value exists in the original values
              final valueExists = originalAttrOption.values.any(
                (v) => normalize(v.name) == normalize(value.name),
              );
              if (valueExists) {
                isAvailable = true;
                debugPrint('✅ Material/Height fallback: "${value.name}" marked as available (exists in original options)');
              }
            }
          }

          // CRITICAL: Mark as selected if it matches the current selected value
          // For size, we should preserve selection even if not available for new color
          // We need to check against the actual current selection, not just selectedByAttribute
          bool isSelected = false;
          
          // Check if this value matches the current selection for this attribute
          if (attrNameLower == 'size' || 
              attrNameLower == currentProduct.primaryVariantLabel.toLowerCase() ||
              attrNameLower == 'brand') {
            // CRITICAL: For size, mark as selected if it matches, regardless of availability
            // This preserves the selected size even when changing colors
            isSelected = normalize(value.name) == normalize(currentProduct.selectedSize);
          } else if (attrNameLower == 'color name' || 
                     attrNameLower == 'color' || 
                     attrNameLower == 'colour' ||
                     attrNameLower == 'اللون') {
            isSelected = isAvailable && normalize(value.name) == normalize(colorNameForMatching);
          } else if (attrNameLower == 'material' || attrNameLower == 'material name') {
            isSelected = isAvailable && 
                        currentProduct.selectedMaterial != null &&
                        normalize(value.name) == normalize(currentProduct.selectedMaterial!);
          } else if (attrNameLower == 'height') {
            final currHeight = currentProduct.selectedHeelHeightCm;
            final valueNum = double.tryParse(value.name.replaceAll(RegExp(r'[^0-9.]'), ''));
            isSelected = isAvailable && currHeight != null && valueNum != null &&
                (valueNum - currHeight).abs() < 0.01;
          } else {
            // For other attributes, check selectedByAttribute
            isSelected = isAvailable && 
                       selectedByAttribute[attributeName]?.toLowerCase() == value.name.toLowerCase();
          }
          
          return VariantAttributeValue(
            id: value.id,
            name: value.name,
            displayName: value.displayName,
            isAvailable: isAvailable,
            isSelected: isSelected,
          );
        }).toList();

        // CRITICAL: For Material/Height/Brand, if only one option exists, ensure it's available and selected
        final bool isMaterialHeightOrBrand = attrNameLower == 'material' ||
                                            attrNameLower == 'material name' ||
                                            attrNameLower == 'height' ||
                                            attrNameLower == 'heel height' ||
                                            attrNameLower == 'brand';
        
        if (isMaterialHeightOrBrand && newValues.length == 1) {
          // Only one option exists - always make it available and selected
          final singleValue = newValues.first;
          if (!singleValue.isAvailable || !singleValue.isSelected) {
            newValues[0] = VariantAttributeValue(
              id: singleValue.id,
              name: singleValue.name,
              displayName: singleValue.displayName,
              isAvailable: true, // Force available for single option
              isSelected: true, // Auto-select single option
            );
            debugPrint('✅ Single option for ${attributeName}: "${singleValue.name}" - marked as available and selected');
          }
        }

        // Determine the selected value for this option
        String optionSelectedValue = '';
        
        // DYNAMIC: Check if this attribute is the clicked attribute (color in this function)
        final isClickedAttribute = clickedColorOption != null && 
            normalize(attributeName) == normalize(clickedColorOption!.attributeName);
        
        if (!isClickedAttribute) {
          // NOT the clicked attribute - preserve current selection exactly
          // Don't update from combo or availability - keep what user selected
          optionSelectedValue = attrOption.selectedValue; // Preserve current selection
          
          // Preserve existing isSelected flags - don't change them
          newValues = newValues.map((v) {
            // Keep existing isSelected state
            final shouldBeSelected = normalize(v.name) == normalize(optionSelectedValue) ||
                (optionSelectedValue.isEmpty && v.isSelected);
            return VariantAttributeValue(
              id: v.id,
              name: v.name,
              displayName: v.displayName,
              isAvailable: v.isAvailable,
              isSelected: shouldBeSelected,
            );
          }).toList();
          debugPrint('🔒 Attribute "${attrOption.attributeName}" preserved (not clicked): "$optionSelectedValue"');
        } else {
          // THIS IS the clicked attribute - update it normally
          // Handle special cases for different attribute types
          if (isMaterialHeightOrBrand && newValues.length == 1) {
            optionSelectedValue = newValues.first.name;
          } else if (attrNameLower == 'size' || 
              attrNameLower == currentProduct.primaryVariantLabel.toLowerCase() ||
              attrNameLower == 'brand') {
            // Size is being clicked - update it
            final currentSizeExists = newValues.any((v) => 
              normalize(v.name) == normalize(currentProduct.selectedSize));
            
            if (currentSizeExists || currentProduct.selectedSize.isNotEmpty) {
              final matchingValue = newValues.firstWhere(
                (v) => normalize(v.name) == normalize(currentProduct.selectedSize),
                orElse: () => newValues.isNotEmpty ? newValues.first : VariantAttributeValue(
                  id: '',
                  name: currentProduct.selectedSize,
                  displayName: null,
                  isAvailable: false,
                  isSelected: false,
                ),
              );
              optionSelectedValue = matchingValue.name.isNotEmpty 
                  ? matchingValue.name 
                  : currentProduct.selectedSize;
              newValues = newValues.map((v) {
                final isSelected = normalize(v.name) == normalize(optionSelectedValue);
                return VariantAttributeValue(
                  id: v.id,
                  name: v.name,
                  displayName: v.displayName,
                  isAvailable: v.isAvailable,
                  isSelected: isSelected,
                );
              }).toList();
              debugPrint('✅ Size updated (clicked): "$optionSelectedValue"');
            } else {
              optionSelectedValue = currentProduct.selectedSize;
            }
          } else if (attrNameLower == 'color name' || 
                     attrNameLower == 'color' || 
                     attrNameLower == 'colour' ||
                     attrNameLower == 'اللون') {
            // Color is being clicked - use the clicked color name
            optionSelectedValue = clickedColorValue?.name ?? colorNameForMatching;
          } else {
            // Other attributes (material, height, width, etc.) - preserve current selection
            // In _onSelectColor, only color is clicked, so other attributes should stay unchanged
            optionSelectedValue = attrOption.selectedValue;
          }
          debugPrint('✅ Attribute "${attrOption.attributeName}" updated (clicked): "$optionSelectedValue"');
        }

        recomputedOptions.add(VariantAttributeOption(
          attributeName: attributeName,
          values: newValues,
          selectedValue: optionSelectedValue,
          apiAttributeName: attrOption.apiAttributeName,
          attributeId: attrOption.attributeId,
        ));
      }
      
      // Determine next selected values from recomputed options
      // CRITICAL: Preserve current selections if they're still available, otherwise use first available
      String nextSelectedPrimary = currentProduct.selectedSize;
      String? nextSelectedMaterial = currentProduct.selectedMaterial;
      double? nextSelectedHeelHeight = currentProduct.selectedHeelHeightCm;
      
      for (int i = 0; i < recomputedOptions.length; i++) {
        final opt = recomputedOptions[i];
        final attrNameLower = opt.attributeName.toLowerCase();
        
        // DYNAMIC: Check if this attribute is the clicked attribute (color in this function)
        final isClickedAttribute = clickedColorOption != null && 
            normalize(opt.attributeName) == normalize(clickedColorOption!.attributeName);
        
        if (!isClickedAttribute) {
          // NOT the clicked attribute - skip updating it, preserve as is
          debugPrint('🔒 Attribute "${opt.attributeName}" preserved in second loop (not clicked): "${opt.selectedValue}"');
          continue; // Skip to next attribute - don't modify this one
        }
        
        // THIS IS the clicked attribute - update it normally
        // Handle size/primary variant
        if (attrNameLower == 'size' || 
            attrNameLower == currentProduct.primaryVariantLabel.toLowerCase() ||
            attrNameLower == 'brand') {
          // Size IS being clicked - update it normally
          if (opt.selectedValue.isNotEmpty && 
              normalize(opt.selectedValue) == normalize(nextSelectedPrimary)) {
            final updatedValues = opt.values.map((v) {
              final isSelected = normalize(v.name) == normalize(opt.selectedValue);
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: isSelected,
              );
            }).toList();
            
            recomputedOptions[i] = VariantAttributeOption(
              attributeName: opt.attributeName,
              values: updatedValues,
              selectedValue: opt.selectedValue,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
            nextSelectedPrimary = opt.selectedValue;
            debugPrint('✅ Size updated (clicked): "$nextSelectedPrimary"');
          } else if (opt.selectedValue.isNotEmpty) {
            nextSelectedPrimary = opt.selectedValue;
            final updatedValues = opt.values.map((v) {
              final isSelected = normalize(v.name) == normalize(opt.selectedValue);
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: isSelected,
              );
            }).toList();
            
            recomputedOptions[i] = VariantAttributeOption(
              attributeName: opt.attributeName,
              values: updatedValues,
              selectedValue: opt.selectedValue,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
            debugPrint('✅ Size updated (clicked): "$nextSelectedPrimary"');
          }
        } else if (attrNameLower == 'color name' || 
                   attrNameLower == 'color' || 
                   attrNameLower == 'colour' ||
                   attrNameLower == 'اللون') {
          // Color is being clicked - update it normally
          if (opt.selectedValue.isNotEmpty) {
            final updatedValues = opt.values.map((v) {
              final isSelected = normalize(v.name) == normalize(opt.selectedValue);
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: isSelected,
              );
            }).toList();
            
            recomputedOptions[i] = VariantAttributeOption(
              attributeName: opt.attributeName,
              values: updatedValues,
              selectedValue: opt.selectedValue,
              apiAttributeName: opt.apiAttributeName,
              attributeId: opt.attributeId,
            );
            debugPrint('✅ Color updated (clicked): "${opt.selectedValue}"');
          }
        } else if ((attrNameLower == 'material' || attrNameLower == 'material name') && isClickedAttribute) {
          if (nextSelectedMaterial != null && nextSelectedMaterial.isNotEmpty) {
            final currentMaterial = nextSelectedMaterial;
            final materialValue = opt.values.firstWhere(
              (v) => normalize(v.name) == normalize(currentMaterial),
              orElse: () => opt.values.first,
            );
            if (materialValue.isAvailable) {
              if (opt.selectedValue != currentMaterial) {
                recomputedOptions[i] = VariantAttributeOption(
                  attributeName: opt.attributeName,
                  values: opt.values,
                  selectedValue: currentMaterial,
                  apiAttributeName: opt.apiAttributeName,
                  attributeId: opt.attributeId,
                );
              }
            }
          }
        } else if (attrNameLower == 'height' && isClickedAttribute) {
          if (nextSelectedHeelHeight != null) {
            final currentHeight = nextSelectedHeelHeight;
            final heightAttrValue = opt.values.firstWhere(
              (v) {
                final vNum = double.tryParse(v.name.replaceAll(RegExp(r'[^0-9.]'), ''));
                return vNum != null && (vNum - currentHeight).abs() < 0.01;
              },
              orElse: () => opt.values.first,
            );
            if (heightAttrValue.isAvailable) {
              final valueNameToUse = heightAttrValue.name;
              if (opt.selectedValue != valueNameToUse) {
                recomputedOptions[i] = VariantAttributeOption(
                  attributeName: opt.attributeName,
                  values: opt.values,
                  selectedValue: valueNameToUse,
                  apiAttributeName: opt.apiAttributeName,
                  attributeId: opt.attributeId,
                );
              }
            }
          }
        }
      }
      
      // Update the reference to use the modified recomputedOptions

      final updatedVariantAttributeOptions = recomputedOptions;
      
      // Update size options.
      // IMPORTANT: Size availability should reflect overall stock for that size
      // across all colors, not be over‑restricted by the current color filter.
      // This ensures sizes don't get disabled when switching colors if stock exists.
      final updatedSizeOptions = currentProduct.sizeOptions.map((size) {
        final bool isSelected = normalize(size.name) == normalize(nextSelectedPrimary);

        // Determine availability by scanning all variant combinations
        // and checking if ANY in‑stock variant exists with this size.
        bool isAvailable = false;
        for (final v in currentProduct.variantCombinations) {
          // Try to read size from primary label or SIZE field
          String? comboSize =
              _getComboValueForAttribute(currentProduct, v, currentProduct.primaryVariantLabel);
          comboSize ??= _getComboValueForAttribute(currentProduct, v, 'SIZE');

          if (comboSize != null &&
              normalize(comboSize) == normalize(size.name) &&
              _isVariantInStock(v)) {
            isAvailable = true;
            break;
          }
        }
        
        return SizeOption(
          id: size.id,
          name: size.name,
          isAvailable: isAvailable,
          isRecommended: size.isRecommended,
          isSelected: isSelected,
        );
      }).toList();

      // Don't set images from color option here – set from selected variant below so we never
      // emit wrong/previous images and cause a glitch. Use current images as placeholder until then.
      final placeholderImages = List<String>.from(currentProduct.images);

      var updatedProduct = ProductDetails(
        id: currentProduct.id,
        brand: currentProduct.brand,
        name: currentProduct.name,
        description: currentProduct.description,
        price: currentProduct.price,
        originalPrice: currentProduct.originalPrice,
        rating: currentProduct.rating,
        reviewCount: currentProduct.reviewCount,
        images: placeholderImages,
        colorOptions: updatedColorOptions,
        sizeOptions: updatedSizeOptions,
        variantAttributeOptions: updatedVariantAttributeOptions, /// Zeinab Attributes
        selectedColor: colorNameForMatching,
        selectedSize: nextSelectedPrimary,
        isFavorite: currentProduct.isFavorite,
        hasDiscount: currentProduct.hasDiscount,
        discountPercentage: currentProduct.discountPercentage,
        features: currentProduct.features,
        material: currentProduct.material,
        materialsList: currentProduct.materialsList,
        materialOptions: currentProduct.materialOptions,
        selectedMaterial: nextSelectedMaterial, // Use recomputed material
        careInstructions: currentProduct.careInstructions,
        heelHeightCm: currentProduct.heelHeightCm,
        heelType: currentProduct.heelType,
        heelHeightOptions: currentProduct.heelHeightOptions,
        selectedHeelHeightCm: nextSelectedHeelHeight, // Use recomputed heel height
        isPlusMember: currentProduct.isPlusMember,
        pointsEarned: currentProduct.pointsEarned,
        optionalProducts: currentProduct.optionalProducts,
        accessoryProducts: currentProduct.accessoryProducts,
        alternativeProducts: currentProduct.alternativeProducts,
        variantCombinations: currentProduct.variantCombinations,
        primaryVariantLabel: currentProduct.primaryVariantLabel,
        tags: currentProduct.tags,
        variantImagesMap: currentProduct.variantImagesMap,
      );
      
      // Sync stock & quantity with the newly selected variant
      // IMPORTANT: When color changes, we need to find variant matching size+color only
      // Other attributes (material, heel height) might not match the new color variant
      int nextQuantity = currentState.quantity;
      VariantCombination? selectedVariant;
      
      // First try exact match (all attributes)
      selectedVariant = _findSelectedVariant(updatedProduct);
      
      if (selectedVariant != null) {
        debugPrint('🎨 COLOR CHANGED → Found EXACT MATCH variant_id=${selectedVariant.variantId} for color="${updatedProduct.selectedColor}", size="${updatedProduct.selectedSize}"');
        print('🎨🎨🎨 COLOR CHANGED → VARIANT_ID: ${selectedVariant.variantId} 🎨🎨🎨');
      }
      
      // If no exact match found, try flexible match (size + color only)
      if (selectedVariant == null && updatedProduct.selectedSize.isNotEmpty && updatedProduct.selectedColor.isNotEmpty) {
        debugPrint('🔍 No exact variant match found, trying flexible match (size + color only)...');
        String normalize(String s) => s.toLowerCase().trim();
        
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
        
        final normalizedSelectedColor = normalize(updatedProduct.selectedColor);
        final flexibleMatch = updatedProduct.variantCombinations.where((combo) {
          // Must match size
          bool sizeMatch = combo.hasAttributeValue('SIZE', updatedProduct.selectedSize) ||
                          combo.hasAttributeValue('size', updatedProduct.selectedSize) ||
                          combo.hasAttributeValue(updatedProduct.primaryVariantLabel, updatedProduct.selectedSize);
          
          if (!sizeMatch) return false;
          
          // Must match color (with normalization for better matching)
          final variantColorName = getVariantColorValue(combo);
          if (variantColorName == null) return false;
          
          final normalizedVariantColor = normalize(variantColorName);
          bool colorMatch = normalizedVariantColor == normalizedSelectedColor ||
                           normalizedVariantColor.contains(normalizedSelectedColor) ||
                           normalizedSelectedColor.contains(normalizedVariantColor);
          
          return colorMatch;
        }).toList();
        
        if (flexibleMatch.isNotEmpty) {
          selectedVariant = flexibleMatch.first;
          debugPrint('✅ Found flexible match variant_id=${selectedVariant.variantId} for color=${updatedProduct.selectedColor}, size=${updatedProduct.selectedSize}');
        }
        
        if (flexibleMatch.isNotEmpty) {
          // Sort by highest stock

          flexibleMatch.sort((a, b) {
            final qtyA = a.quantityAvailable ?? 0;
            final qtyB = b.quantityAvailable ?? 0;
            return qtyB.compareTo(qtyA);
          });
          selectedVariant = flexibleMatch.first;
          debugPrint('✅ Flexible match found: variantId=${selectedVariant.variantId}, quantityAvailable=${selectedVariant.quantityAvailable}');
          print('🎨🎨🎨 COLOR CHANGED → VARIANT_ID (FLEXIBLE MATCH): ${selectedVariant.variantId} 🎨🎨🎨');
        }
      }
      
      // CRITICAL: When size is selected, use hasInStockVariant as the primary source of truth
      // This ensures we correctly reflect stock status for the exact color+size combination
      bool finalInStock;
      if (selectedVariant != null) {
        // CRITICAL: Use _isVariantInStock to properly check both inStock flag AND quantityAvailable
        // This ensures we correctly identify when a variant is truly out of stock
        bool variantInStock = _isVariantInStock(selectedVariant);
        
        final double? quantityAvailable = selectedVariant.quantityAvailable;

        if (quantityAvailable != null) {
          // Check if there's already an item in cart with this variant ID
          int existingCartQuantity = 0;
          final variantIdToCheck = selectedVariant.variantId;
          // Convert variantId to String for comparison (cart items use String IDs)
          final variantIdStr = variantIdToCheck.toString();
          if (cartBloc.state is CartLoaded) {
            final cartState = cartBloc.state as CartLoaded;
            try {
              final existingItem = cartState.cartItems.firstWhere(
                (item) => item.product.id.toString() == variantIdStr,
              );
              existingCartQuantity = existingItem.quantity;
            } catch (e) {
              // Item not found in cart, existingCartQuantity remains 0
            }
          }
          
          final maxAllowed = quantityAvailable.toInt();
          final available = maxAllowed - existingCartQuantity;
          
          // If no stock available (considering cart), mark as out of stock
          if (maxAllowed <= 0 || available <= 0) {
            variantInStock = false;
            nextQuantity = 1;
          } else {
            // Clamp to available quantity (accounting for cart items)

            ///Zeinab QTY
            if (nextQuantity > available) {
              nextQuantity = available;
            }
            if (nextQuantity <= 0) {
              nextQuantity = 1;
            }
          }
          
          debugPrint(
            '📦 _onSelectColor → Found variant: size="${updatedProduct.selectedSize}", '
            'color="$actualColorName", variantId=${selectedVariant.variantId}, '
            'inStock=${selectedVariant.inStock}, qty=$quantityAvailable, '
            'available=$available, finalInStock=$variantInStock',
          );
          print('Zeinnaa 2: ${updatedVariantAttributeOptions.length} ,ID ${selectedVariant.variantId} , '
              'List of sizes :: ${ selectedVariant.attributes.length}');
        } else {
          // If quantityAvailable is null, rely on _isVariantInStock result
          debugPrint(
            '⚠️ Selected variant has null quantityAvailable, using inStock flag: $variantInStock',
          );
        }

        // Don't set inStock from variant match - only set from combination validation
        // Keep finalInStock as false until combination matches exactly
        finalInStock = false; // Don't show in stock until combination matches
        debugPrint(
          '📦 _onSelectColor → variantId=${selectedVariant.variantId}, but inStock=false until combination matches',
        );
      } else {
        // No variant found - set to false until combination matches
        finalInStock = false; // Don't show in stock until combination matches
        debugPrint('📦 No variant match: inStock=false until combination matches for color="$colorNameForMatching"');
        nextQuantity = 1;
      }
      
      // Step 1: Send only the clicked color value id to the loop; get available combination.
      // Use the same validation logic as other attributes: compare selected ids with available combination ids.
      if (updatedProduct.attributeVariantCombinations.isNotEmpty ||
          updatedProduct.attributeValueCombinationsByKey.isNotEmpty) {
        final colorValueId = event.colorId.toString();
        debugPrint(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
        debugPrint(
          '🎯 [SelectColor] Attribute: COLOR | Selected ID: $colorValueId',
        );
        debugPrint(
          '📤 [Send to Loop] Color attribute value id: $colorValueId',
        );
        final comboFromLoop = updatedProduct.findMatchingComboByClickedValueId(colorValueId);
        debugPrint(
          '📥 [Get from Loop] Matched: ${comboFromLoop != null} | Variant ID: ${comboFromLoop?.variantId}',
        );

        if (comboFromLoop != null) {
          // Step 2: Extract available combination ids from the combo (list of value ids in this combo).
          final availableCombinationIds = comboFromLoop.values.map((v) => v.id).toSet();
          debugPrint(
            '📋 [Available Combination IDs] From loop response: $availableCombinationIds',
          );
          // Show detailed breakdown of each attribute in the combo
          debugPrint(
            '   📋 [Combo Details]',
          );
          for (final comboVal in comboFromLoop.values) {
            final attrSlug = ProductDetails.attributeNameToComboSlug(
              comboVal.value.split('-').first.trim(),
            );
            debugPrint(
              '      - Attribute: $attrSlug | Value ID: ${comboVal.id} | Value: "${comboVal.value}"',
            );
          }

          // Step 3: Normalize ONLY the clicked color id from combo - don't change other attributes.
          // This ensures only the clicked color is updated, other attributes stay as user selected them.
          final colorAttrSlug = ProductDetails.attributeNameToComboSlug('color');
          updatedProduct = _normalizeAttributeIdsFromCombo(updatedProduct, comboFromLoop, clickedAttributeSlug: colorAttrSlug);

          // Step 4: Get full current selection (all selected attribute ids) with normalized ids.
          // Build selection that includes ALL attributes from combo, even if selectedValue is empty.
          final fullSelection = updatedProduct.getSelectedAttributeSlugToValueId();
          // Also include attributes from combo that might not be in selectedValue (use isSelected flag)
          final comboBasedSelection = <String, int>{};
          for (final comboVal in comboFromLoop.values) {
            final comboValueStr = comboVal.value;
            final idx = comboValueStr.indexOf('-');
            if (idx <= 0) continue;
            final attrPart = comboValueStr.substring(0, idx).trim();
            final attrSlug = ProductDetails.attributeNameToComboSlug(attrPart);
            if (attrSlug.isEmpty) continue;
            comboBasedSelection[attrSlug] = comboVal.id;
          }
          // Merge: combo-based selection takes precedence (source of truth), then add any other selected
          final mergedSelection = <String, int>{...comboBasedSelection, ...fullSelection};
          final selectedIds = mergedSelection.values.toSet();
          debugPrint(
            '📋 [Selected IDs] Current selection (all attributes): $selectedIds',
          );
          // Show detailed breakdown of each selected attribute
          debugPrint(
            '   📋 [Selection Details]',
          );
          debugPrint(
            '   📋 [From Combo] Combo-based selection: $comboBasedSelection',
          );
          debugPrint(
            '   📋 [From Options] variantAttributeOptions selection: $fullSelection',
          );
          debugPrint(
            '   📋 [Merged] Final merged selection: $mergedSelection',
          );
          for (final entry in mergedSelection.entries) {
            final source = comboBasedSelection.containsKey(entry.key) ? 'combo' : 'options';
            debugPrint(
              '      - Attribute: ${entry.key} | Selected ID: ${entry.value} (from $source)',
            );
          }

          // Step 5: Validate: compare selected ids (with normalized attribute ids) with available combination ids.
          // Exclude the color attribute from validation (we're validating OTHER attributes match)
          // Use colorAttrSlug already declared above for normalization
          // Remove color attribute from mergedSelection for validation
          final selectedForValidation = Map<String, int>.from(mergedSelection);
          selectedForValidation.remove(colorAttrSlug);
          // Also try removing by other possible color slugs
          selectedForValidation.remove('color');
          selectedForValidation.remove('اللون');
          final selectedIdsForValidation = selectedForValidation.values.toSet();
          // Remove color ID from available combination IDs
          final colorIdInCombo = comboBasedSelection[colorAttrSlug] ?? 
                                 comboBasedSelection['color'] ?? 
                                 comboBasedSelection['اللون'];
          final availableIdsForValidation = colorIdInCombo != null
              ? availableCombinationIds.where((id) => id != colorIdInCombo).toSet()
              : availableCombinationIds;
          
          final idsMatch = selectedIdsForValidation.length == availableIdsForValidation.length &&
              selectedIdsForValidation.containsAll(availableIdsForValidation);
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );
          debugPrint(
            '✅ [Validate] Comparing (excluding color attribute "$colorAttrSlug", ID: $colorIdInCombo):',
          );
          debugPrint(
            '   Selected IDs (all):     $selectedIds',
          );
          debugPrint(
            '   Selected IDs (for validation, excluding clicked):     $selectedIdsForValidation',
          );
          debugPrint(
            '   Available IDs (all):    $availableCombinationIds',
          );
          debugPrint(
            '   Available IDs (for validation, excluding clicked):    $availableIdsForValidation',
          );
          debugPrint(
            '   Match Result:     ${idsMatch ? "✅ MATCH" : "❌ NO MATCH"}',
          );
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );

          if (idsMatch) {
            // Exact match → use combo for stock badge (in stock, low stock, etc.)
            final combo = comboFromLoop;
            finalInStock = combo.inStock && combo.quantityAvailable > 0;
            final qty = combo.quantityAvailable.toInt();
            updatedProduct = updatedProduct.copyWith(
              inStock: finalInStock,
              selectedVariantQuantityAvailable: qty,
            );
            debugPrint(
              '📦 _onSelectColor → ✅ Match! colorId=$colorValueId → variantId=${combo.variantId}, inStock=$finalInStock, qty=$qty',
            );
          } else {
            // No match → out of stock
            finalInStock = false;
            updatedProduct = updatedProduct.copyWith(
              inStock: false,
              selectedVariantQuantityAvailable: 0,
            );
            debugPrint(
              '📦 _onSelectColor → ❌ No match: selectedIdsForValidation=$selectedIdsForValidation ≠ availableIdsForValidation=$availableIdsForValidation → out of stock',
            );
          }
        } else {
          // No combo from loop → out of stock
          finalInStock = false;
          updatedProduct = updatedProduct.copyWith(
            inStock: false,
            selectedVariantQuantityAvailable: 0,
          );
          debugPrint(
            '📦 _onSelectColor → ❌ No combo from loop for colorId=$colorValueId → out of stock',
          );
        }
      } else {
        // Fallback: use variant_combinations logic when attribute_value_combinations not available
        final int? qtyForBadge = selectedVariant?.quantityAvailable != null
            ? selectedVariant!.quantityAvailable!.toInt()
            : null;
        updatedProduct = updatedProduct.copyWith(
          inStock: finalInStock,
          selectedVariantQuantityAvailable: qtyForBadge,
        );
      }

      // Update images only when color changes: use variant_id from first variant matching selected color (variantImagesMap = multiple images per variant).
      final vid = updatedProduct.variantIdForImagesByColor;
      if (vid != null && vid.isNotEmpty) {
        updatedProduct = updatedProduct.withImagesForVariant(vid);
        debugPrint('🎨 _onSelectColor: images from variantIdByColor=$vid (${updatedProduct.images.length} images)');
      } else if (selectedColorOption.images.isNotEmpty) {
        updatedProduct = updatedProduct.copyWith(images: List<String>.from(selectedColorOption.images));
        debugPrint('🎨 Using ColorOption.images: ${selectedColorOption.images.length} (${selectedColorOption.displayNameOrName})');
      }
      // If still no update (no variant for color, no option images), keep current images to avoid blank.

      debugPrint('🔴 [_onSelectColor] EMITTING: selectedSize="${updatedProduct.selectedSize}" selectedColor="${updatedProduct.selectedColor}"');
      for (final opt in updatedProduct.variantAttributeOptions) {
        debugPrint('🔴 [_onSelectColor]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
      }
      debugPrint('🔴 [_onSelectColor] ═══════════════════════════════════════');

      emit(ProductDetailsLoaded(updatedProduct, quantity: nextQuantity, isAdding: false));
      
      final result = await selectColor(SelectColorParams(
        productId: event.productId,
        colorId: event.colorId,
      ));
      
      // Don't re-emit on success – we already emitted the correct state above. Re-emitting here
      // overwrites the state that SelectVariantById may have set (which runs while we awaited),
      // causing the "correct image then revert to previous" glitch within ~1 second.
      result.fold(
        (failure) => emit(ProductDetailsError(failure.message)),
        (_) {
          // Success: do nothing; UI already has correct state from first emit + SelectVariantById.
        },
      );
    }
  }

  Future<void> _onSelectSize(
    SelectSizeEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    debugPrint('🔴 [_onSelectSize] ═══════════════════════════════════════');
    debugPrint('🔴 [_onSelectSize] EVENT RECEIVED (USER TAPPED SIZE BUTTON) sizeId=${event.sizeId}');
    
    if (state is ProductDetailsLoaded) {
      final currentState = state as ProductDetailsLoaded;
      final currentProduct = currentState.productDetails;
      debugPrint('🔴 [_onSelectSize] BEFORE: selectedSize="${currentProduct.selectedSize}" selectedColor="${currentProduct.selectedColor}"');
      for (final opt in currentProduct.variantAttributeOptions) {
        debugPrint('🔴 [_onSelectSize]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
      }
      
      // Find the selected size.
      // NOTE: Backend sometimes sends sizeOptions as empty, but we still have sizes
      // inside variantAttributeOptions. In that case we synthesize sizeOptions
      // from the size attribute values so that size selection works.
      List<SizeOption> effectiveSizeOptions = currentProduct.sizeOptions;

      if (effectiveSizeOptions.isEmpty) {
        debugPrint(
          '⚠️ _onSelectSize: sizeOptions is EMPTY for product ${currentProduct.id}, '
          'synthesizing from variantAttributeOptions...',
        );

        // Try to locate the size attribute in variantAttributeOptions
        VariantAttributeOption? sizeAttr;
        for (final opt in currentProduct.variantAttributeOptions) {
          final n = opt.attributeName.toLowerCase().trim();
          if (n == 'size' ||
              n == currentProduct.primaryVariantLabel.toLowerCase().trim() ||
              n == 'القياس') {
            sizeAttr = opt;
            break;
          }
        }

        if (sizeAttr != null && sizeAttr.values.isNotEmpty) {
          effectiveSizeOptions = sizeAttr.values.map((v) {
            return SizeOption(
              id: v.id,
              name: v.name,
              isAvailable: true, // treat as available for UI selection
              isRecommended: false,
              isSelected: v.id == event.sizeId,
            );
          }).toList();
        } else {
          debugPrint(
            '⚠️ _onSelectSize: Could not synthesize sizeOptions (no size attribute values). '
            'Ignoring SelectSizeEvent(sizeId=${event.sizeId}).',
          );
          return;
        }
      }

      // Resolve sizeId → size NAME from the same source as the UI (variantAttributeOptions).
      // Size buttons send sizeId: value.id; we must use the corresponding value.name for variant
      // matching so the correct variant (and image) is found. Using only SizeOption by id can
      // pick the wrong size when backend sizeOptions use different ids.
      String selectedSizeName;
      VariantAttributeOption? sizeAttrForResolve;
      for (final opt in currentProduct.variantAttributeOptions) {
        final n = opt.attributeName.toLowerCase().trim();
        if (n == 'size' ||
            n == currentProduct.primaryVariantLabel.toLowerCase().trim() ||
            n == 'القياس') {
          sizeAttrForResolve = opt;
          break;
        }
      }
      if (sizeAttrForResolve != null) {
        final sizeIdStr = event.sizeId.toString().trim();
        try {
          final matchedValue = sizeAttrForResolve.values.firstWhere(
            (v) => v.id.toString().trim() == sizeIdStr,
          );
          selectedSizeName = matchedValue.name;
          debugPrint('📏 _onSelectSize: resolved sizeId=$sizeIdStr (value id for "$selectedSizeName") → name="$selectedSizeName"');
        } catch (_) {
          final selectedSizeOption = effectiveSizeOptions.firstWhere(
            (size) => size.id.toString().trim() == sizeIdStr,
            orElse: () => effectiveSizeOptions.first,
          );
          selectedSizeName = selectedSizeOption.name;
          debugPrint('📏 _onSelectSize: sizeId $sizeIdStr not in variantAttributeOptions, using SizeOption: name="$selectedSizeName"');
        }
      } else {
        final sizeIdStr = event.sizeId.toString().trim();
        final selectedSizeOption = effectiveSizeOptions.firstWhere(
          (size) => size.id.toString().trim() == sizeIdStr,
          orElse: () => effectiveSizeOptions.first,
        );
        selectedSizeName = selectedSizeOption.name;
      }

      // Recompute stock for the currently selected combination (size + color + other attrs).
      // If there is no in-stock variant for the current selection, we must mark inStock=false
      // so the UI can show "Out of stock" for that size/color combination.
      bool containsArabic(String text) {
        if (text.isEmpty) return false;
        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        return arabicRegex.hasMatch(text);
      }

      String normalize(String s) => s.toLowerCase().trim();

      String? getVariantColorValue(VariantCombination v) {
        final colorAttrNames = [
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
        for (final attrName in colorAttrNames) {
          final value = v.getAttributeValue(attrName);
          if (value != null && value.isNotEmpty) {
            return value;
          }
        }
        return null;
      }

      // Determine the effective selected color name for matching.
      String? selectedColorName = currentProduct.selectedColor;
      if (selectedColorName.isEmpty) {
        // Try to get from colorOptions (first selected one)
        try {
          final selectedColorOpt = currentProduct.colorOptions.firstWhere(
            (c) => c.isSelected,
            orElse: () => currentProduct.colorOptions.isNotEmpty
                ? currentProduct.colorOptions.first
                : const ColorOption(
                    id: '',
                    name: '',
                    displayName: null,
                    code: '',
                    images: [],
                    isSelected: false,
                  ),
          );
          selectedColorName = selectedColorOpt.name;
        } catch (_) {
          selectedColorName = '';
        }
      }

      // If the color name is Arabic, try to resolve to an English one from colorOptions.
      if (selectedColorName.isNotEmpty && containsArabic(selectedColorName)) {
        for (final colorOpt in currentProduct.colorOptions) {
          if (colorOpt.displayNameOrName == selectedColorName &&
              !containsArabic(colorOpt.name)) {
            selectedColorName = colorOpt.name;
            break;
          }
        }
      }

      final normalizedSelectedSize = normalize(selectedSizeName);
      final normalizedSelectedColor =
          selectedColorName != null ? normalize(selectedColorName!) : '';

      bool hasAvailableVariantForSelection = false;

      for (final v in currentProduct.variantCombinations) {
        // Match size (dynamic: uses product's attribute options for API name)
        bool sizeMatch = false;
        final sizeVal = _getComboValueForAttribute(currentProduct, v, currentProduct.primaryVariantLabel) ??
            _getComboValueForAttribute(currentProduct, v, 'SIZE');
        if (sizeVal != null && sizeVal.isNotEmpty) {
          sizeMatch = normalize(sizeVal) == normalizedSelectedSize;
        }
        if (!sizeMatch) continue;

        // Match color only when a color is effectively selected
        bool colorMatch = true;
        if (normalizedSelectedColor.isNotEmpty) {
          final variantColorName = getVariantColorValue(v);
          if (variantColorName == null || variantColorName.isEmpty) {
            colorMatch = false;
          } else {
            final normalizedVariantColor = normalize(variantColorName);
            colorMatch = normalizedVariantColor == normalizedSelectedColor ||
                normalizedVariantColor.contains(normalizedSelectedColor) ||
                normalizedSelectedColor.contains(normalizedVariantColor);
          }
        }
        if (!colorMatch) continue;

        // Check stock for this exact combination using the proper stock check function
        if (_isVariantInStock(v)) {
          hasAvailableVariantForSelection = true;
          debugPrint(
            '📦 _onSelectSize → Found in-stock variant: size="$selectedSizeName", '
            'color="${selectedColorName ?? 'none'}", variantId=${v.variantId}',
          );
          break;
        }
      }

      // CRITICAL: Recalculate color availability based on the newly selected size
      List<ColorOption> updatedColorOptions = currentProduct.colorOptions.map((color) {
        // Get the English color name for matching
        String? colorNameForMatching;
        for (final opt in currentProduct.variantAttributeOptions) {
          final attrNameLower = opt.attributeName.toLowerCase();
          if (attrNameLower == 'color name' || 
              attrNameLower == 'color' || 
              attrNameLower == 'colour' ||
              attrNameLower == 'اللون') {
            try {
              final matchedValue = opt.values.firstWhere(
                (v) => v.id == color.id,
              );
              if (!containsArabic(matchedValue.name)) {
                colorNameForMatching = matchedValue.name;
                break;
              }
            } catch (e) {
              // ID not found, continue
            }
          }
        }
        if (colorNameForMatching == null || colorNameForMatching.isEmpty) {
          colorNameForMatching = color.name;
        }
        // Fallback for Arabic: use displayName when name is placeholder/empty
        if ((colorNameForMatching == null || colorNameForMatching.isEmpty || colorNameForMatching.startsWith('COLOR_ID_')) &&
            color.displayName != null && color.displayName!.isNotEmpty) {
          colorNameForMatching = color.displayName;
        }
        
        // Check if this color is available for the newly selected size
        bool hasInStockVariant = false;
        final normalizedColor = normalize(colorNameForMatching ?? '');
        // CRITICAL: Empty string causes "x".contains("") = true, incorrectly matching all variants (Arabic bug)
        final hasValidColorName = normalizedColor.isNotEmpty;
        
        for (final v in currentProduct.variantCombinations) {
          // Match size (dynamic: uses product's attribute options for API name)
          bool sizeMatch = false;
          final sizeVal = _getComboValueForAttribute(currentProduct, v, currentProduct.primaryVariantLabel) ??
              _getComboValueForAttribute(currentProduct, v, 'SIZE');
          if (sizeVal != null && sizeVal.isNotEmpty) {
            sizeMatch = normalize(sizeVal) == normalizedSelectedSize;
          }
          if (!sizeMatch) continue;
          
          // Match color
          final variantColorName = getVariantColorValue(v);
          if (variantColorName == null) continue;
          
          final normalizedVariantColor = normalize(variantColorName);
          
          final bool colorMatch = hasValidColorName && normalizedVariantColor.isNotEmpty &&
              (normalizedVariantColor == normalizedColor ||
               (normalizedColor.isNotEmpty && normalizedVariantColor.contains(normalizedColor)) ||
               (normalizedVariantColor.isNotEmpty && normalizedColor.contains(normalizedVariantColor)));
          
          if (colorMatch) {
            final isInStock = _isVariantInStock(v);
            if (isInStock) {
              hasInStockVariant = true;
              break;
            }
          }
        }
        
        return ColorOption(
          id: color.id,
          name: color.name,
          displayName: color.displayName,
          code: color.code,
          images: color.images,
          isSelected: color.isSelected,
          isAvailable: hasInStockVariant, // Recalculate based on newly selected size
        );
      }).toList();

      // Sync variantAttributeOptions so size attribute has selectedValue = selectedSizeName.
      // This allows _findSelectedVariant to resolve the exact variant for images + stock.
      final updatedVariantAttributeOptions = currentProduct.variantAttributeOptions.map((opt) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if (attrNameLower == 'size' ||
            attrNameLower == currentProduct.primaryVariantLabel.toLowerCase() ||
            attrNameLower == 'القياس') {
          return VariantAttributeOption(
            attributeName: opt.attributeName,
            values: opt.values,
            selectedValue: selectedSizeName,
            apiAttributeName: opt.apiAttributeName,
            attributeId: opt.attributeId,
          );
        }
        return opt;
      }).toList();

      var productToEmit = currentProduct.copyWith(
        selectedSize: selectedSizeName,
        colorOptions: updatedColorOptions,
        variantAttributeOptions: updatedVariantAttributeOptions,
      );

      int nextQuantity = currentState.quantity;
      bool inStock = hasAvailableVariantForSelection;
      VariantCombination? selectedVariant = _findSelectedVariant(productToEmit);

      // Step 1: Send only the size attribute value id to the loop; get available combination.
      if (productToEmit.attributeVariantCombinations.isNotEmpty ||
          productToEmit.attributeValueCombinationsByKey.isNotEmpty) {
        debugPrint(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
        debugPrint(
          '🎯 [SelectSize] Attribute: SIZE | Selected ID: ${event.sizeId}',
        );
        debugPrint(
          '📤 [Send to Loop] Size attribute value id: ${event.sizeId}',
        );
        final comboFromLoop = productToEmit.findMatchingComboByClickedValueId(event.sizeId);
        debugPrint(
          '📥 [Get from Loop] Matched: ${comboFromLoop != null} | Variant ID: ${comboFromLoop?.variantId}',
        );

        if (comboFromLoop != null) {
          // Step 2: Extract available combination ids from the combo (list of value ids in this combo).
          final availableCombinationIds = comboFromLoop.values.map((v) => v.id).toSet();
          debugPrint(
            '📋 [Available Combination IDs] From loop response: $availableCombinationIds',
          );
          // Show detailed breakdown of each attribute in the combo
          debugPrint(
            '   📋 [Combo Details]',
          );
          for (final comboVal in comboFromLoop.values) {
            final attrSlug = ProductDetails.attributeNameToComboSlug(
              comboVal.value.split('-').first.trim(),
            );
            debugPrint(
              '      - Attribute: $attrSlug | Value ID: ${comboVal.id} | Value: "${comboVal.value}"',
            );
          }

          // Step 3: Normalize ONLY the clicked size id from combo - don't change other attributes.
          // This ensures only the clicked size is updated, other attributes stay as user selected them.
          final sizeAttrSlug = ProductDetails.attributeNameToComboSlug(
            productToEmit.primaryVariantLabel.isNotEmpty 
                ? productToEmit.primaryVariantLabel 
                : 'size'
          );
          productToEmit = _normalizeAttributeIdsFromCombo(productToEmit, comboFromLoop, clickedAttributeSlug: sizeAttrSlug);

          // Step 4: Get full current selection (all selected attribute ids) with normalized ids.
          // Build selection that includes ALL attributes from combo, even if selectedValue is empty.
          final fullSelection = productToEmit.getSelectedAttributeSlugToValueId();
          // Also include attributes from combo that might not be in selectedValue (use isSelected flag)
          final comboBasedSelection = <String, int>{};
          for (final comboVal in comboFromLoop.values) {
            final comboValueStr = comboVal.value;
            final idx = comboValueStr.indexOf('-');
            if (idx <= 0) continue;
            final attrPart = comboValueStr.substring(0, idx).trim();
            final attrSlug = ProductDetails.attributeNameToComboSlug(attrPart);
            if (attrSlug.isEmpty) continue;
            comboBasedSelection[attrSlug] = comboVal.id;
          }
          // Merge: combo-based selection takes precedence (source of truth), then add any other selected
          final mergedSelection = <String, int>{...comboBasedSelection, ...fullSelection};
          final selectedIds = mergedSelection.values.toSet();
          debugPrint(
            '📋 [Selected IDs] Current selection (all attributes): $selectedIds',
          );
          // Show detailed breakdown of each selected attribute
          debugPrint(
            '   📋 [Selection Details]',
          );
          debugPrint(
            '   📋 [From Combo] Combo-based selection: $comboBasedSelection',
          );
          debugPrint(
            '   📋 [From Options] variantAttributeOptions selection: $fullSelection',
          );
          debugPrint(
            '   📋 [Merged] Final merged selection: $mergedSelection',
          );
          for (final entry in mergedSelection.entries) {
            final source = comboBasedSelection.containsKey(entry.key) ? 'combo' : 'options';
            debugPrint(
              '      - Attribute: ${entry.key} | Selected ID: ${entry.value} (from $source)',
            );
          }

          // Step 5: Validate: compare selected ids (with normalized attribute ids) with available combination ids.
          // Exclude the size attribute from validation (we're validating OTHER attributes match)
          // Use sizeAttrSlug already declared above for normalization
          // Find size ID from mergedSelection - check all possible size slugs
          final sizeIdInSelection = mergedSelection[sizeAttrSlug] ?? 
                                    mergedSelection['size'] ?? 
                                    mergedSelection['المقاس'] ??
                                    mergedSelection['القياس'];
          // Remove size attribute from mergedSelection for validation - try all possible size slugs
          final selectedForValidation = Map<String, int>.from(mergedSelection);
          selectedForValidation.remove(sizeAttrSlug);
          selectedForValidation.remove('size');
          selectedForValidation.remove('المقاس');
          selectedForValidation.remove('القياس');
          // Also find and remove by ID if we found the size ID
          if (sizeIdInSelection != null) {
            selectedForValidation.removeWhere((key, value) => value == sizeIdInSelection);
          }
          final selectedIdsForValidation = selectedForValidation.values.toSet();
          // Remove size ID from available combination IDs (if it exists in combo, otherwise just use available as-is)
          final sizeIdInCombo = comboBasedSelection[sizeAttrSlug] ?? 
                                comboBasedSelection['size'] ?? 
                                comboBasedSelection['المقاس'] ??
                                comboBasedSelection['القياس'];
          final availableIdsForValidation = sizeIdInCombo != null
              ? availableCombinationIds.where((id) => id != sizeIdInCombo).toSet()
              : availableCombinationIds;
          
          debugPrint(
            '   🔍 [Size Exclusion] sizeAttrSlug=$sizeAttrSlug, sizeIdInSelection=$sizeIdInSelection, sizeIdInCombo=$sizeIdInCombo',
          );
          debugPrint(
            '   🔍 [Size Exclusion] mergedSelection keys before removal: ${mergedSelection.keys.toList()}',
          );
          debugPrint(
            '   🔍 [Size Exclusion] selectedForValidation keys after removal: ${selectedForValidation.keys.toList()}',
          );
          
          final idsMatch = selectedIdsForValidation.length == availableIdsForValidation.length &&
              selectedIdsForValidation.containsAll(availableIdsForValidation);
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );
          debugPrint(
            '✅ [Validate] Comparing (excluding size attribute "$sizeAttrSlug", sizeIdInSelection=$sizeIdInSelection, sizeIdInCombo=$sizeIdInCombo):',
          );
          debugPrint(
            '   Selected IDs (all):     $selectedIds',
          );
          debugPrint(
            '   Merged Selection keys: ${mergedSelection.keys.toList()}',
          );
          debugPrint(
            '   Selected IDs (for validation, excluding size):     $selectedIdsForValidation',
          );
          debugPrint(
            '   Available IDs (all):    $availableCombinationIds',
          );
          debugPrint(
            '   Available IDs (for validation, excluding clicked):    $availableIdsForValidation',
          );
          debugPrint(
            '   Match Result:     ${idsMatch ? "✅ MATCH" : "❌ NO MATCH"}',
          );
          debugPrint(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );

          if (idsMatch) {
            // Exact match → use combo for stock badge (in stock, low stock, etc.)
            final combo = comboFromLoop;
            inStock = combo.inStock && combo.quantityAvailable > 0;
            final qty = combo.quantityAvailable.toInt();
            productToEmit = productToEmit.copyWith(
              inStock: inStock,
              selectedVariantQuantityAvailable: qty,
            );
            debugPrint(
              '📦 _onSelectSize → ✅ Match! sizeId=${event.sizeId} → variantId=${combo.variantId}, inStock=$inStock, qty=$qty',
            );
            try {
              final variantIdStr = combo.variantId.toString();
              selectedVariant = currentProduct.variantCombinations.firstWhere(
                (v) => v.variantId.toString() == variantIdStr,
              );
            } catch (_) {}
          } else {
            // No match → out of stock
            inStock = false;
            productToEmit = productToEmit.copyWith(
              inStock: false,
              selectedVariantQuantityAvailable: 0,
            );
            debugPrint(
              '📦 _onSelectSize → ❌ No match: selectedIdsForValidation=$selectedIdsForValidation ≠ availableIdsForValidation=$availableIdsForValidation → out of stock',
            );
          }
        } else {
          // No combo from loop → out of stock
          inStock = false;
          productToEmit = productToEmit.copyWith(
            inStock: false,
            selectedVariantQuantityAvailable: 0,
          );
          debugPrint(
            '📦 _onSelectSize → ❌ No combo from loop for sizeId=${event.sizeId} → out of stock',
          );
        }
      }

      if (selectedVariant != null && productToEmit.attributeVariantCombinations.isEmpty) {
        // Only use variant-based stock if we don't have attribute combinations validation
        // But since we're using attribute combinations, this should only be fallback - set to false until match
        inStock = false; // Don't show in stock until combination matches
        final double? quantityAvailable = selectedVariant.quantityAvailable;
        if (quantityAvailable != null) {
          int existingCart = 0;
          if (cartBloc.state is CartLoaded) {
            try {
              final cartState = cartBloc.state as CartLoaded;
              final variantIdStr = selectedVariant.variantId.toString();
              final item = cartState.cartItems.firstWhere(
                (i) => i.product.id.toString() == variantIdStr,
              );
              existingCart = item.quantity;
            } catch (_) {}
          }
          final available = quantityAvailable.toInt() - existingCart;
          if (available <= 0) {
            inStock = false;
            nextQuantity = 1;
          } else {
            if (nextQuantity > available) nextQuantity = available;
            if (nextQuantity <= 0) nextQuantity = 1;
          }
        }
        final int? qtyForBadge = selectedVariant.quantityAvailable != null
            ? selectedVariant.quantityAvailable!.toInt()
            : null;
        productToEmit = productToEmit.copyWith(
          inStock: inStock,
          selectedVariantQuantityAvailable: qtyForBadge,
        );
        // Images update only on color change; keep current images when size changes.
        productToEmit = productToEmit.copyWith(images: List<String>.from(currentProduct.images));
      } else if (selectedVariant != null && productToEmit.attributeVariantCombinations.isNotEmpty) {
        // Already set inStock/selectedVariantQuantityAvailable from id-based loop; clamp nextQuantity by cart
        final int? qtyAvailable = productToEmit.selectedVariantQuantityAvailable;
        if (qtyAvailable != null) {
          int existingCart = 0;
          if (cartBloc.state is CartLoaded) {
            try {
              final cartState = cartBloc.state as CartLoaded;
              final variantIdStr = selectedVariant.variantId.toString();
              final item = cartState.cartItems.firstWhere(
                (i) => i.product.id.toString() == variantIdStr,
              );
              existingCart = item.quantity;
            } catch (_) {}
          }
          final available = qtyAvailable - existingCart;
          if (available <= 0) {
            nextQuantity = 1;
            productToEmit = productToEmit.copyWith(inStock: false);
          } else {
            if (nextQuantity > available) nextQuantity = available;
            if (nextQuantity <= 0) nextQuantity = 1;
          }
        }
        productToEmit = productToEmit.copyWith(images: List<String>.from(currentProduct.images));
      } else {
        productToEmit = productToEmit.copyWith(
          inStock: inStock,
          selectedVariantQuantityAvailable: null,
        );
      }

      debugPrint(
        '📦 _onSelectSize → size="$selectedSizeName" (sizeId=${event.sizeId}), color="${selectedColorName ?? 'none'}", '
        'variantId=${selectedVariant?.variantId}, inStock=$inStock, qty=${selectedVariant?.quantityAvailable}',
      );
      debugPrint('🔴 [_onSelectSize] EMITTING: selectedSize="${productToEmit.selectedSize}" selectedColor="${productToEmit.selectedColor}"');
      for (final opt in productToEmit.variantAttributeOptions) {
        debugPrint('🔴 [_onSelectSize]   attr="${opt.attributeName}" selectedValue="${opt.selectedValue}"');
      }
      debugPrint('🔴 [_onSelectSize] ═══════════════════════════════════════');

      emit(ProductDetailsLoaded(
        productToEmit,
        quantity: nextQuantity,
        isAdding: currentState.isAdding,
      ));
      return;
    }
  }

  /// Normalizes all attribute ids from combo: updates variantAttributeOptions to use combo's ids.
  /// This ensures validation uses correct ids for all attributes (color, material, height, width, etc.).
  /// Combo values format: "اللون-اسود", "height-4.5", "materials-روغان", etc.
  ProductDetails _normalizeAttributeIdsFromCombo(
    ProductDetails product,
    AttributeVariantCombination combo, {
    String? clickedAttributeSlug,
  }) {
    var updatedProduct = product;
    final updatedOptions = product.variantAttributeOptions.toList();
    
    // Parse each combo value to get attribute slug and value id
    // Only normalize the clicked attribute, skip others to preserve user's selections
    for (final comboVal in combo.values) {
      final comboValueStr = comboVal.value;
      // Parse combo slug: "اللون-اسود" -> ("اللون", "اسود") or "height-4.5" -> ("height", "4.5")
      // Use the same parsing logic as entity's _parseComboSlug
      final idx = comboValueStr.indexOf('-');
      if (idx <= 0) continue; // Skip if no separator found
      
      final attrPart = comboValueStr.substring(0, idx).trim();
      final valuePart = comboValueStr.substring(idx + 1).trim();
      
      // Get attribute slug from attribute part (normalize Arabic/English)
      final attrSlug = ProductDetails.attributeNameToComboSlug(attrPart);
      if (attrSlug.isEmpty) continue;
      
      // Only normalize the clicked attribute - skip others to preserve user's selections
      if (clickedAttributeSlug != null && attrSlug != clickedAttributeSlug) {
        debugPrint(
          '   ⏭️ [Normalize] Skipping attribute (slug=$attrSlug) - not the clicked attribute (clicked=$clickedAttributeSlug)',
        );
        continue;
      }
      
      // Find matching attribute option in variantAttributeOptions
      final attrOptionIndex = updatedOptions.indexWhere(
        (opt) => ProductDetails.attributeNameToComboSlug(opt.attributeName) == attrSlug,
      );
      
      if (attrOptionIndex >= 0) {
        final attrOption = updatedOptions[attrOptionIndex];
        final comboValueId = comboVal.id;
        
        // Find the value with combo's id
        VariantAttributeValue? correctValue;
        try {
          correctValue = attrOption.values.firstWhere(
            (v) => v.id.toString() == comboValueId.toString(),
          );
        } catch (_) {
          // If id not found, try to find by name match (fallback)
          if (valuePart.isNotEmpty) {
            String normalize(String s) => s.replaceAll(RegExp(r'[\s\-_]+'), '').toLowerCase();
            final normalizedCombo = normalize(valuePart);
            try {
              correctValue = attrOption.values.firstWhere(
                (v) => normalize(v.name) == normalizedCombo || 
                       (v.displayName != null && normalize(v.displayName!) == normalizedCombo),
              );
            } catch (_) {
              // If still not found, skip this attribute (don't update)
              debugPrint(
                '   🧬 [Normalize] Attribute "${attrOption.attributeName}" (slug=$attrSlug): Combo id $comboValueId not found in values, skipping',
              );
              continue;
            }
          } else {
            continue;
          }
        }
        
        if (correctValue != null) {
          // Get old selected id for comparison
          VariantAttributeValue? oldSelectedValue;
          try {
            oldSelectedValue = attrOption.values.firstWhere(
              (v) => v.isSelected || v.name == attrOption.selectedValue || 
                     (v.displayName != null && v.displayName == attrOption.selectedValue),
            );
          } catch (_) {
            // If no match found, use first value as fallback
            if (attrOption.values.isNotEmpty) {
              oldSelectedValue = attrOption.values.first;
            }
          }
          final oldSelectedId = oldSelectedValue?.id ?? correctValue.id;
          
          // Ensure selectedValue is never empty - use name, displayName, or valuePart from combo
          String selectedValueToStore = correctValue.name;
          if (selectedValueToStore.isEmpty && correctValue.displayName != null && correctValue.displayName!.isNotEmpty) {
            selectedValueToStore = correctValue.displayName!;
          }
          if (selectedValueToStore.isEmpty && valuePart.isNotEmpty) {
            selectedValueToStore = valuePart;
          }
          if (selectedValueToStore.isEmpty) {
            // Last resort: use first value's name
            selectedValueToStore = attrOption.values.first.name;
          }
          
          // Update variantAttributeOptions to store correct id
          // CRITICAL: Only update selectedValue and isSelected flags if this is the clicked attribute
          // For other attributes, preserve the existing selectedValue and isSelected flags to prevent unwanted changes
          final shouldUpdateSelectedValue = clickedAttributeSlug == null || attrSlug == clickedAttributeSlug;
          updatedOptions[attrOptionIndex] = VariantAttributeOption(
            attributeName: attrOption.attributeName,
            values: attrOption.values.map((v) {
              // Only update isSelected flag if this is the clicked attribute
              final shouldBeSelected = shouldUpdateSelectedValue 
                  ? v.id.toString() == comboValueId.toString()
                  : v.isSelected; // Preserve existing isSelected for non-clicked attributes
              return VariantAttributeValue(
                id: v.id,
                name: v.name,
                displayName: v.displayName,
                isAvailable: v.isAvailable,
                isSelected: shouldBeSelected,
              );
            }).toList(),
            selectedValue: shouldUpdateSelectedValue ? selectedValueToStore : attrOption.selectedValue, // Only update if clicked attribute
            apiAttributeName: attrOption.apiAttributeName,
            attributeId: attrOption.attributeId,
          );
          
          if (oldSelectedId.toString() != comboValueId.toString()) {
            debugPrint(
              '   🔄 [Normalize] Attribute "${attrOption.attributeName}" (slug=$attrSlug): Updated ID $oldSelectedId → $comboValueId (value="$selectedValueToStore")',
            );
          } else {
            debugPrint(
              '   ✓ [Normalize] Attribute "${attrOption.attributeName}" (slug=$attrSlug): ID $comboValueId already correct (value="$selectedValueToStore")',
            );
          }
        }
      }
    }
    
    return updatedProduct.copyWith(variantAttributeOptions: updatedOptions);
  }

  /// Helper method to find the currently selected variant based on product details.
  /// Prefer matching by attribute_name + value_name (strings: e.g. BLACK, 36, Synthetic Leather, 4.5);
  /// then fallback to legacy name-based match.
  VariantCombination? _findSelectedVariant(ProductDetails pd) {
    try {
      String normalize(String s) => s.toLowerCase().trim();

      // 1) Match by value_name: all 4 (color, size, material, height) validated against variant attributes.
      final byValueName = pd.findVariantMatchingSelectionByValueName();
      if (byValueName != null) {
        debugPrint(
          '📦 Variant matched by value_name: variantId=${byValueName.variantId}, '
          'inStock=${byValueName.inStock}, quantityAvailable=${byValueName.quantityAvailable}',
        );
        return byValueName;
      }

      // 2) Fallback: build selected pairs using attribute names (legacy)
      final Map<String, String> selectedByAttribute = {};
      
      // Add selected size/primary variant from variantAttributeOptions (source of truth)
      String? selectedSizeValue;
      for (final opt in pd.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if ((attrNameLower == 'size' || attrNameLower == pd.primaryVariantLabel.toLowerCase()) && 
            opt.selectedValue.isNotEmpty) {
          selectedSizeValue = opt.selectedValue;
          break;
        }
      }
      // Fallback to selectedSize
      if (selectedSizeValue == null && pd.selectedSize.isNotEmpty) {
        selectedSizeValue = pd.selectedSize;
      }
      
      if (selectedSizeValue != null && selectedSizeValue.isNotEmpty) {
        selectedByAttribute['SIZE'] = selectedSizeValue;
        selectedByAttribute['size'] = selectedSizeValue;
        selectedByAttribute[pd.primaryVariantLabel] = selectedSizeValue;
      }
      
      // Add selected color - prioritize COLOR NAME attribute from variantAttributeOptions
      String? selectedColorValue;
      for (final opt in pd.variantAttributeOptions) {
        final attrNameLower = opt.attributeName.toLowerCase();
        if ((attrNameLower == 'color name' || 
             attrNameLower == 'color' || 
             attrNameLower == 'colour' ||
             attrNameLower == 'اللون') && 
            opt.selectedValue.isNotEmpty) {
          selectedColorValue = opt.selectedValue;
          break;
        }
      }
      // Fallback to selectedColor
      if (selectedColorValue == null && pd.selectedColor.isNotEmpty) {
        selectedColorValue = pd.selectedColor;
      }
      
      if (selectedColorValue != null && selectedColorValue.isNotEmpty) {
        // Use "COLOR NAME" as the primary matching attribute (standard from API)
        selectedByAttribute['COLOR NAME'] = selectedColorValue;
        selectedByAttribute['color name'] = selectedColorValue;
        selectedByAttribute['color'] = selectedColorValue;
        selectedByAttribute['colour'] = selectedColorValue;
        selectedByAttribute['اللون'] = selectedColorValue;
      }
      
      // Add other selected attributes from variantAttributeOptions (material, height, etc.)
      for (final opt in pd.variantAttributeOptions) {
        if (opt.selectedValue.isNotEmpty) {
          final attrNameLower = opt.attributeName.toLowerCase();
          // Skip color and size as we've already handled them
          if (attrNameLower != 'color name' && 
              attrNameLower != 'color' && 
              attrNameLower != 'colour' &&
              attrNameLower != 'اللون' &&
              attrNameLower != 'size' &&
              attrNameLower != pd.primaryVariantLabel.toLowerCase()) {
            selectedByAttribute[opt.attributeName] = opt.selectedValue;
            // Also try uppercase version for common attributes
            if (opt.attributeName.toUpperCase() != opt.attributeName) {
              selectedByAttribute[opt.attributeName.toUpperCase()] = opt.selectedValue;
            }
          }
        }
      }
      
      // Add selectedMaterial if available
      if (pd.selectedMaterial != null && pd.selectedMaterial!.isNotEmpty) {
        selectedByAttribute['MATERIAL NAME'] = pd.selectedMaterial!;
        selectedByAttribute['material name'] = pd.selectedMaterial!;
      }
      
      // Add selectedHeelHeightCm if available
      if (pd.selectedHeelHeightCm != null) {
        final heightStr = pd.selectedHeelHeightCm!.toStringAsFixed(1);
        selectedByAttribute['HEIGHT'] = heightStr;
        selectedByAttribute['height'] = heightStr;
      }
      
      // Find matching variant - must match all selected attributes.
      // Use _getComboValueForAttribute so we match regardless of API attribute names.
      // For color, use bilingual match (Arabic displayName <-> English variant value).
      final matching = pd.variantCombinations.where((combo) {
        for (final entry in selectedByAttribute.entries) {
          final v = _getComboValueForAttribute(pd, combo, entry.key);
          final bool match = _isColorAttributeKey(entry.key)
              ? _colorValuesMatch(pd, v, entry.value)
              : (v != null && normalize(v) == normalize(entry.value));
          if (!match) return false;
        }
        return true;
      }).toList();
      
      if (matching.length == 1) {
        return matching.first;
      } else if (matching.length > 1) {
        // If multiple matches, prefer one with highest available stock
        matching.sort((a, b) {
          final qtyA = a.quantityAvailable ?? 0;
          final qtyB = b.quantityAvailable ?? 0;
          return qtyB.compareTo(qtyA); // Sort descending by stock
        });
        debugPrint('🔍 Multiple variants matched, selected one with highest stock: variantId=${matching.first.variantId}, quantityAvailable=${matching.first.quantityAvailable}');
        return matching.first;
      }
      
      // If no exact match, try partial match (at least size and color)
      if (selectedSizeValue != null && selectedColorValue != null) {
        final sizeValue = selectedSizeValue;
        final colorValue = selectedColorValue;
        final partialMatch = pd.variantCombinations.where((combo) {
          final comboSize = _getComboValueForAttribute(pd, combo, 'SIZE');
          final comboColor = _getComboValueForAttribute(pd, combo, 'COLOR NAME');
          final sizeMatch = comboSize != null && normalize(comboSize) == normalize(sizeValue);
          final colorMatch = _colorValuesMatch(pd, comboColor, colorValue);
          return sizeMatch && colorMatch;
        }).toList();
        
        if (partialMatch.isNotEmpty) {
          // Sort by highest stock when multiple partial matches
          partialMatch.sort((a, b) {
            final qtyA = a.quantityAvailable ?? 0;
            final qtyB = b.quantityAvailable ?? 0;
            return qtyB.compareTo(qtyA); // Sort descending by stock
          });
          debugPrint('🔍 Partial match found, selected one with highest stock: variantId=${partialMatch.first.variantId}, quantityAvailable=${partialMatch.first.quantityAvailable}');
          return partialMatch.first;
        }
      }
      
      // Last resort: return first variant if available
      if (pd.variantCombinations.isNotEmpty) {
        return pd.variantCombinations.first;
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ Error finding selected variant: $e');
      return null;
    }
  }

  Future<void> _onAddToCart(
    AddToCartEvent event,
    Emitter<ProductDetailsState> emit,
  ) async {
    debugPrint('🛒 _onAddToCart called with event: ${event.toString()}');
    
    if (state is ProductDetailsLoaded) {
      final currentState = state as ProductDetailsLoaded;
      debugPrint('📱 Current state: ProductDetailsLoaded with quantity: ${currentState.quantity}');
      
      final pd = currentState.productDetails;
      
      // STEP 1: Determine the correct variant ID FIRST (before stock validation)
      debugPrint('🔍 Step 1: Determining variant ID to add...');
      String productIdToAdd = event.productId;
      VariantCombination? targetVariant;
      try {
        // Build selected pairs using attribute_id and value_id
        // Helper to resolve attribute_id for an attribute name from variant_combinations
        String? findAttributeIdByName(String attributeName) {
          for (final combo in pd.variantCombinations) {
            for (final a in combo.attributes) {
              if (a.attributeName.toLowerCase() == attributeName.toLowerCase()) {
                return a.attributeId?.toString() ?? '';
              }
            }
          }
          return null;
        }

        // Build a lookup: attribute_id -> (value_name_lower -> value_id_from_combinations)
        final Map<String, Map<String, String>> attrIdNameToId = {};
        for (final combo in pd.variantCombinations) {
          for (final a in combo.attributes) {
            final String attrId = (a.attributeId ?? '').toString();
            final String valueId = (a.valueId ?? '').toString();
            final String valueNameKey = (a.valueName).toLowerCase().trim();
            if (attrId.isEmpty || valueId.isEmpty || valueNameKey.isEmpty) continue;
            attrIdNameToId.putIfAbsent(attrId, () => {});
            attrIdNameToId[attrId]![valueNameKey] = valueId;
          }
        }

        // structure to hold selected attr_id -> value_id (mapped via value name when needed)
        final Map<String, String> selectedByAttrId = {};

        // Add selected size/primary variant
        if (pd.selectedSize.isNotEmpty) {
          final String? attrId = findAttributeIdByName(pd.primaryVariantLabel);
          // find value_id for selected size from options (by name)
          final valName = pd.selectedSize;
          if ((attrId ?? '').isNotEmpty && valName.isNotEmpty) {
            final mapped = attrIdNameToId[attrId!]?[(valName.toLowerCase().trim())] ?? '';
            if (mapped.isNotEmpty) {
              selectedByAttrId[attrId] = mapped;
              debugPrint('📏 Added size to matching: attr_id=$attrId, value_id=$mapped, value_name=$valName');
            }
          }
        }

        // Add selected color (CRITICAL: must include color to match correct variant)
        if (pd.selectedColor.isNotEmpty) {
          // Try multiple color attribute name variations
          final List<String> colorAttrNames = ['COLOR NAME', 'COLOR', 'COLOUR', 'اللون', 'color name', 'color'];
          String? colorAttrId;
          String? colorValueId;
          
          for (final colorAttrName in colorAttrNames) {
            colorAttrId = findAttributeIdByName(colorAttrName);
            if (colorAttrId != null && colorAttrId.isNotEmpty) {
              final colorValName = pd.selectedColor;
              final mapped = attrIdNameToId[colorAttrId]?[(colorValName.toLowerCase().trim())] ?? '';
              if (mapped.isNotEmpty) {
                colorValueId = mapped;
                break;
              }
            }
          }
          
          if (colorAttrId != null && colorAttrId.isNotEmpty && colorValueId != null && colorValueId.isNotEmpty) {
            selectedByAttrId[colorAttrId] = colorValueId;
            debugPrint('🎨 Added color to matching: attr_id=$colorAttrId, value_id=$colorValueId, value_name=${pd.selectedColor}');
          } else {
            debugPrint('⚠️ Could not find color attribute_id or value_id for color: ${pd.selectedColor}');
          }
        }

        // Add selected material if available
        if (pd.selectedMaterial != null && pd.selectedMaterial!.isNotEmpty) {
          final List<String> materialAttrNames = ['MATERIAL NAME', 'MATERIAL', 'material name', 'material'];
          String? materialAttrId;
          String? materialValueId;
          
          for (final materialAttrName in materialAttrNames) {
            materialAttrId = findAttributeIdByName(materialAttrName);
            if (materialAttrId != null && materialAttrId.isNotEmpty) {
              final materialValName = pd.selectedMaterial!;
              final mapped = attrIdNameToId[materialAttrId]?[(materialValName.toLowerCase().trim())] ?? '';
              if (mapped.isNotEmpty) {
                materialValueId = mapped;
                break;
              }
            }
          }
          
          if (materialAttrId != null && materialAttrId.isNotEmpty && materialValueId != null && materialValueId.isNotEmpty) {
            selectedByAttrId[materialAttrId] = materialValueId;
            debugPrint('🧵 Added material to matching: attr_id=$materialAttrId, value_id=$materialValueId, value_name=${pd.selectedMaterial}');
          }
        }

        // Add selected heel height if available
        if (pd.selectedHeelHeightCm != null) {
          final List<String> heightAttrNames = ['HEIGHT', 'HEEL HEIGHT', 'heel height', 'height'];
          String? heightAttrId;
          String? heightValueId;
          
          for (final heightAttrName in heightAttrNames) {
            heightAttrId = findAttributeIdByName(heightAttrName);
            if (heightAttrId != null && heightAttrId.isNotEmpty) {
              // Convert heel height to string (e.g., 4.5 -> "4.5")
              final heightValName = pd.selectedHeelHeightCm!.toStringAsFixed(1);
              final mapped = attrIdNameToId[heightAttrId]?[(heightValName.toLowerCase().trim())] ?? '';
              if (mapped.isNotEmpty) {
                heightValueId = mapped;
                break;
              }
            }
          }
          
          if (heightAttrId != null && heightAttrId.isNotEmpty && heightValueId != null && heightValueId.isNotEmpty) {
            selectedByAttrId[heightAttrId] = heightValueId;
            debugPrint('👠 Added heel height to matching: attr_id=$heightAttrId, value_id=$heightValueId, value_name=${pd.selectedHeelHeightCm}');
          }
        }

        // Add other dynamic attributes from variantAttributeOptions
        for (final opt in pd.variantAttributeOptions) {
          if (opt.selectedValue.isEmpty) continue;
          final String? attrId = findAttributeIdByName(opt.attributeName);
          final valName = opt.selectedValue;
          if ((attrId ?? '').isNotEmpty && valName.isNotEmpty) {
            final mapped = attrIdNameToId[attrId!]?[(valName.toLowerCase().trim())] ?? '';
            if (mapped.isNotEmpty) {
              selectedByAttrId[attrId] = mapped;
              debugPrint('🔧 Added ${opt.attributeName} to matching: attr_id=$attrId, value_id=$mapped, value_name=$valName');
            }
          }
        }

        debugPrint('🎯 Variant resolution (by ids) — ' + selectedByAttrId.entries.map((e) => 'attr_id=${e.key}:value_id=${e.value}').join(', '));

        bool matchesAll(VariantCombination v) {
          // For each selected pair attr_id -> value_id there must be an attribute in the variant with same ids
          for (final entry in selectedByAttrId.entries) {
            final String attrId = entry.key;
            final String valId = entry.value;
            final bool hasPair = v.attributes.any((a) =>
              (a.attributeId?.toString() ?? '') == attrId && (a.valueId?.toString() ?? '') == valId
            );
            if (!hasPair) return false;
          }
          return true;
        }

        // Try to find exact match by attribute IDs
        final matchingVariants = pd.variantCombinations.where((v) => matchesAll(v)).toList();
        
        if (matchingVariants.length == 1) {
          final matched = matchingVariants.first;
          debugPrint('✅ Matched variantId=${matched.variantId} with attributes: '+
            matched.attributes.map((a) => '${a.attributeName}:${a.valueName}').join(', '));
          productIdToAdd = matched.variantId;
          targetVariant = matched;
        } else if (matchingVariants.length > 1) {
          debugPrint('⚠️ Multiple variants matched (${matchingVariants.length}). Using first match.');
          final matched = matchingVariants.first;
          productIdToAdd = matched.variantId;
          targetVariant = matched;
        } else {
          // No exact match by IDs - try matching by attribute names as fallback
          debugPrint('⚠️ No exact match by IDs. Trying fallback matching by attribute names...');
          final Map<String, String> selectedByAttributeName = {};
          
          if (pd.selectedSize.isNotEmpty) {
            selectedByAttributeName[pd.primaryVariantLabel] = pd.selectedSize;
            selectedByAttributeName['size'] = pd.selectedSize;
            selectedByAttributeName['SIZE'] = pd.selectedSize;
          }
          
          if (pd.selectedColor.isNotEmpty) {
            selectedByAttributeName['color'] = pd.selectedColor;
            selectedByAttributeName['colour'] = pd.selectedColor;
            selectedByAttributeName['COLOR NAME'] = pd.selectedColor;
            selectedByAttributeName['اللون'] = pd.selectedColor;
          }
          
          if (pd.selectedMaterial != null && pd.selectedMaterial!.isNotEmpty) {
            selectedByAttributeName['MATERIAL NAME'] = pd.selectedMaterial!;
            selectedByAttributeName['material name'] = pd.selectedMaterial!;
          }
          
          if (pd.selectedHeelHeightCm != null) {
            final heightStr = pd.selectedHeelHeightCm!.toStringAsFixed(1);
            selectedByAttributeName['HEIGHT'] = heightStr;
            selectedByAttributeName['height'] = heightStr;
          }
          
          for (final opt in pd.variantAttributeOptions) {
            if (opt.selectedValue.isNotEmpty) {
              selectedByAttributeName[opt.attributeName] = opt.selectedValue;
            }
          }
          
          final nameMatchedVariants = pd.variantCombinations.where((v) {
            for (final entry in selectedByAttributeName.entries) {
              final vVal = v.getAttributeValue(entry.key);
              if (vVal == null || vVal.toLowerCase() != entry.value.toLowerCase()) {
                return false;
              }
            }
            return true;
          }).toList();
          
          if (nameMatchedVariants.length == 1) {
            final matched = nameMatchedVariants.first;
            debugPrint('✅ Matched by attribute names: variantId=${matched.variantId}');
            productIdToAdd = matched.variantId;
            targetVariant = matched;
          } else if (nameMatchedVariants.length > 1) {
            debugPrint('⚠️ Multiple variants matched by names (${nameMatchedVariants.length}). Using first match.');
            final matched = nameMatchedVariants.first;
            productIdToAdd = matched.variantId;
            targetVariant = matched;
          } else {
            // Final fallback: use selected size option's variant id if available
            final SizeOption selectedSize = pd.sizeOptions.firstWhere(
              (s) => s.isSelected,
              orElse: () => pd.sizeOptions.isNotEmpty ? pd.sizeOptions.first : const SizeOption(id: '', name: '', isAvailable: false, isRecommended: false, isSelected: false),
            );
            if (selectedSize.id.isNotEmpty) {
              productIdToAdd = selectedSize.id;
              debugPrint('⚠️ No match found. Falling back to sizeOption.variantId=${selectedSize.id} for size="${selectedSize.name}"');
              // Try to find variant by this ID
              try {
                targetVariant = pd.variantCombinations.firstWhere(
                  (v) => v.variantId == productIdToAdd,
                );
              } catch (_) {
                debugPrint('❌ Could not find variant with variantId=$productIdToAdd');
              }
            } else {
              debugPrint('❌ No matching variant found and no size variantId available, using productId=${productIdToAdd}');
              // Try to find variant by productId
              try {
                targetVariant = pd.variantCombinations.firstWhere(
                  (v) => v.variantId == productIdToAdd,
                );
              } catch (_) {
                debugPrint('❌ Could not find variant with variantId=$productIdToAdd');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error resolving variant ID: $e');
      }
      
      // If we still don't have a target variant, try to find it by the resolved productIdToAdd
      if (targetVariant == null && productIdToAdd.isNotEmpty) {
        try {
          targetVariant = pd.variantCombinations.firstWhere(
            (v) => v.variantId == productIdToAdd,
          );
          debugPrint('✅ Found target variant by productIdToAdd: ${targetVariant.variantId}');
        } catch (_) {
          debugPrint('⚠️ Could not find variant with variantId=$productIdToAdd');
        }
      }
      
      // STEP 2: Validate stock on the TARGET variant (the one we're actually adding)
      debugPrint('🔍 Step 2: Validating stock for variantId=$productIdToAdd');
      int quantityToAdd = currentState.quantity;
      bool quantityWasClamped = false;
      
      if (targetVariant != null) {
        debugPrint('📦 Target variant: variantId=${targetVariant.variantId}, inStock=${targetVariant.inStock}, quantityAvailable=${targetVariant.quantityAvailable}');
        
        // Check inStock first
        if (!targetVariant.inStock) {
          debugPrint('❌ Variant is marked as out of stock');
          final isArabic = AppLocalizationService().currentLocale.languageCode == 'ar';
          final msg = isArabic
              ? 'هذا المنتج غير متوفر حالياً في المخزون.'
              : 'This product is currently out of stock.';
          emit(ProductDetailsError(msg));
          return;
        }
        
        // Check quantityAvailable
        final quantityAvailable = targetVariant.quantityAvailable;
        if (quantityAvailable != null) {
          if (quantityAvailable <= 0) {
            debugPrint('❌ Variant quantityAvailable is 0 or negative');
            final isArabic = AppLocalizationService().currentLocale.languageCode == 'ar';
            final msg = isArabic
                ? 'هذا المنتج غير متوفر حالياً في المخزون.'
                : 'This product is currently out of stock.';
            emit(ProductDetailsError(msg));
            return;
          }
          
          // Check if there's already an item in cart with this variant ID
          int existingCartQuantity = 0;
          final variantIdToCheck = targetVariant.variantId;
          if (cartBloc.state is CartLoaded) {
            final cartState = cartBloc.state as CartLoaded;
            try {
              final existingItem = cartState.cartItems.firstWhere(
                (item) => item.product.id == variantIdToCheck,
              );
              existingCartQuantity = existingItem.quantity;
              debugPrint('📋 Found existing cart item: quantity=$existingCartQuantity');
            } catch (e) {
              debugPrint('ℹ️ Item not found in cart, using 0 for existing quantity');
            }
          }
          
          // Calculate available quantity (total available - already in cart)
          final maxAllowed = quantityAvailable.toInt();
          final available = maxAllowed - existingCartQuantity;
          
          debugPrint('🔢 Stock check: quantity=${currentState.quantity}, existingCart=$existingCartQuantity, maxAllowed=$maxAllowed, available=$available');
          
          // If user tries to add more than available, clamp to available quantity
          if (currentState.quantity > available && available > 0) {
            quantityToAdd = available;
            quantityWasClamped = true;
            debugPrint('⚠️ Quantity clamped from ${currentState.quantity} to $quantityToAdd (available: $available)');
          }
        } else {
          debugPrint('⚠️ quantityAvailable is null, but inStock=true. Proceeding with stock check...');
        }
      } else {
        debugPrint('⚠️ Could not find target variant for stock validation. Proceeding anyway...');
      }
      
      emit(currentState.copyWith(isAdding: true));
      debugPrint('⏳ Emitting loading state...');
      
      debugPrint('🚀 Calling addToCart use case...');

      debugPrint('📤 addToCart payload — productIdToAdd=$productIdToAdd, colorId=${event.colorId}, sizeId=${event.sizeId}, qty=$quantityToAdd');
      final result = await addToCart(AddToCartParams(
        productId: productIdToAdd,
        colorId: event.colorId,
        sizeId: event.sizeId,
        quantity: quantityToAdd,
      ));
      
      debugPrint('📦 addToCart result received: ${result.toString()}');
      
      result.fold(
        (failure) {
          debugPrint('❌ Add to cart failed: ${failure.message}');
          
          // Check if this is a stock-related error - if so, don't show error since we already clamped
          final lowerMessage = failure.message.toLowerCase();
          final isStockError = lowerMessage.contains('available') || 
                              lowerMessage.contains('stock') ||
                              lowerMessage.contains('quantity') ||
                              lowerMessage.contains('exceed');
          
          if (isStockError) {
            // For stock errors, we've already clamped, so just refresh cart and show success
            debugPrint('⚠️ Stock error from API (should not happen after clamping), refreshing cart state');
            cartBloc.add(const RefreshCart());
            
            // If quantity was clamped, show the clamped dialog, otherwise just close
            if (quantityWasClamped) {
              final isArabic = AppLocalizationService().currentLocale.languageCode == 'ar';
              final message = isArabic
                  ? 'تم إضافة جميع الكمية المتاحة ($quantityToAdd قطعة) إلى السلة.'
                  : 'We added all available quantity ($quantityToAdd item(s)) to your cart.';
              emit(ProductDetailsQuantityClamped(message, quantityToAdd));
            } else {
              emit(currentState.copyWith(isAdding: false));
            }
          } else {
            // For non-stock errors, show the error
            emit(ProductDetailsError(failure.message));
          }
        },
        (cartItem) {
          debugPrint('✅ Cart item added successfully via API: ${cartItem.toString()}');
          
          // The item has already been added to the cart via the API in the repository
          // Just refresh the cart to get the updated state
          debugPrint('🔄 Refreshing cart to get updated state...');
          cartBloc.add(const RefreshCart());
          
          // If quantity was clamped, emit a special state to show dialog
          if (quantityWasClamped) {
            final isArabic = AppLocalizationService().currentLocale.languageCode == 'ar';
            final message = isArabic
                ? 'تم إضافة جميع الكمية المتاحة ($quantityToAdd قطعة) إلى السلة.'
                : 'We added all available quantity ($quantityToAdd item(s)) to your cart.';
            emit(ProductDetailsQuantityClamped(message, quantityToAdd));
          } else {
            emit(currentState.copyWith(isAdding: false));
          }
          debugPrint('✅ Final state emitted: isAdding = false');
        },
      );
    } else {
      debugPrint('⚠️ State is not ProductDetailsLoaded: ${state.runtimeType}');
    }
  }

  void _onIncrementQty(
    IncrementQuantityEvent event,
    Emitter<ProductDetailsState> emit,
  ) {
    if (state is ProductDetailsLoaded) {
      final s = state as ProductDetailsLoaded;
      final pd = s.productDetails;
      
      // Find the currently selected variant
      final selectedVariant = _findSelectedVariant(pd);
      if (selectedVariant == null) {
        debugPrint('⚠️ Cannot find selected variant, allowing increment');
        final newQuantity = s.quantity + 1;
        emit(s.copyWith(quantity: newQuantity));
        return;
      }
      
      // Get available quantity for this variant
      final quantityAvailable = selectedVariant.quantityAvailable ?? double.infinity;
      if (quantityAvailable == 0) {
        debugPrint('⚠️ Product is out of stock, cannot increment');
        return;
      }
      
      // Check if there's already an item in cart with this variant ID
      int existingCartQuantity = 0;
      if (cartBloc.state is CartLoaded) {
        final cartState = cartBloc.state as CartLoaded;
        try {
          final existingItem = cartState.cartItems.firstWhere(
            (item) => item.product.id == selectedVariant.variantId,
          );
          existingCartQuantity = existingItem.quantity;
        } catch (e) {
          // Item not found in cart, existingCartQuantity remains 0
          debugPrint('ℹ️ Item not found in cart, using 0 for existing quantity');
        }
      }
      
      // Calculate total quantity (current selection + already in cart)
      final totalQuantity = s.quantity + existingCartQuantity;
      final maxAllowed = quantityAvailable.toInt();
      
      // Always prevent incrementing if it would exceed available stock
      if (totalQuantity >= maxAllowed) {
        debugPrint('⚠️ Cannot increment: total quantity ($totalQuantity) would exceed available stock ($maxAllowed)');
        // Don't emit error, just silently prevent the increment
        return;
      }
      
      final newQuantity = s.quantity + 1;
      debugPrint('➕ Incrementing quantity from ${s.quantity} to $newQuantity (available: $maxAllowed, in cart: $existingCartQuantity)');
      emit(s.copyWith(quantity: newQuantity));
    }
  }

  void _onDecrementQty(
    DecrementQuantityEvent event,
    Emitter<ProductDetailsState> emit,
  ) {
    if (state is ProductDetailsLoaded) {
      final s = state as ProductDetailsLoaded;
      if (s.quantity > 1) {
        final newQuantity = s.quantity - 1;
        debugPrint('➖ Decrementing quantity from ${s.quantity} to $newQuantity');
        emit(s.copyWith(quantity: newQuantity));
      } else {
        debugPrint('⚠️ Cannot decrement quantity below 1 (current: ${s.quantity})');
      }
    }
  }
}
