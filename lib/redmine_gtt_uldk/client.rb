# frozen_string_literal: true

require 'net/http'
require 'uri'

module RedmineGttUldk
  # Thin client for the GUGiK ULDK service (https://uldk.gugik.gov.pl).
  #
  # Every answer starts with a status line: "-1 ..." means no result (or an
  # error), "0" or a count means result lines follow, one per parcel:
  # "id|commune|region|parcel|SRID=4326;POLYGON(...)".
  class Client
    ENDPOINT = URI('https://uldk.gugik.gov.pl/')
    OPEN_TIMEOUT = 4
    READ_TIMEOUT = 10

    Parcel = Struct.new(:id, :commune, :region, :number, :wkt, keyword_init: true)

    class Error < StandardError; end

    # Full parcel id, e.g. "046101_1.0001.123/4".
    def by_id(parcel_id)
      query('GetParcelById', parcel_id)
    end

    # "<precinct name or id> <parcel number>", e.g. "Fordon 123/4".
    def by_name(text)
      query('GetParcelByIdOrNr', text)
    end

    def self.parse(body)
      lines = body.to_s.dup.force_encoding('UTF-8').strip.lines.map(&:strip).reject(&:empty?)
      return [] if lines.empty? || lines.first.start_with?('-1')

      lines.drop(1).filter_map do |line|
        id, commune, region, number, geom = line.split('|', 5)
        next if geom.nil? || geom.strip.empty?

        Parcel.new(id: id, commune: commune, region: region, number: number,
                   wkt: geom.sub(/\ASRID=\d+;/, ''))
      end
    end

    private

    def query(request, ident)
      uri = ENDPOINT.dup
      uri.query = URI.encode_www_form(
        request: request, id: ident, srid: 4326,
        result: 'id,commune,region,parcel,geom_wkt'
      )
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                            open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri)
      end
      raise Error, "ULDK HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      self.class.parse(res.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "ULDK #{e.class}: #{e.message}"
    end
  end
end
