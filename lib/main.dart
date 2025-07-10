import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CurrencyConverterApp());

class CurrencyConverterApp extends StatelessWidget {
  const CurrencyConverterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const CurrencyConverterPage(),
    theme: ThemeData(
      scaffoldBackgroundColor: const Color(0xFFF5F5F2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF737373),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
  );
}

class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  static const _version = '1.1';
  final _amountController = TextEditingController();
  String _from = 'United States - USD';
  String _to = 'Thailand - THB';
  Map<String, double> _rates = {};
  DateTime? _lastUpdated;
  double? _result;
  bool _loading = false;

  static const _currencyMap = {
    'Australia': 'AUD',
    'Canada': 'CAD',
    'China': 'CNY',
    'Eurozone': 'EUR',
    'Hong Kong': 'HKD',
    'India': 'INR',
    'Indonesia': 'IDR',
    'Japan': 'JPY',
    'Malaysia': 'MYR',
    'New Zealand': 'NZD',
    'Philippines': 'PHP',
    'Singapore': 'SGD',
    'South Korea': 'KRW',
    'Switzerland': 'CHF',
    'Taiwan': 'TWD',
    'Thailand': 'THB',
    'United Arab Emirates': 'AED',
    'United Kingdom': 'GBP',
    'United States': 'USD',
    'Vietnam': 'VND',
  };

  List<String> get _countries {
    final keys = _currencyMap.keys.toList()..sort();
    return keys.map((c) => '$c - ${_currencyMap[c]}').toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('rates');
    final ts = prefs.getString('updated');
    if (json != null && ts != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      setState(() {
        _rates = data.map((k, v) => MapEntry(k, (v as num).toDouble()));
        _lastUpdated = DateTime.tryParse(ts);
      });
    }
  }

  Future<void> _fetchRates() async {
    setState(() => _loading = true);
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      final msg = _rates.isNotEmpty
          ? 'Offline: using cached rates'
          : 'No internet and no cache';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _loading = false);
      return;
    }
    try {
      final code = _from.split(' - ').last;
      final uri = Uri.https('open.er-api.com', '/v6/latest/$code');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if (map['result'] != 'success' || map['rates'] == null) throw 'API error';
      final entries = (map['rates'] as Map<String, dynamic>).entries.map(
        (e) => MapEntry(e.key, (e.value as num).toDouble()),
      );
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _rates = Map.fromEntries(entries);
        _lastUpdated = DateTime.now();
      });
      prefs.remove('rates');
      prefs.remove('updated');
      prefs.setString('rates', jsonEncode(_rates));
      prefs.setString('updated', _lastUpdated!.toIso8601String());
      ('updated', _lastUpdated!.toIso8601String());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _convert() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }
    if (!_rates.containsKey(_to.split(' - ').last)) await _fetchRates();
    final rate = _rates[_to.split(' - ').last];
    if (rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please update rates first')),
      );
      return;
    }
    setState(() => _result = amt * rate);
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
      _rates.clear();
      _result = null;
      _lastUpdated = null;
    });
    _fetchRates();
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastUpdated == null
        ? ''
        : 'Updated: ${DateFormat('d MMM yyyy HH:mm').format(_lastUpdated!)}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Currency Converter',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount'),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _amountController.clear();
                                setState(() => _result = null);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _from,
                      isExpanded: true,
                      decoration: const InputDecoration(),
                      items: _countries
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _from = v!;
                          _rates.clear();
                          _result = null;
                          _lastUpdated = null;
                        });
                        _fetchRates();
                      },
                    ),
                  ),
                ),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 32),
                    onPressed: _swap,
                  ),
                ),
                Card(
                  color: const Color(0xFFE8F5E9),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _to,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: _countries
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _to = v!;
                              _result = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            _result == null
                                ? '0.00 ${_to.split(' - ').last}'
                                : '${_result!.toStringAsFixed(2)} ${_to.split(' - ').last}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _convert,
                  child: const Text('Convert'),
                ),
                const SizedBox(height: 16),
                if (last.isNotEmpty) ...[
                  Text(
                    last,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (_rates.containsKey(_to.split(' - ').last))
                    Text(
                      'Rate: 1 ${_from.split(' - ').last} = ${_rates[_to.split(' - ').last]!.toStringAsFixed(2)} ${_to.split(' - ').last}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchRates,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Refresh Rates'),
                ),
                const SizedBox(height: 8),
                Text(
                  'v$_version',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
