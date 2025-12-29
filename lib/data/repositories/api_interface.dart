import 'package:lab/domain/models/card_data.dart';

abstract class ApiInterface {
  Future<List<CardData>?> loadData(String query);
}
