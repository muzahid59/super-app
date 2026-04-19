import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/ocr_service.dart';

class ReviewEditScreen extends StatefulWidget {
  const ReviewEditScreen({super.key});

  @override
  State<ReviewEditScreen> createState() => _ReviewEditScreenState();
}

class _ReviewEditScreenState extends State<ReviewEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'Cash';
  String? _imagePath;
  Transaction? _existingTransaction;
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Mobile Banking',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic> && args.containsKey('imagePath')) {
      _imagePath = args['imagePath'] as String;
      _isEditMode = false;
      _performOCR();
    } else if (args is Transaction) {
      _existingTransaction = args;
      _isEditMode = true;
      _loadExistingTransaction();
    }
  }

  void _loadExistingTransaction() {
    if (_existingTransaction != null) {
      _merchantController.text = _existingTransaction!.merchantName;
      _amountController.text = _existingTransaction!.totalAmount.toString();
      _selectedDate = _existingTransaction!.date;
      _selectedPaymentMethod = _existingTransaction!.paymentMethod;
      if (_existingTransaction!.taxAmount != null) {
        _taxController.text = _existingTransaction!.taxAmount.toString();
      }
      _imagePath = _existingTransaction!.imagePath;
    }
  }

  Future<void> _performOCR() async {
    if (_imagePath == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final extractedData = await OCRService.extractReceiptData(_imagePath!);

      if (!mounted) return;

      setState(() {
        _merchantController.text = extractedData['merchantName'] ?? '';
        _amountController.text = extractedData['totalAmount']?.toString() ?? '0.0';
        _selectedDate = extractedData['date'] ?? DateTime.now();
        _selectedPaymentMethod = extractedData['paymentMethod'] ?? 'Cash';

        if (extractedData['taxAmount'] != null) {
          _taxController.text = extractedData['taxAmount'].toString();
        }

        _isLoading = false;
      });

      if (extractedData.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read receipt. Please enter details manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR failed. Please enter details manually.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    final transaction = Transaction(
      id: _existingTransaction?.id ?? const Uuid().v4(),
      merchantName: _merchantController.text.trim(),
      totalAmount: double.parse(_amountController.text),
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      taxAmount: _taxController.text.isNotEmpty
          ? double.tryParse(_taxController.text)
          : null,
      imagePath: _imagePath,
    );

    if (_isEditMode) {
      provider.updateTransaction(transaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated')),
      );
    } else {
      provider.addTransaction(transaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved')),
      );
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retakePhoto() {
    Navigator.of(context).pushReplacementNamed('/capture');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Review Receipt'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter merchant name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: '৳ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter total amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Amount (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                        prefixText: '৳ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final tax = double.tryParse(value);
                          if (tax == null || tax < 0) {
                            return 'Please enter a valid tax amount';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isEditMode ? 'Update Transaction' : 'Save Transaction',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (!_isEditMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _retakePhoto,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Retake Photo',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
