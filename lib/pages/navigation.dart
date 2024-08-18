import 'package:ecub_delivery/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationPage extends StatefulWidget {
  final OrdersSam order;

  const NavigationPage({Key? key, required this.order}) : super(key: key);

  @override
  NavigationPageState createState() => NavigationPageState();
}

class NavigationPageState extends State<NavigationPage> {
  bool _isNavigating = false;

  void _callCustomer(dynamic order) async {
    final url = Uri.parse('tel:${order.customerMobile}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _startNavigation() async {
    final double lat = double.parse('9.51272000');
    final double lng = double.parse('77.63369000');

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _acceptOrder() {
    setState(() {
      _isNavigating = true;
    });
  }

  void _rejectOrder() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: const Color.fromARGB(255, 205, 195, 222),
      ),
      body: Column(
        children: [
          if (!_isNavigating)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Do you want to accept this order?',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: _acceptOrder,
                      child: const Text('Accept'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _rejectOrder,
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID: ${widget.order.orderId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Item: ${widget.order.itemName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Customer: ${widget.order.customerName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Price: ${widget.order.itemPrice}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    // Text(
                    //   'Address: ${order.address}',
                    //   style: const TextStyle(fontSize: 16),
                    // ),
                    // const SizedBox(height: 10),
                    // ElevatedButton(
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.purple,
                    //   ),
                    //   onPressed: _callCustomer,
                    //   child: const Text('Call Customer'),
                    // ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: _startNavigation,
                      child: const Text('Start Navigation'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
