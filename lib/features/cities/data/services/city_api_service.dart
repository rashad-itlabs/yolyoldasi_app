import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/city.dart';
import '../models/city_model.dart';

/// `GET /cities` — API.md §6. Public, so it works before sign-in.
class CityApiService {
  const CityApiService(this._client);

  final ApiClient _client;

  FutureResult<List<City>> list() =>
      _client.getList(Api.cities, parse: CityModel.fromJson);
}
