import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ClubBusyApp());
}

class ClubBusyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Club Busy Status',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ClubListScreen(),
    );
  }
}

class ClubListScreen extends StatefulWidget {
  @override
  _ClubListScreenState createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  String _selectedSortOption = 'Alphabetical';
  String _selectedCity = '';
  List<String> _cities = [];

  @override
  void initState() {
    super.initState();
    _fetchCities();
  }

  void _fetchCities() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('clubs').get();
    final cities = querySnapshot.docs.map((doc) => doc['city'] as String).toSet().toList();
    setState(() {
      _cities = cities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clubs Busy Status'),
        actions: [
          DropdownButton<String>(
            value: _selectedSortOption,
            icon: Icon(Icons.sort),
            onChanged: (String? newValue) {
              setState(() {
                _selectedSortOption = newValue!;
              });
            },
            items: <String>['Alphabetical', 'Busy Status']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select City',
                border: OutlineInputBorder(),
              ),
              value: _selectedCity.isEmpty ? null : _selectedCity,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCity = newValue!;
                });
              },
              items: _cities.map<DropdownMenuItem<String>>((String city) {
                return DropdownMenuItem<String>(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ClubList(
              sortOption: _selectedSortOption,
              selectedCity: _selectedCity,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClubDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddClubDialog(BuildContext context) {
    final _nameController = TextEditingController();
    final _statusController = TextEditingController();
    final _cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Club'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Club Name'),
              ),
              TextField(
                controller: _statusController,
                decoration: InputDecoration(labelText: 'Busy Status (1-10)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'City'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = _nameController.text;
                final status = int.tryParse(_statusController.text);
                final city = _cityController.text;

                if (name.isNotEmpty && status != null && status >= 1 && status <= 10 && city.isNotEmpty) {
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('clubs')
                      .where('name', isEqualTo: name)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    // If club exists, update the status
                    final docId = querySnapshot.docs.first.id;
                    FirebaseFirestore.instance.collection('clubs').doc(docId).update({
                      'busyStatus': status,
                      'city': city,
                    });
                  } else {
                    // If club doesn't exist, add a new club
                    FirebaseFirestore.instance.collection('clubs').add({
                      'name': name,
                      'busyStatus': status,
                      'city': city,
                    });
                  }

                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class Club {
  final String name;
  final int busyStatus;
  final String city;

  Club({required this.name, required this.busyStatus, required this.city});

  factory Club.fromDocument(DocumentSnapshot doc) {
    return Club(
      name: doc['name'],
      busyStatus: doc['busyStatus'],
      city: doc['city'],
    );
  }
}

class ClubList extends StatelessWidget {
  final String sortOption;
  final String selectedCity;

  ClubList({required this.sortOption, required this.selectedCity});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var clubs = snapshot.data!.docs
            .map((doc) => Club.fromDocument(doc))
            .where((club) => club.city.toLowerCase().contains(selectedCity.toLowerCase()))
            .toList();

        if (sortOption == 'Alphabetical') {
          clubs.sort((a, b) => a.name.compareTo(b.name));
        } else if (sortOption == 'Busy Status') {
          clubs.sort((a, b) => b.busyStatus.compareTo(a.busyStatus));
        }

        return ListView.builder(
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final club = clubs[index];
            return ListTile(
              title: Text(
                club.name,
                style: TextStyle(fontSize: 20.0),
              ),
              subtitle: Text(
                'Status: ${club.busyStatus}/10\nCity: ${club.city}',
                style: TextStyle(fontSize: 16.0),
              ),
              leading: Icon(
                Icons.circle,
                color: getStatusColor(club.busyStatus),
              ),
              onTap: () => _showEditStatusDialog(context, club),
            );
          },
        );
      },
    );
  }

  void _showEditStatusDialog(BuildContext context, Club club) {
    final _statusController = TextEditingController(text: club.busyStatus.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Busy Status for ${club.name}'),
          content: TextField(
            controller: _statusController,
            decoration: InputDecoration(labelText: 'Busy Status (1-10)'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final status = int.tryParse(_statusController.text);

                if (status != null && status >= 1 && status <= 10) {
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('clubs')
                      .where('name', isEqualTo: club.name)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    final docId = querySnapshot.docs.first.id;
                    await FirebaseFirestore.instance.collection('clubs').doc(docId).update({
                      'busyStatus': status,
                    });
                  }

                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Color getStatusColor(int status) {
    if (status >= 8) {
      return Colors.red;
    } else if (status >= 4) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
