import 'package:chating_app/features/coins/wallet_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends StatefulWidget {
  final int coins;
  final int price;
  final WalletRepo repo;

  const PaymentScreen({
    super.key,
    required this.coins,
    required this.price,
    required this.repo,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'CBE';
  final _cbeAccountController = TextEditingController();
  final _telebirrPhoneController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _cbeAccountController.dispose();
    _telebirrPhoneController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final padding = EdgeInsets.symmetric(
          horizontal: constraints.maxWidth * 0.05,
          vertical: 16,
        );
        const cbeReceiver = '369390';
        const telebirrReceiver = '0901191234';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Payment',
              style: t.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: t.colorScheme.onSurface,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: t.colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
          ),
          body: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // How to Pay Button at Top
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.6 : double.infinity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: OutlinedButton(
                      onPressed: () {
                        context.go(
                          '/wallet/how-to-pay',
                          extra: {
                            'method': _selectedMethod,
                            'price': widget.price,
                            'cbeReceiver': cbeReceiver,
                            'telebirrReceiver': telebirrReceiver,
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: t.colorScheme.primary,
                          width: 1.5,
                        ),
                        foregroundColor: t.colorScheme.primary,
                      ),
                      onHover: (isHovering) {
                        setState(() {});
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'How to Pay',
                            style: t.textTheme.titleMedium?.copyWith(
                              color: t.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: isWide ? 18 : 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: t.colorScheme.primary,
                            size: isWide ? 24 : 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Payment Methods in Column
                Column(
                  children: [
                    _buildPaymentOption(
                      method: 'CBE',
                      logo: Icons.payment,
                      accountHolder: 'John Doe',
                      accountNumber: cbeReceiver,
                      isSelected: _selectedMethod == 'CBE',
                      onTap: _isLoading
                          ? null
                          : () => setState(() {
                              _selectedMethod = 'CBE';
                              _cbeAccountController.clear();
                              _telebirrPhoneController.clear();
                              _transactionIdController.clear();
                            }),
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentOption(
                      method: 'TeleBirr',
                      logo: Icons.phone_android,
                      accountHolder: 'John Doe',
                      accountNumber: telebirrReceiver,
                      isSelected: _selectedMethod == 'TeleBirr',
                      onTap: _isLoading
                          ? null
                          : () => setState(() {
                              _selectedMethod = 'TeleBirr';
                              _cbeAccountController.clear();
                              _telebirrPhoneController.clear();
                              _transactionIdController.clear();
                            }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedMethod == 'CBE')
                        _buildTextField(
                          controller: _cbeAccountController,
                          label: 'Your CBE Account Number',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            if (value.length < 12 || value.length > 16)
                              return 'Must be 12-16 digits';
                            return null;
                          },
                        ),
                      if (_selectedMethod == 'TeleBirr')
                        _buildTextField(
                          controller: _telebirrPhoneController,
                          label: 'Your Phone Number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\+0-9]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            if (value.length < 10 || value.length > 13)
                              return 'Must be 10-13 digits';
                            return null;
                          },
                        ),
                      _buildTextField(
                        controller: _transactionIdController,
                        label: 'Transaction ID',
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 6 || value.length > 20)
                            return 'Must be 6-20 characters';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Pay Now Button
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.5 : double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isLoading = true);
                            try {
                              final paymentDetails = _selectedMethod == 'CBE'
                                  ? {
                                      'account_number':
                                          _cbeAccountController.text,
                                      'transaction_id':
                                          _transactionIdController.text,
                                      'receiver_account': cbeReceiver,
                                    }
                                  : {
                                      'phone_number':
                                          _telebirrPhoneController.text,
                                      'transaction_id':
                                          _transactionIdController.text,
                                      'receiver_phone': telebirrReceiver,
                                    };
                              await widget.repo.buyCoins(
                                widget.coins,
                                widget.price,
                                _selectedMethod,
                                paymentDetails,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully purchased ${widget.coins} coins!',
                                    ),
                                    backgroundColor: t.colorScheme.primary,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Purchase failed: $e'),
                                    backgroundColor: t.colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: t.colorScheme.primary,
                      elevation: _isLoading ? 0 : 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Pay Now',
                            style: t.textTheme.titleMedium?.copyWith(
                              color: t.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: isWide ? 18 : 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required IconData logo,
    required String accountHolder,
    required String accountNumber,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final t = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? t.colorScheme.primary : t.colorScheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? t.colorScheme.surfaceContainerHigh
              : t.colorScheme.surface,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              logo,
              size: isWide ? 40 : 32,
              color: isSelected
                  ? t.colorScheme.primary
                  : t.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? t.colorScheme.primary
                          : t.colorScheme.onSurface,
                      fontSize: isWide ? 18 : 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Account Holder Name: $accountHolder',
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      fontSize: isWide ? 14 : 12,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Account Number: $accountNumber',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                            fontSize: isWide ? 14 : 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: isWide ? 18 : 16,
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard'),
                              backgroundColor: t.colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: method,
              groupValue: _selectedMethod,
              onChanged: (_) => onTap?.call(),
              activeColor: t.colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required String? Function(String?) validator,
  }) {
    final t = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: t.textTheme.bodyLarge?.copyWith(
            fontSize: isWide ? 16 : 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: t.colorScheme.surfaceContainerLow,
          errorStyle: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.error,
          ),
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: t.textTheme.bodyLarge?.copyWith(fontSize: isWide ? 16 : 14),
      ),
    );
  }
}
