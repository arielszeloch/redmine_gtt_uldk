# frozen_string_literal: true

Redmine::Plugin.register :redmine_gtt_uldk do
  name 'GTT ULDK parcels'
  author 'Ariel Szeloch'
  description 'Fills the redmine_gtt issue geometry with Polish cadastral parcel ' \
              'boundaries fetched from the GUGiK ULDK service, based on issue custom fields.'
  version '1.0.0'
  url 'https://github.com/arielszeloch/redmine_gtt_uldk'
  author_url 'https://github.com/arielszeloch'
  requires_redmine version_or_higher: '6.0.0'
  requires_redmine_plugin :redmine_gtt, version_or_higher: '6.0.0'

  settings default: {
             'commune_field_id' => '',
             'precinct_field_id' => '',
             'parcel_field_id' => '',
             'unit_map' => '',
             'auto_geocode' => '1',
             'max_parcels' => '20'
           },
           partial: 'settings/gtt_uldk_settings'
end

# Redmine 6+ evaluates plugin init.rb inside to_prepare, so the patch can be
# applied directly (lib/ is autoloaded by Zeitwerk).
RedmineGttUldk::IssuePatch.apply
RedmineGttUldk::Hooks
