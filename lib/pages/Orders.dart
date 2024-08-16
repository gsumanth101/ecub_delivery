import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrdersService _ordersService = OrdersService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
    });

    String status = _selectedIndex == 0 ? 'Pending' : 'Completed';
    List<Map<String, dynamic>> orders =
        await _ordersService.fetchOrdersByStatus(status);

    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  Widget _buildTabButton(int index, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              _fetchOrders();
            });
          }
        },
        child: Container(
          color:
              _selectedIndex == index ? Colors.purple[100] : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: _selectedIndex == index ? Colors.purple : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        title: const Text(
          'Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.purple[50],
            child: Row(
              children: [
                _buildTabButton(0, 'Pending Orders'),
                _buildTabButton(1, 'Completed Orders'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text('No orders found'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(order['itemName'] ?? 'No Name'),
                        subtitle: Text('Price: ${order['itemPrice'] ?? 'N/A'}'),
                        trailing: Text(order['status'] ?? 'Unknown'),
                      ),
                    );
                  },
                ),
    );
  }
}
