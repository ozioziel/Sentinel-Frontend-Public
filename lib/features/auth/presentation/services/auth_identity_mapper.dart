class NameParts {
  final String firstName;
  final String lastName;
  final String? middleLastName;

  const NameParts({
    required this.firstName,
    required this.lastName,
    this.middleLastName,
  });
}

class AuthIdentityMapper {
  static String normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final hasLeadingPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
      return digits.isEmpty ? '' : '+$digits';
    }

    if (hasLeadingPlus) {
      return digits.isEmpty ? '' : '+$digits';
    }

    if (digits.startsWith('591')) {
      return '+$digits';
    }

    if (digits.length == 8) {
      return '+591$digits';
    }

    return digits.isEmpty ? '' : '+$digits';
  }

  static String buildEmailFromPhone(String phone) {
    final normalizedPhone = normalizePhone(phone);
    final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    final localPart = digits.isEmpty ? 'phone_user' : 'phone$digits';
    return '$localPart@sentinel.app';
  }

  static NameParts splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return const NameParts(
        firstName: 'Usuaria',
        lastName: 'Sentinel',
      );
    }

    if (parts.length == 1) {
      return NameParts(
        firstName: parts.first,
        lastName: 'Sin apellido',
      );
    }

    if (parts.length == 2) {
      return NameParts(
        firstName: parts.first,
        lastName: parts.last,
      );
    }

    return NameParts(
      firstName: parts.first,
      lastName: parts[1],
      middleLastName: parts.sublist(2).join(' '),
    );
  }

  static String buildAddressFromCity(String city) {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      return '';
    }

    return 'Ciudad: $trimmedCity';
  }

  static String extractCity(String? address) {
    final trimmedAddress = address?.trim() ?? '';
    if (trimmedAddress.isEmpty) {
      return 'Bolivia';
    }

    const prefix = 'Ciudad: ';
    if (trimmedAddress.startsWith(prefix)) {
      return trimmedAddress.substring(prefix.length).trim();
    }

    return trimmedAddress;
  }
}
