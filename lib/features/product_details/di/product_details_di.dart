import 'package:get_it/get_it.dart';
import 'dart:developer' as developer;
import '../data/repositories/product_details_repository_impl.dart';
import '../data/datasources/product_details_remote_data_source.dart';
import '../domain/repositories/product_details_repository.dart';
import 'package:zalando_clone_app/core/network/api_client.dart';
import '../domain/usecases/add_to_cart.dart';
import '../domain/usecases/get_product_details.dart';
import '../domain/usecases/get_variant_lite.dart';
import '../domain/usecases/select_color.dart';
import '../domain/usecases/select_size.dart';
import '../domain/usecases/toggle_favorite.dart';
import '../presentation/bloc/product_details_bloc.dart';
import '../../cart/presentation/bloc/cart_bloc.dart';
import '../../cart/domain/repositories/cart_repository.dart';

class ProductDetailsDI {
  static void setup(GetIt getIt) {
    // Data Source
    getIt.registerLazySingleton<ProductDetailsRemoteDataSource>(
      () => ProductDetailsRemoteDataSourceImpl(getIt<ApiClient>()),
    );

    // Repository
    getIt.registerLazySingleton<ProductDetailsRepository>(
      () => ProductDetailsRepositoryImpl(
        cartRepository: getIt<CartRepository>(),
        remoteDataSource: getIt<ProductDetailsRemoteDataSource>(),
      ),
    );

    // Use Cases
    getIt.registerLazySingleton(() => GetProductDetails(getIt()));
    getIt.registerLazySingleton(() => GetVariantLite(getIt()));
    getIt.registerLazySingleton(() => ToggleFavorite(getIt()));
    getIt.registerLazySingleton(() => SelectColor(getIt()));
    getIt.registerLazySingleton(() => SelectSize(getIt()));
    getIt.registerLazySingleton(() => AddToCart(getIt()));

    // BLoC
    getIt.registerFactory(
      () {
        developer.log('🏭 Creating ProductDetailsBloc...');
        final cartBloc = getIt<CartBloc>();
        developer.log('🛒 CartBloc retrieved: ${cartBloc.runtimeType}');
        
        return ProductDetailsBloc(
          getProductDetails: getIt(),
          getVariantLite: getIt(),
          toggleFavorite: getIt(),
          selectColor: getIt(),
          selectSize: getIt(),
          addToCart: getIt(),
          cartBloc: cartBloc,
        );
      },
    );
  }
}
