# frozen_string_literal: true

post 'issues/:id/gtt_uldk', to: 'gtt_uldk#geocode', as: 'gtt_uldk_geocode_issue', id: /\d+/
