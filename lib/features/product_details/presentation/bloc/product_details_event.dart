part of 'product_details_bloc.dart';

abstract class ProductDetailsEvent extends Equatable {
  const ProductDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProductDetails extends ProductDetailsEvent {
  final String productId;
  final String productType;
  /// Optional preview from the product card (image, brand, title, price)
  /// to show immediately while full details are loading.
  final ProductDetailsCardPreview? cardPreview;

  const LoadProductDetails(
    this.productId, {
    this.productType = 'variant',
    this.cardPreview,
  });

  @override
  List<Object?> get props => [productId, productType, cardPreview];
}

class ToggleFavoriteEvent extends ProductDetailsEvent {
  final String productId;

  const ToggleFavoriteEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class IncrementQuantityEvent extends ProductDetailsEvent {
  final int? maxAvailable;
  final String? variantId;

  const IncrementQuantityEvent({
    this.maxAvailable,
    this.variantId,
  });

  @override
  List<Object?> get props => [maxAvailable, variantId];
}

class DecrementQuantityEvent extends ProductDetailsEvent {}

class ResetQuantityEvent extends ProductDetailsEvent {
  final int quantity;

  const ResetQuantityEvent({this.quantity = 1});

  @override
  List<Object?> get props => [quantity];
}

class ResetAddingStateEvent extends ProductDetailsEvent {}

class SelectColorEvent extends ProductDetailsEvent {
  final String productId;
  final String colorId;

  const SelectColorEvent({
    required this.productId,
    required this.colorId,
  });

  @override
  List<Object?> get props => [productId, colorId];
}

class SelectSizeEvent extends ProductDetailsEvent {
  final String productId;
  final String sizeId;

  const SelectSizeEvent({
    required this.productId,
    required this.sizeId,
  });

  @override
  List<Object?> get props => [productId, sizeId];
}

class AddToCartEvent extends ProductDetailsEvent {
  final String productId;
  final String colorId;
  final String sizeId;
  final int quantity;

  const AddToCartEvent({
    required this.productId,
    required this.colorId,
    required this.sizeId,
    required this.quantity,
  });

  @override
  List<Object?> get props => [productId, colorId, sizeId, quantity];
}

class SelectMaterialEvent extends ProductDetailsEvent {
  final String productId;
  final String material;

  const SelectMaterialEvent({required this.productId, required this.material});

  @override
  List<Object?> get props => [productId, material];
}

class SelectHeelHeightEvent extends ProductDetailsEvent {
  final String productId;
  final double heelHeightCm;

  const SelectHeelHeightEvent({required this.productId, required this.heelHeightCm});

  @override
  List<Object?> get props => [productId, heelHeightCm];
}

class FilterVariantsByAttributeEvent extends ProductDetailsEvent {
  final String productId;
  final String attributeName;
  final String attributeValue;

  const FilterVariantsByAttributeEvent({
    required this.productId,
    required this.attributeName,
    required this.attributeValue,
  });

  @override
  List<Object?> get props => [productId, attributeName, attributeValue];
}

/// Explicitly select a concrete variant by its `variantId` and update images/UI.
/// This is used by variant selectors (color, material, etc.) once they resolve
/// which `VariantCombination` should be active.
class SelectVariantByIdEvent extends ProductDetailsEvent {
  final String variantId;

  const SelectVariantByIdEvent(this.variantId);

  @override
  List<Object?> get props => [variantId];
}

/// Internal event used to load the full variant combinations/attributes
/// payload (api_load = normal) after the initial lite product load has
/// already populated the UI.
class LoadProductVariantsCombinationsEvent extends ProductDetailsEvent {
  final String productId;
  final String productType;

  const LoadProductVariantsCombinationsEvent({
    required this.productId,
    this.productType = 'variant',
  });

  @override
  List<Object?> get props => [productId, productType];
}

/// Internal event: merge full variant data (from normal API) into current product.
/// Fired when the normal API completes; can complete before or after lite.
class MergeFullVariantDataEvent extends ProductDetailsEvent {
  final ProductDetails fullDetails;

  const MergeFullVariantDataEvent({required this.fullDetails});

  @override
  List<Object?> get props => [fullDetails];
}

/// Fallback: when user clicks an attribute and normal API has not provided
/// variant_combinations (loading, empty, or failed), fetch variant data via
/// /ecom/get/variant/lite with current selected attribute value IDs.
class FetchVariantLiteFallbackEvent extends ProductDetailsEvent {
  final String productId;
  final List<int> attributeValueIds;

  const FetchVariantLiteFallbackEvent({
    required this.productId,
    required this.attributeValueIds,
  });

  @override
  List<Object?> get props => [productId, attributeValueIds];
}
