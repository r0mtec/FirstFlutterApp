import 'package:lab/domain/models/card.dart';

abstract class ApiInterface {
  Future<List<CardData>?> loadData(String query);
}
