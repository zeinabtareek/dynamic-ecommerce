import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import '../controllers/dynamic_variant_controller.dart' show DynamicVariantController, ValueState;
import '../utils/attribute_label_helper.dart';

/// Fully dynamic variant selector widget that works with unlimited attributes
/// 
/// Features:
/// - Dynamically renders all variant_attributes from API
/// - Works purely with attribute_id and value_id
/// - Auto-enables/disables values based on stock and current selection
/// - Updates price, stock, and images automatically
/// - Handles "Out of Stock" scenarios
/// 
/// Usage:
/// ```dart
/// DynamicVariantSelector(
///   productDetails: productDetails,
///   onVariantChanged: (controller) {
///     // Handle variant change
///     print('New variant: ${controller.variantId}');
///     print('Price: ${controller.currentPrice}');
///     print('In stock: ${controller.inStock}');
///   },
/// )
/// ```
class DynamicVariantSelector extends StatefulWidget {
  final ProductDetails productDetails;
  final Function(DynamicVariantController)? onVariantChanged;
  
  const DynamicVariantSelector({
    super.key,
    required this.productDetails,
    this.onVariantChanged,
  });

  @override
  State<DynamicVariantSelector> createState() => _DynamicVariantSelectorState();
}

class _DynamicVariantSelectorState extends State<DynamicVariantSelector> {
  late DynamicVariantController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DynamicVariantController();
    _controller.initialize(widget.productDetails);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DynamicVariantSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productDetails != widget.productDetails) {
      _controller.initialize(widget.productDetails);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.onVariantChanged != null) {
      widget.onVariantChanged!(_controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DynamicVariantController>.value(
      value: _controller,
      child: Consumer<DynamicVariantController>(
        builder: (context, controller, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Render all variant attributes dynamically
              ...widget.productDetails.variantAttributeOptions.map((attrOption) {
                final attributeId = int.tryParse(attrOption.attributeId ?? '');
                
                if (attributeId == null) {
                  debugPrint('⚠️ DynamicVariantSelector: Skipping attribute "${attrOption.attributeName}" - no valid attribute_id');
                  return const SizedBox.shrink();
                }
                
                return _AttributeSection(
                  attributeName: attrOption.attributeName,
                  attributeId: attributeId,
                  values: attrOption.values,
                  controller: controller,
                );
              }).toList(),
              
              // Spacing
              SizedBox(height: ResponsiveConstants.mdSpacing),
              
              // Variant info display
              _VariantInfoDisplay(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

/// Section for a single attribute with its values
class _AttributeSection extends StatelessWidget {
  final String attributeName;
  final int attributeId;
  final List<VariantAttributeValue> values;
  final DynamicVariantController controller;

  const _AttributeSection({
    required this.attributeName,
    required this.attributeId,
    required this.values,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    
    // Get available values for this attribute
    final availableValueIds = controller.getAvailableValuesForAttribute(attributeId);
    
    // Get currently selected value for this attribute
    final selectedValueId = controller.selectedAttributes[attributeId];
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveConstants.mdSpacing),
      padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attribute name
          Text(
            localizedAttributeLabel(context, attributeName),
            style: AppFonts.getTextStyle(
              fontSize: ResponsiveConstants.mdFontSize,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          
          SizedBox(height: ResponsiveConstants.smSpacing),
          
          // Values - Show ALL values, but disable unavailable ones
          Wrap(
            spacing: ResponsiveConstants.smSpacing,
            runSpacing: ResponsiveConstants.smSpacing,
            children: values.map((value) {
              final valueId = int.tryParse(value.id);
              
              if (valueId == null) {
                debugPrint('⚠️ DynamicVariantSelector: Skipping value "${value.name}" - no valid value_id');
                return const SizedBox.shrink();
              }
              
              // On initial load, when the controller has not yet built
              // selectedAttributes, fall back to the model's isSelected flag
              // (set from `selected_variant` in the first API response).
              final isSelected = selectedValueId != null
                  ? selectedValueId == valueId
                  : value.isSelected;
              
              // Get the state of this value (three-state logic)
              final valueState = controller.getValueState(attributeId, valueId);
              
              // Determine button properties based on state
              final isFullyAvailable = valueState == ValueState.fullyAvailable;
              final existsButIncompatible = valueState == ValueState.existsButIncompatible;
              final doesNotExist = valueState == ValueState.doesNotExist;
              
              // Button is enabled if:
              // - Not selected AND (fully available OR exists but incompatible)
              // - Incompatible values are clickable to allow changing selection path
              // - Only disabled if value does not exist at all
              final isEnabled = !isSelected && !doesNotExist;
              
              // Get stock information for this value
              final stockInfo = controller.getStockInfoForValue(attributeId, valueId);
              
              return _ValueButton(
                valueName: value.name,
                isSelected: isSelected,
                isFullyAvailable: isFullyAvailable,
                existsButIncompatible: existsButIncompatible,
                doesNotExist: doesNotExist,
                primary: primary,
                colorScheme: colorScheme,
                stockInfo: stockInfo,
                onTap: isEnabled
                    ? () {
                        debugPrint('🎯 DynamicVariantSelector: Selected $attributeName (id: $attributeId) → ${value.name} (id: $valueId)');
                        debugPrint('   State: $valueState');
                        debugPrint('   Stock info: ${stockInfo['inStock']}, Qty: ${stockInfo['quantity']}');
                        // Sync with latest product details and variant_combinations from normal API
                        try {
                          final state = context.read<ProductDetailsBloc>().state;
                          if (state is ProductDetailsLoaded) {
                            controller.updateProductDetails(state.productDetails);
                            controller.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
                          }
                        } catch (_) {}
                        controller.selectAttributeValue(attributeId, valueId);
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Button for a single attribute value with three-state logic
class _ValueButton extends StatelessWidget {
  final String valueName;
  final bool isSelected;
  final bool isFullyAvailable;
  final bool existsButIncompatible;
  final bool doesNotExist;
  final Color primary;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final Map<String, dynamic>? stockInfo;

  const _ValueButton({
    required this.valueName,
    required this.isSelected,
    required this.isFullyAvailable,
    required this.existsButIncompatible,
    required this.doesNotExist,
    required this.primary,
    required this.colorScheme,
    this.onTap,
    this.stockInfo,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = stockInfo?['quantity'] as int? ?? 0;
    final isLowStock = isFullyAvailable && quantity > 0 && quantity <= 5;
    
    // Determine colors and styles based on state
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    double borderWidth;
    double textOpacity;
    
    // STANDARDIZED BUTTON STATES - Only 3 clear states:
    // 1. Selected: Orange background + White text
    // 2. Available (Not Selected): White background + Orange border + Orange text
    // 3. Unavailable: Light gray background + Gray text + Not clickable
    
    if (isSelected) {
      // ✅ STATE 1: Selected State
      // Orange background, white text, no ambiguity
      backgroundColor = primary;
      borderColor = primary;
      textColor = colorScheme.onPrimary; // White text
      borderWidth = 2;
      textOpacity = 1.0;
    } else if (doesNotExist) {
      // ✅ STATE 3: Unavailable / Hidden State
      // Light gray background, gray text, not clickable
      backgroundColor = Colors.grey.shade200; // Light gray background
      borderColor = Colors.grey.shade400; // Light gray border
      textColor = Colors.grey.shade600; // Gray text
      borderWidth = 1;
      textOpacity = 1.0; // Full opacity but gray color
    } else {
      // ✅ STATE 2: Available (Not Selected) State
      // Transparent background, orange border, orange text, clickable
      // This applies to both fullyAvailable and existsButIncompatible
      // User can click to change selection even if incompatible
      backgroundColor = Colors.transparent; // Transparent background
      borderColor = primary; // Orange border
      textColor = primary; // Orange text
      borderWidth = 1;
      textOpacity = 1.0;
    }
    
    return GestureDetector(
      onTap: onTap,
      behavior: onTap != null ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      child: Opacity(
        opacity: textOpacity,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveConstants.mdPadding,
            vertical: ResponsiveConstants.smPadding,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            borderRadius: BorderRadius.circular(ResponsiveConstants.smRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueName,
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              // Show stock indicator for low stock items (only for fully available)
              if (isLowStock && !isSelected && isFullyAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Only $quantity left',
                    style: AppFonts.getTextStyle(
                      fontSize: ResponsiveConstants.xsFontSize,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display current variant information (price, stock, variant_id)
class _VariantInfoDisplay extends StatelessWidget {
  final DynamicVariantController controller;

  const _VariantInfoDisplay({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        border: Border.all(
          color: controller.inStock
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price
          Row(
            children: [
              Text(
                'Price: ',
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '\$${controller.currentPrice.toStringAsFixed(2)}',
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.lgFontSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          
          SizedBox(height: ResponsiveConstants.xsSpacing),
          
          // Stock status
          Row(
            children: [
              Icon(
                controller.inStock ? Icons.check_circle : Icons.error_outline,
                color: controller.inStock ? Colors.green : Colors.red,
                size: 20,
              ),
              SizedBox(width: ResponsiveConstants.xsSpacing),
              Text(
                controller.inStock
                    ? 'In Stock (${controller.quantityAvailable} available)'
                    : 'Out of Stock',
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w600,
                  color: controller.inStock ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          
          SizedBox(height: ResponsiveConstants.xsSpacing),
          
          // Variant ID
          if (controller.variantId.isNotEmpty)
            Text(
              'Variant ID: ${controller.variantId}',
              style: AppFonts.getTextStyle(
                fontSize: ResponsiveConstants.smFontSize,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          
          // Selected attributes debug info
          if (controller.selectedAttributes.isNotEmpty) ...[
            SizedBox(height: ResponsiveConstants.xsSpacing),
            Text(
              'Selected: ${_formatSelectedAttributes(controller)}',
              style: AppFonts.getTextStyle(
                fontSize: ResponsiveConstants.smFontSize,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSelectedAttributes(DynamicVariantController controller) {
    final parts = <String>[];
    
    for (final entry in controller.selectedAttributes.entries) {
      final attrId = entry.key;
      final valueId = entry.value;
      
      final attrName = controller.getAttributeNameById(attrId) ?? 'Attr$attrId';
      final valueName = controller.getValueNameByIds(attrId, valueId) ?? 'Val$valueId';
      
      parts.add('$attrName=$valueName');
    }
    
    return parts.join(', ');
  }
}
