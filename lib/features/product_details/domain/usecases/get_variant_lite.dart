import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/product_details.dart';
import '../repositories/product_details_repository.dart';

/// Fetches variant data by selected attribute value IDs.
/// Used as fallback when normal API has not returned variant_combinations.
class GetVariantLite {
  final ProductDetailsRepository repository;

  const GetVariantLite(this.repository);

  Future<Either<Failure, ProductDetails>> call(
    String productId,
    List<int> attributeValueIds,
  ) async {
    return repository.getVariantLite(productId, attributeValueIds);
  }
}
