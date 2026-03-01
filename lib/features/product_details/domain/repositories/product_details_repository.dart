import 'package:dartz/dartz.dart';
import '../entities/product_details.dart';
import '../../../../core/errors/failures.dart';
import '../../../cart/domain/entities/cart_item.dart';

abstract class ProductDetailsRepository {
  Future<Either<Failure, ProductDetails>> getProductDetails(
    String productId, {
    String productType = 'variant',
    String apiLoad = 'normal',
  });

  /// Fallback: fetch variant data by selected attribute value IDs when normal API
  /// has not returned variant_combinations. Used on attribute button click.
  Future<Either<Failure, ProductDetails>> getVariantLite(
    String productId,
    List<int> attributeValueIds,
  );

  Future<Either<Failure, void>> toggleFavorite(String productId);
  Future<Either<Failure, void>> selectColor(String productId, String colorId);
  Future<Either<Failure, void>> selectSize(String productId, String sizeId);
  Future<Either<Failure, CartItem>> addToCart(String productId, String colorId, String sizeId, int quantity);
}
