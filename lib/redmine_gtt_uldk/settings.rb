# frozen_string_literal: true

module RedmineGttUldk
  # Plugin settings with sensible fallbacks: when a field is not chosen in the
  # settings, an issue custom field with a typical Polish name is used.
  module Settings
    DEFAULT_NAMES = {
      commune: %w[gmina],
      precinct: %w[obręb obreb obręb\ ewidencyjny],
      parcel: %w[nr\ działki numer\ działki działka działki nr\ dzialki]
    }.freeze

    module_function

    def raw
      Setting.plugin_redmine_gtt_uldk || {}
    end

    def auto_geocode?
      raw['auto_geocode'].to_s == '1'
    end

    def max_parcels
      n = raw['max_parcels'].to_i
      n.positive? ? n : 20
    end

    def unit_map
      Text.parse_unit_map(raw['unit_map'])
    end

    def field(kind)
      id = raw["#{kind_key(kind)}_field_id"].to_i
      return IssueCustomField.find_by(id: id) if id.positive?

      names = DEFAULT_NAMES.fetch(kind)
      IssueCustomField.sorted.detect { |cf| names.include?(cf.name.to_s.strip.downcase) }
    end

    def fields
      { commune: field(:commune), precinct: field(:precinct), parcel: field(:parcel) }
    end

    def field_ids
      fields.values.compact.map(&:id)
    end

    def kind_key(kind)
      { commune: 'commune', precinct: 'precinct', parcel: 'parcel' }.fetch(kind)
    end
  end
end
