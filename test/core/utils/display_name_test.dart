import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/utils/display_name.dart';

void main() {
  group('firstNameFor', () {
    test('uses the first word of the account name', () {
      expect(firstNameFor(displayName: 'Ada Lovelace', email: 'x@y.com'), 'Ada');
      expect(firstNameFor(displayName: '  Grace   Hopper ', email: 'x@y.com'), 'Grace');
    });

    test('falls back to a tidied email prefix', () {
      expect(firstNameFor(displayName: null, email: 'jane.doe_99@x.com'), 'Jane');
      expect(firstNameFor(displayName: '', email: 'samadajayi0@gmail.com'), 'Samadajayi');
    });

    test('uses a friendly default when nothing is usable', () {
      expect(firstNameFor(displayName: null, email: ''), 'there');
      expect(firstNameFor(displayName: null, email: '123@x.com'), 'there');
    });
  });

  group('fullNameFor', () {
    test('prefers the account name', () {
      expect(fullNameFor(displayName: 'Ada Lovelace', email: 'x@y.com'), 'Ada Lovelace');
    });

    test('turns the email prefix into words', () {
      expect(fullNameFor(displayName: null, email: 'jane.doe-smith@x.com'), 'Jane Doe Smith');
    });
  });

  group('initialsFor', () {
    test('takes first and last initials', () {
      expect(initialsFor('Ada Lovelace'), 'AL');
      expect(initialsFor('Jane Doe Smith'), 'JS');
    });

    test('handles one word and empty input', () {
      expect(initialsFor('ada'), 'A');
      expect(initialsFor('  '), '?');
    });
  });
}
