# frozen_string_literal: true

module RedmineGttUldk
  # Pure text helpers (no Redmine dependency, unit tested standalone).
  module Text
    FULL_ID = /\A\d{6}_\d\.\d{4}\.\S+\z/
    NUMBER = %r{\d+(?:/\d+)?}

    module_function

    # "51", "24/7, 24/8", "dz. 12 i 13/4" -> ["51"], ["24/7", "24/8"], ["12", "13/4"].
    # A full ULDK id ("046101_1.0001.12/3") is kept as a single entry.
    def parcel_numbers(text)
      text = text.to_s.strip
      return [] if text.empty?
      return [text] if text.match?(FULL_ID)

      text.scan(NUMBER).uniq
    end

    def full_id?(text)
      text.to_s.match?(FULL_ID)
    end

    # Lower-case, no diacritics, no dots/spaces/hyphens: "M. Bydgoszcz" -> "mbydgoszcz".
    def norm(text)
      text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase
          .tr('ł', 'l').gsub(/[\s.\-_]/, '')
    end

    # Does a commune name from the issue match a commune name from ULDK
    # (e.g. "Bydgoszcz" vs "M. Bydgoszcz", "Białe Błota" vs "Białe Błota (2)")?
    def commune_match?(issue_value, uldk_value)
      a = norm(issue_value)
      b = norm(uldk_value).sub(/\(\d\)\z/, '')
      return false if a.empty? || b.empty?

      a == b || b.include?(a) || a.include?(b)
    end

    # Parses the "unit map" setting:
    #   M. Bydgoszcz, MB, Bydgoszcz = 046101_1
    #   # comment
    # Returns { "mbydgoszcz" => "046101_1", "mb" => "046101_1", ... }.
    def parse_unit_map(text)
      text.to_s.each_line.with_object({}) do |line, map|
        line = line.sub(/#.*/, '').strip
        next if line.empty?

        names, unit = line.split('=', 2).map(&:strip)
        next unless unit&.match?(/\A\d{6}_\d\z/)

        names.split(/[,;]/).map { |n| norm(n) }.reject(&:empty?).each { |n| map[n] = unit }
      end
    end

    # Registration unit for a commune name, exact (normalised) match only.
    def unit_for(commune, unit_map)
      unit_map[norm(commune)]
    end

    # Precinct given as a number ("1", "0042") -> 4-digit precinct code.
    def precinct_code(precinct)
      precinct.to_s.strip.match?(/\A\d{1,4}\z/) ? precinct.strip.rjust(4, '0') : nil
    end
  end
end
