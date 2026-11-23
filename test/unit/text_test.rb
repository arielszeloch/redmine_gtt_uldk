# frozen_string_literal: true

# Standalone tests, no Redmine needed:
#   ruby -Ilib test/unit/text_test.rb
require 'minitest/autorun'
require_relative '../../lib/redmine_gtt_uldk/text'
require_relative '../../lib/redmine_gtt_uldk/client'

class TextTest < Minitest::Test
  T = RedmineGttUldk::Text

  def test_parcel_numbers
    assert_equal %w[51], T.parcel_numbers('51')
    assert_equal %w[24/7 24/8], T.parcel_numbers('24/7, 24/8')
    assert_equal %w[12 13/4], T.parcel_numbers('dz. 12 i 13/4')
    assert_equal %w[5], T.parcel_numbers('5; 5')
    assert_equal [], T.parcel_numbers('  ')
    assert_equal [], T.parcel_numbers(nil)
    assert_equal ['046101_1.0001.12/3'], T.parcel_numbers('046101_1.0001.12/3')
  end

  def test_full_id
    assert T.full_id?('046101_1.0001.12/3')
    refute T.full_id?('12/3')
  end

  def test_norm
    assert_equal 'mbydgoszcz', T.norm('M. Bydgoszcz')
    assert_equal 'bialeblota', T.norm('Białe Błota')
  end

  def test_commune_match
    assert T.commune_match?('Bydgoszcz', 'M. Bydgoszcz')
    assert T.commune_match?('Białe Błota', 'Białe Błota (2)')
    refute T.commune_match?('Osielsko', 'Białe Błota')
    refute T.commune_match?('', 'Osielsko')
  end

  def test_unit_map
    map = T.parse_unit_map(<<~TXT)
      # comment
      M. Bydgoszcz, MB; Bydgoszcz = 046101_1
      Broken line
      Toruń = 046301_1 # trailing comment
      Bad = 12345
    TXT
    assert_equal '046101_1', T.unit_for('m.bydgoszcz', map)
    assert_equal '046101_1', T.unit_for('MB', map)
    assert_equal '046301_1', T.unit_for('Torun', map)
    assert_nil T.unit_for('Bad', map)
    assert_nil T.unit_for('Osielsko', map)
  end

  def test_precinct_code
    assert_equal '0042', T.precinct_code('42')
    assert_equal '0001', T.precinct_code(' 1 ')
    assert_nil T.precinct_code('Fordon')
  end

  def test_client_parse
    body = "2\n046101_1.0001.1|M. Bydgoszcz|0001|1|SRID=4326;POLYGON((18 53,18.1 53,18 53.1,18 53))\n" \
           "046101_1.0001.2|M. Bydgoszcz|0001|2|\n"
    parcels = RedmineGttUldk::Client.parse(body)
    assert_equal 1, parcels.size
    assert_equal '046101_1.0001.1', parcels.first.id
    assert parcels.first.wkt.start_with?('POLYGON')
    assert_equal [], RedmineGttUldk::Client.parse("-1 brak wyników\n")
    assert_equal [], RedmineGttUldk::Client.parse('')
  end
end
