import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      print("Error fetching orders: $e");
      return [];
    }
  }
}
