import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Future<List<Map<String, dynamic>>> fetchOrdersByStatus(String status) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: status)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      _logger.e("Error fetching orders", error: e);
      return [];
    }
  }

  fetchOrdersByItemId(String itemId) {}
}
