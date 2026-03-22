import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/network/api_client.dart';
import '../models/contact_model.dart';
import 'auth_identity_mapper.dart';
import 'auth_service.dart';

class ContactsService {
  static const _contactsCachePrefix = 'contacts_cache_';
  static const _contactEmailsPrefix = 'contact_emails_';

  final AuthService _authService;
  final ApiClient _apiClient;

  ContactsService({AuthService? authService, ApiClient? apiClient})
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient();

  String _cacheKey(String userId) => '$_contactsCachePrefix$userId';
  String _emailCacheKey(String userId) => '$_contactEmailsPrefix$userId';

  Future<List<ContactModel>> getContacts(String userId) async {
    final session = await _authService.getSession();
    if (session == null) {
      return _loadCachedContacts(userId);
    }

    try {
      final response = await _apiClient.getJson(
        '/contacts',
        accessToken: session.accessToken,
      );
      final data = response['data'];
      if (data is! List) {
        return [];
      }

      final contacts =
          data
              .map(
                (item) =>
                    ContactModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      final mergedContacts = await _mergeLocalContactEmails(userId, contacts);
      await _saveCachedContacts(userId, mergedContacts);
      return mergedContacts;
    } catch (_) {
      return _loadCachedContacts(userId);
    }
  }

  Future<bool> hasContacts(String userId) async {
    final contacts = await getContacts(userId);
    return contacts.isNotEmpty;
  }

  Future<bool> addContact(
    String userId,
    String name,
    String phone,
    String relation,
    String? email,
  ) async {
    final session = await _authService.getSession();
    if (session == null) {
      return false;
    }

    final normalizedPhone = AuthIdentityMapper.normalizePhone(phone);
    if (normalizedPhone.isEmpty) {
      return false;
    }

    final contacts = await getContacts(userId);
    final exists = contacts.any(
      (contact) =>
          AuthIdentityMapper.normalizePhone(contact.phone) == normalizedPhone,
    );
    if (exists) {
      return false;
    }

    final localContact = ContactModel(
      id: _buildLocalContactId(),
      name: name.trim(),
      phone: normalizedPhone,
      email: email,
      relation: relation.trim().isEmpty
          ? 'Contacto de emergencia'
          : relation.trim(),
      priority: contacts.length + 1,
    );

    try {
      await _upsertLocalEmail(userId, phone: normalizedPhone, email: email);
      await _apiClient.postJson(
        '/contacts',
        accessToken: session.accessToken,
        body: ContactModel(
          id: '',
          name: name.trim(),
          phone: normalizedPhone,
          email: email,
          relation: relation.trim().isEmpty
              ? 'Contacto de emergencia'
              : relation.trim(),
          priority: contacts.length + 1,
        ).toBackendPayload(),
      );
      await _refreshCache(userId);
      return true;
    } catch (error) {
      if (!_shouldSaveLocally(error)) {
        return false;
      }

      await _saveContactLocally(userId, localContact);
      await OfflineSyncService.instance.enqueueCreateContact(
        userId: userId,
        contact: localContact,
      );
      return true;
    }
  }

  Future<bool> updateContact(String userId, ContactModel updated) async {
    final session = await _authService.getSession();
    if (session == null) {
      return false;
    }

    final normalizedPhone = AuthIdentityMapper.normalizePhone(updated.phone);
    if (normalizedPhone.isEmpty) {
      return false;
    }

    final contacts = await getContacts(userId);
    final duplicates = contacts.any(
      (contact) =>
          contact.id != updated.id &&
          AuthIdentityMapper.normalizePhone(contact.phone) == normalizedPhone,
    );
    if (duplicates) {
      return false;
    }

    final previousContact = contacts.cast<ContactModel?>().firstWhere(
      (contact) => contact?.id == updated.id,
      orElse: () => null,
    );
    if (previousContact != null) {
      await _removeLocalEmailEntries(userId, previousContact);
    }
    final normalizedContact = updated.copyWith(phone: normalizedPhone);
    await _upsertLocalEmail(userId, contact: normalizedContact);
    await _upsertCachedContact(userId, normalizedContact);

    if (_isLocalId(normalizedContact.id)) {
      await OfflineSyncService.instance.enqueueUpdateContact(
        userId: userId,
        contact: normalizedContact,
      );
      return true;
    }

    try {
      await _apiClient.putJson(
        '/contacts/${updated.id}',
        accessToken: session.accessToken,
        body: normalizedContact.toBackendPayload(),
      );
      await _refreshCache(userId);
      return true;
    } catch (error) {
      if (!_shouldSaveLocally(error)) {
        if (previousContact != null) {
          await _upsertLocalEmail(userId, contact: previousContact);
          await _upsertCachedContact(userId, previousContact);
        }
        return false;
      }

      await OfflineSyncService.instance.enqueueUpdateContact(
        userId: userId,
        contact: normalizedContact,
      );
      return true;
    }
  }

  Future<bool> deleteContact(String userId, String contactId) async {
    final session = await _authService.getSession();
    if (session == null) {
      return false;
    }

    final cachedContacts = await _loadCachedContacts(userId);
    final removedContact = cachedContacts.cast<ContactModel?>().firstWhere(
      (contact) => contact?.id == contactId,
      orElse: () => null,
    );
    if (removedContact != null) {
      await _removeLocalEmailEntries(userId, removedContact);
    }
    cachedContacts.removeWhere((contact) => contact.id == contactId);
    await _saveCachedContacts(userId, cachedContacts);

    if (_isLocalId(contactId)) {
      await OfflineSyncService.instance.enqueueDeleteContact(
        userId: userId,
        contactId: contactId,
      );
      return true;
    }

    try {
      await _apiClient.deleteJson(
        '/contacts/$contactId',
        accessToken: session.accessToken,
      );
      return true;
    } catch (error) {
      if (!_shouldSaveLocally(error)) {
        if (removedContact != null) {
          await _upsertLocalEmail(userId, contact: removedContact);
          cachedContacts.insert(0, removedContact);
          await _saveCachedContacts(userId, cachedContacts);
        }
        return false;
      }

      await OfflineSyncService.instance.enqueueDeleteContact(
        userId: userId,
        contactId: contactId,
      );
      return true;
    }
  }

  Future<void> _refreshCache(String userId) async {
    final session = await _authService.getSession();
    if (session == null) {
      return;
    }

    try {
      final response = await _apiClient.getJson(
        '/contacts',
        accessToken: session.accessToken,
      );
      final data = response['data'];
      if (data is! List) {
        return;
      }

      final contacts =
          data
              .map(
                (item) =>
                    ContactModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      final mergedContacts = await _mergeLocalContactEmails(userId, contacts);
      await _saveCachedContacts(userId, mergedContacts);
    } catch (_) {
      // Keep the previous cache if refresh fails.
    }
  }

  Future<List<ContactModel>> _mergeLocalContactEmails(
    String userId,
    List<ContactModel> contacts,
  ) async {
    final localEmails = await _loadLocalEmails(userId);
    if (localEmails.isEmpty) {
      return contacts;
    }

    return contacts.map((contact) {
      final email = _resolveLocalEmail(localEmails, contact);
      if (email == null) {
        return contact;
      }

      return contact.copyWith(email: email);
    }).toList();
  }

  Future<Map<String, String>> _loadLocalEmails(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_emailCacheKey(userId));
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded.map(
        (key, value) => MapEntry(key, readContactString(value)),
      )..removeWhere((key, value) => value.trim().isEmpty);
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveLocalEmails(
    String userId,
    Map<String, String> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailCacheKey(userId), jsonEncode(values));
  }

  Future<void> _upsertLocalEmail(
    String userId, {
    ContactModel? contact,
    String? phone,
    String? email,
  }) async {
    final prefs = await _loadLocalEmails(userId);
    final normalizedEmail = normalizeNullableEmail(email ?? contact?.email);
    final keys = contact != null
        ? _emailAliasesForContact(contact)
        : _emailAliasesForPhone(phone);

    if (keys.isEmpty) {
      return;
    }

    for (final key in keys) {
      if (normalizedEmail == null) {
        prefs.remove(key);
      } else {
        prefs[key] = normalizedEmail;
      }
    }

    await _saveLocalEmails(userId, prefs);
  }

  Future<void> _removeLocalEmailEntries(
    String userId,
    ContactModel contact,
  ) async {
    final emails = await _loadLocalEmails(userId);
    final keys = _emailAliasesForContact(contact);
    if (keys.isEmpty) {
      return;
    }

    for (final key in keys) {
      emails.remove(key);
    }

    await _saveLocalEmails(userId, emails);
  }

  String? _resolveLocalEmail(
    Map<String, String> localEmails,
    ContactModel contact,
  ) {
    for (final key in _emailAliasesForContact(contact)) {
      final value = localEmails[key];
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  List<String> _emailAliasesForContact(ContactModel contact) {
    final aliases = <String>[];
    final trimmedId = contact.id.trim();
    if (trimmedId.isNotEmpty) {
      aliases.add('id:$trimmedId');
    }

    final normalizedPhone = AuthIdentityMapper.normalizePhone(contact.phone);
    if (normalizedPhone.isNotEmpty) {
      aliases.add('phone:$normalizedPhone');
    }

    return aliases;
  }

  List<String> _emailAliasesForPhone(String? phone) {
    final normalizedPhone = AuthIdentityMapper.normalizePhone(phone ?? '');
    if (normalizedPhone.isEmpty) {
      return const <String>[];
    }

    return <String>['phone:$normalizedPhone'];
  }

  Future<List<ContactModel>> _loadCachedContacts(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(userId));
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
      return decoded.map(ContactModel.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedContacts(
    String userId,
    List<ContactModel> contacts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(userId),
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
  }

  Future<void> _saveContactLocally(String userId, ContactModel contact) async {
    await _upsertLocalEmail(userId, contact: contact);
    await _upsertCachedContact(userId, contact);
  }

  Future<void> _upsertCachedContact(String userId, ContactModel contact) async {
    final contacts = await _loadCachedContacts(userId);
    final index = contacts.indexWhere((item) => item.id == contact.id);
    if (index == -1) {
      contacts.add(contact);
    } else {
      contacts[index] = contact;
    }
    contacts.sort((a, b) => a.priority.compareTo(b.priority));
    await _saveCachedContacts(userId, contacts);
  }

  bool _shouldSaveLocally(Object error) {
    if (error is! Exception) {
      return true;
    }

    final normalized = error.toString().toLowerCase();
    return normalized.contains('no se pudo conectar con el servidor') ||
        normalized.contains('schema cache') ||
        normalized.contains('schema_cache') ||
        normalized.contains('pgrst204') ||
        normalized.contains('pgrst205');
  }

  bool _isLocalId(String id) {
    return id.trim().startsWith('local-');
  }

  String _buildLocalContactId() {
    return 'local-contact-${DateTime.now().microsecondsSinceEpoch}';
  }
}
