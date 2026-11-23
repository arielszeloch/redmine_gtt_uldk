# frozen_string_literal: true

namespace :redmine do
  namespace :gtt_uldk do
    desc <<~DESC
      Fill the geometry of issues that have none, using ULDK.
      ENV: PROJECT=identifier (default: all projects with the GTT module),
           LIMIT=n, DRY_RUN=1 (resolve only, store nothing), DELAY=seconds between issues (default 0.35)
    DESC
    task backfill: :environment do
      limit = ENV['LIMIT'].presence&.to_i
      dry = ENV['DRY_RUN'].present?
      delay = (ENV['DELAY'] || '0.35').to_f
      parcel_cf = RedmineGttUldk::Settings.field(:parcel)
      abort 'No parcel number custom field configured or found.' unless parcel_cf

      projects = Project.has_module(:gtt)
      projects = projects.where(identifier: ENV['PROJECT']) if ENV['PROJECT'].present?
      scope = Issue.where(geom: nil, project_id: projects.select(:id))
                   .joins(:custom_values)
                   .where(custom_values: { custom_field_id: parcel_cf.id })
                   .where.not(custom_values: { value: [nil, ''] })
                   .order(:id)
      scope = scope.limit(limit) if limit

      client = RedmineGttUldk::Client.new
      stats = Hash.new(0)
      problems = []
      scope.each do |issue|
        result = RedmineGttUldk::Geocoder.call(issue, client: client, dry_run: dry)
        stats[result.status] += 1
        problems << "##{issue.id}\t#{result.status}\t#{result.message}" unless result.status == :ok
      rescue StandardError => e
        stats[:error] += 1
        problems << "##{issue.id}\terror\t#{e.class}: #{e.message}"
      ensure
        sleep delay
      end

      puts "Result#{' (DRY RUN)' if dry}: #{stats.to_h}"
      puts problems
    end
  end
end
