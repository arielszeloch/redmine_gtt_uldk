# frozen_string_literal: true

module RedmineGttUldk
  # Turns the issue's commune / precinct / parcel number custom fields into
  # parcel geometries (via ULDK) and stores their union as the GTT geometry.
  #
  # Lookup order for each parcel number:
  # 1. a full ULDK id typed into the parcel field ("046101_1.0001.12/3"),
  # 2. commune listed in the "unit map" setting + numeric precinct
  #    -> GetParcelById "<unit>.<precinct 4 digits>.<number>",
  # 3. GetParcelByIdOrNr "<precinct> <number>"; when ULDK returns several
  #    parcels they are narrowed down by the unit from the unit map, or else
  #    by the commune name.
  # Only an unambiguous single match is used.
  class Geocoder
    Result = Struct.new(:status, :parcels, :missing, :message, keyword_init: true) do
      def ok?
        %i[ok partial].include?(status)
      end
    end

    # dry_run: resolve parcels but do not store the geometry.
    def self.call(issue, client: Client.new, dry_run: false)
      new(issue, client, dry_run: dry_run).call
    end

    def initialize(issue, client, dry_run: false)
      @issue = issue
      @client = client
      @dry_run = dry_run
      @fields = Settings.fields
    end

    def call
      unless @issue.respond_to?(:geom)
        return Result.new(status: :skipped, message: 'redmine_gtt geometry not available')
      end

      commune = value(:commune)
      precinct = value(:precinct)
      numbers = Text.parcel_numbers(value(:parcel))
      if numbers.empty? || (precinct.empty? && numbers.none? { |n| Text.full_id?(n) })
        return Result.new(status: :skipped, message: 'no precinct or parcel number')
      end

      parcels = []
      missing = []
      unit_map = Settings.unit_map
      numbers.first(Settings.max_parcels).each do |nr|
        found = resolve(commune, precinct, nr, unit_map)
        found ? parcels << found : missing << nr
      end
      if parcels.empty?
        return Result.new(status: :not_found, parcels: [], missing: missing,
                          message: "not found: #{missing.join(', ')}")
      end

      store(parcels) unless @dry_run
      msg = parcels.map(&:id).join(', ')
      msg += " (not found: #{missing.join(', ')})" if missing.any?
      Result.new(status: missing.any? ? :partial : :ok, parcels: parcels, missing: missing, message: msg)
    end

    private

    def value(kind)
      cf = @fields[kind]
      cf ? @issue.custom_field_value(cf).to_s.strip : ''
    end

    def resolve(commune, precinct, nr, unit_map)
      return single(@client.by_id(nr)) if Text.full_id?(nr)

      unit = Text.unit_for(commune, unit_map)
      code = Text.precinct_code(precinct)
      return single(@client.by_id("#{unit}.#{code}.#{nr}")) if unit && code

      candidates = @client.by_name("#{precinct} #{nr}")
      if candidates.size > 1
        if unit
          candidates = candidates.select { |p| p.id.to_s.start_with?("#{unit}.") }
        elsif !commune.empty?
          candidates = candidates.select { |p| Text.commune_match?(commune, p.commune) }
        end
      end
      single(candidates)
    end

    def single(list)
      list.size == 1 ? list.first : nil
    end

    # GTT reads and writes issue geometries with a 3D (has_z_coordinate)
    # RGeo factory, so the union is stored as 3D too.
    def store(parcels)
      conn = Issue.connection
      geoms = parcels.map { |p| "ST_GeomFromText(#{conn.quote(p.wkt)}, 4326)" }.join(', ')
      Issue.where(id: @issue.id).update_all("geom = ST_Force3D(ST_Union(ARRAY[#{geoms}]))")
    end
  end
end
