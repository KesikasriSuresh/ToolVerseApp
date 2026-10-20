import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Global ScaffoldMessenger key so floating warnings can be displayed reliably anywhere in the app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ---------------------------------------------------------------------------
// FLOATING VALIDATION FEEDBACK SYSTEM
// ---------------------------------------------------------------------------

class ValidationFeedback {
  static String? _lastMessage;
  static int _lastShownMillis = 0;

  /// Shows a floating warning with ToolVerse theme without queuing alert backlogs.
  static void showWarning(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context) ??
        rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _displaySnackBar(messenger, message, isError, duration);
  }

  /// Shows a floating warning using the global root ScaffoldMessenger key.
  static void showRootWarning(
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _displaySnackBar(messenger, message, isError, duration);
  }

  static void _displaySnackBar(
    ScaffoldMessengerState messenger,
    String message,
    bool isError,
    Duration duration,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Suppress rapid duplicates within 300ms to avoid micro-stuttering, while allowing subsequent keystrokes to refresh
    if (_lastMessage == message && (now - _lastShownMillis) < 300) {
      return;
    }
    _lastMessage = message;
    _lastShownMillis = now;

    // Immediately replace any active snackbar so there's never a queue lag
    messenger.hideCurrentSnackBar();

    final primaryColor =
        isError ? const Color(0xFFEF4444) : const Color(0xFFE5A93C);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B), // High-contrast ToolVerse Slate
        duration: duration,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM TEXT INPUT FORMATTERS WITH REAL-TIME FEEDBACK
// ---------------------------------------------------------------------------

/// Formatter for personal names (allows letters, spaces, hyphens, apostrophes).
/// Rejects digits and symbols immediately and notifies the user with a floating warning.
class NameInputFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;

  NameInputFormatter(this.context, {this.maxLength = 50});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If deletion or no change, allow immediately
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    // 1. Digits check
    if (RegExp(r'\d').hasMatch(newValue.text)) {
      _notify("Numbers are not allowed in the name field.");
      final sanitized = newValue.text.replaceAll(RegExp(r'\d'), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 2. Prohibited special characters check (allows letters, spaces, hyphens, apostrophes)
    if (RegExp(r"[^a-zA-Z\s\-']").hasMatch(newValue.text)) {
      _notify("Please use letters, spaces, apostrophes, or hyphens only.");
      final sanitized = newValue.text.replaceAll(RegExp(r"[^a-zA-Z\s\-']"), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 3. Length check
    if (newValue.text.length > maxLength) {
      _notify("Name cannot exceed $maxLength characters.");
      if (oldValue.text.length <= maxLength) return oldValue;
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter for phone numbers (allows digits, +, spaces, -).
/// Rejects letters and prohibited characters with a floating warning.
class PhoneInputFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;

  PhoneInputFormatter(this.context, {this.maxLength = 18});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    // 1. Letters check
    if (RegExp(r'[a-zA-Z]').hasMatch(newValue.text)) {
      _notify("Letters are not allowed in the phone number.");
      final sanitized = newValue.text.replaceAll(RegExp(r'[a-zA-Z]'), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 2. Prohibited special characters (allowed: digits, +, spaces, -)
    if (RegExp(r'[^\d\+\s\-]').hasMatch(newValue.text)) {
      _notify("Special characters aren't allowed in phone numbers.");
      final sanitized = newValue.text.replaceAll(RegExp(r'[^\d\+\s\-]'), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 3. Length check
    if (newValue.text.length > maxLength) {
      _notify("Phone number cannot exceed $maxLength characters.");
      if (oldValue.text.length <= maxLength) return oldValue;
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter for single OTP boxes (allows digits only).
/// Warns if letters or prohibited characters are attempted.
class OtpDigitInputFormatter extends TextInputFormatter {
  final BuildContext? context;

  OtpDigitInputFormatter(this.context);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (newValue.text == oldValue.text) return newValue;

    if (RegExp(r'\D').hasMatch(newValue.text)) {
      _notify("Only digits are allowed in the OTP.");
      final clean = newValue.text.replaceAll(RegExp(r'\D'), '');
      if (clean == oldValue.text) return oldValue;
      return clean.isEmpty
          ? oldValue
          : TextEditingValue(
              text: clean,
              selection: TextSelection.collapsed(offset: clean.length),
            );
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter for monetary deposits / amounts (digits only, non-negative integer).
class NumericAmountInputFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;
  final int maxAmount;

  NumericAmountInputFormatter(this.context, {this.maxLength = 6, this.maxAmount = 50000});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    // 1. Letters check
    if (RegExp(r'[a-zA-Z]').hasMatch(newValue.text)) {
      _notify("Only numbers are allowed in the deposit amount.");
      final sanitized = newValue.text.replaceAll(RegExp(r'[a-zA-Z]'), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 2. Negative signs or symbols
    if (RegExp(r'\D').hasMatch(newValue.text)) {
      _notify("Special characters aren't allowed in the deposit field.");
      final sanitized = newValue.text.replaceAll(RegExp(r'\D'), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    // 3. Max Amount check
    final parsed = int.tryParse(newValue.text);
    if (parsed != null && parsed > maxAmount) {
      _notify("Deposit must be between ₹0 and ₹$maxAmount.");
      final oldParsed = int.tryParse(oldValue.text);
      if (oldParsed != null && oldParsed <= maxAmount) {
        return oldValue;
      }
      return TextEditingValue(
        text: maxAmount.toString(),
        selection: TextSelection.collapsed(offset: maxAmount.toString().length),
      );
    }

    // 4. Length check
    if (newValue.text.length > maxLength) {
      _notify("Deposit must be between ₹0 and ₹$maxAmount.");
      if (oldValue.text.length <= maxLength) return oldValue;
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter for item names (allows letters, numbers, spaces, model punctuation).
class ItemNameInputFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;

  ItemNameInputFormatter(this.context, {this.maxLength = 60});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    // Reject dangerous/unsuitable symbols like <>{}[]~$^%*\|`=
    if (RegExp(r'''[<>{}\[\]\~\$\^\%\*\\|`=]''').hasMatch(newValue.text)) {
      _notify("Special characters like <>{} are not allowed in the item name.");
      final sanitized =
          newValue.text.replaceAll(RegExp(r'''[<>{}\[\]\~\$\^\%\*\\|`=]'''), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    if (newValue.text.length > maxLength) {
      _notify("Item name cannot exceed $maxLength characters.");
      if (oldValue.text.length <= maxLength) return oldValue;
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter for addresses / society names (allows numbers, letters, spaces, commas, hyphens, slashes, dots, hashes, parentheses).
class AddressInputFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;

  AddressInputFormatter(this.context, {this.maxLength = 100});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    if (RegExp(r'''[<>{}\[\]\~\$\^\%\*\\|`=]''').hasMatch(newValue.text)) {
      _notify("Special characters like <>{} are not allowed in the address.");
      final sanitized =
          newValue.text.replaceAll(RegExp(r'''[<>{}\[\]\~\$\^\%\*\\|`=]'''), '');
      if (sanitized == oldValue.text) return oldValue;
      return _buildTextEditingValue(sanitized, oldValue, newValue);
    }

    if (newValue.text.length > maxLength) {
      _notify("Address cannot exceed $maxLength characters.");
      if (oldValue.text.length <= maxLength) return oldValue;
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }

    return newValue;
  }

  void _notify(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {
        ValidationFeedback.showWarning(context!, msg);
      } else {
        ValidationFeedback.showRootWarning(msg);
      }
    });
  }
}

/// Formatter with character limit and floating warning when limit is reached.
class LengthLimitWithWarningFormatter extends TextInputFormatter {
  final BuildContext? context;
  final int maxLength;
  final String fieldLabel;

  LengthLimitWithWarningFormatter(
    this.context, {
    required this.maxLength,
    required this.fieldLabel,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > maxLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context != null) {
          ValidationFeedback.showWarning(
            context!,
            "$fieldLabel cannot exceed $maxLength characters.",
          );
        } else {
          ValidationFeedback.showRootWarning(
            "$fieldLabel cannot exceed $maxLength characters.",
          );
        }
      });
      if (oldValue.text.length <= maxLength) {
        return oldValue;
      }
      final truncated = newValue.text.substring(0, maxLength);
      return _buildTextEditingValue(truncated, oldValue, newValue);
    }
    return newValue;
  }
}

// ---------------------------------------------------------------------------
// HELPER METHODS
// ---------------------------------------------------------------------------

TextEditingValue _buildTextEditingValue(
  String sanitizedText,
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  final selectionIndex = newValue.selection.end;
  final clampedIndex = selectionIndex.clamp(0, sanitizedText.length);
  return TextEditingValue(
    text: sanitizedText,
    selection: TextSelection.collapsed(offset: clampedIndex),
  );
}
