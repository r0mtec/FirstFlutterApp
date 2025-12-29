import 'package:lab/data/repositories/api_interface.dart';
import 'package:lab/domain/models/card_data.dart';

class CardsRepository {
  final ApiInterface _api;

  CardsRepository(this._api);

  Future<List<CardData>> loadData({String? q}) async {
    final query = (q ?? '').trim();

    final data = await _api.loadData(query);
    return data ?? <CardData>[];
  }
}