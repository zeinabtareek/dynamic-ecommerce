import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product_details.dart';
import '../repositories/product_details_repository.dart';

class GetProductDetails implements UseCase<ProductDetails, String> {
  final ProductDetailsRepository repository;

  const GetProductDetails(this.repository);

  @override
  Future<Either<Failure, ProductDetails>> call(
    String productId, {
    String productType = 'variant',
    String apiLoad = 'normal',
  }) async {
    return await repository.getProductDetails(
      productId,
      productType: productType,
      apiLoad: apiLoad,
    );
  }
}
