import 'package:flutter_test/flutter_test.dart';
import 'package:sharemarium/models/profile_page_color.dart';
import 'package:sharemarium/services/supabase_service.dart';

void main() {
  test('standard accounts can select only blue, yellow, and green', () {
    expect(ProfilePageColors.standardKeys, {'blue', 'yellow', 'green'});
    expect(
      ProfilePageColors.options
          .where(
            (option) => ProfilePageColors.standardKeys.contains(option.key),
          )
          .map((option) => option.key)
          .toSet(),
      {'blue', 'yellow', 'green'},
    );
  });

  test('favorite limits are 3 normally and 12 for subscribers', () {
    expect(SupabaseService.standardFavoriteLimit, 3);
    expect(SupabaseService.subscriberFavoriteLimit, 12);
  });
}
