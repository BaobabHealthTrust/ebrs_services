@database = YAML.load_file("#{Rails.root}/config/couchdb.yml")[Rails.env]

location_id = SETTINGS['location_id']
if SETTINGS['application_mode'] == 'FC'
  filter = 'filters.js'
else
  filter = 'filters2.js'
end

source = "#{@database['protocol']}://#{@database['username']}:#{@database['password']}@#{@database['host']}:#{@database['port']}/#{@database['prefix']}_#{@database['suffix']}"
target = "#{SETTINGS['sync_protocol']}://#{SETTINGS['sync_username']}:#{SETTINGS['sync_password']}@#{SETTINGS['sync_host']}/#{SETTINGS['sync_database']}"
replicator = "#{@database['protocol']}://#{@database['username']}:#{@database['password']}@#{@database['host']}:#{@database['port']}/_replicate"


doc = JSON.parse(`cd #{Rails.root}/db && curl -s -H 'Content-Type: application/json' -X GET #{source}/_design/MyLocation#{location_id}`)
if doc["error"].present?
`cd #{Rails.root}/db && curl -s -H 'Content-Type: application/json' -X PUT -d @#{filter} #{source}/_design/MyLocation#{location_id}`
end

doc = JSON.parse(`cd #{Rails.root}/db && curl -s -H 'Content-Type: application/json' -X GET #{target}/_design/MyLocation#{location_id}`)
if doc["error"].present?
  `cd #{Rails.root}/db && curl -s -H 'Content-Type: application/json' -X PUT -d @#{filter} #{target}/_design/MyLocation#{location_id}`
end

%x[curl -s -k -H 'Content-Type: application/json' -X POST -d '#{{
    source: source,
    target: target,
    connection_timeout: 10000,
    retries_per_request: 10,
    http_connections: 30,
    continuous: true
}.to_json}' "#{replicator}"]

%x[curl -s -k -H 'Content-Type: application/json' -X POST -d '#{{
    source: target,
    target: source,
    connection_timeout: 10000,
    retries_per_request: 10,
    http_connections: 30,
    filter: "MyLocation#{location_id}/my_location",
    query_params: {
        location_id: location_id.to_s
    },
    continuous: true
     }.to_json}' "#{replicator}/_replicate"]


FileUtils.touch("#{SETTINGS['main_ebrs_app']}/public/sync_sentinel")
