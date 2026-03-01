part of 'product_details_bloc.dart';

abstract class ProductDetailsState extends Equatable {
  const ProductDetailsState();

  @override
  List<Object?> get props => [];
}

class ProductDetailsInitial extends ProductDetailsState {}

class ProductDetailsLoading extends ProductDetailsState {
  /// When navigating from a product card, show this data immediately
  /// (image, brand, title, price) and skeleton for the rest until API responds.
  final ProductDetailsCardPreview? cardPreview;

  const ProductDetailsLoading({this.cardPreview});

  @override
  List<Object?> get props => [cardPreview];
}

class ProductDetailsLoaded extends ProductDetailsState {
  final ProductDetails productDetails;
  final int quantity;
  final bool isAdding;
  /// True while we are recomputing variant/attribute availability
  /// (e.g. after a color/attribute selection) so the UI can show a loader.
  final bool isVariantFilterLoading;
  /// Variant combinations from the normal API (api_load=normal).
  /// Kept separate from lite product so they are not overridden; used for
  /// matching on attribute click. Lite response has empty variant_combinations.
  final List<VariantCombination>? variantCombinationsFromNormalApi;

  const ProductDetailsLoaded(
    this.productDetails, {
    this.quantity = 1,
    this.isAdding = false,
    this.isVariantFilterLoading = false,
    this.variantCombinationsFromNormalApi,
  });

  ProductDetailsLoaded copyWith({
    ProductDetails? productDetails,
    int? quantity,
    bool? isAdding,
    bool? isVariantFilterLoading,
    List<VariantCombination>? variantCombinationsFromNormalApi,
  }) {
    return ProductDetailsLoaded(
      productDetails ?? this.productDetails,
      quantity: quantity ?? this.quantity,
      isAdding: isAdding ?? this.isAdding,
      isVariantFilterLoading:
          isVariantFilterLoading ?? this.isVariantFilterLoading,
      variantCombinationsFromNormalApi:
          variantCombinationsFromNormalApi ?? this.variantCombinationsFromNormalApi,
    );
  }

  @override
  List<Object?> get props => [
        productDetails,
        quantity,
        isAdding,
        isVariantFilterLoading,
        variantCombinationsFromNormalApi,
      ];
}

class ProductDetailsError extends ProductDetailsState {
  final String message;

  const ProductDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductDetailsAddedToCart extends ProductDetailsState {}

class ProductDetailsQuantityClamped extends ProductDetailsState {
  final String message;
  final int quantityAdded;

  const ProductDetailsQuantityClamped(this.message, this.quantityAdded);

  @override
  List<Object?> get props => [message, quantityAdded];
}
