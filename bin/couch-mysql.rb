require 'rest-client'
require "yaml"

#ActiveRecord::Base.logger.level = 3

couch_mysql_path = Dir.pwd + "/config/couchdb.yml"
db_settings = YAML.load_file(couch_mysql_path)

settings_path = Dir.pwd + "/config/settings.yml"
settings = YAML.load_file(settings_path)
$settings = settings
$app_mode = settings['application_mode']
$app_mode = 'HQ' if $app_mode.blank?

couch_db_settings = db_settings[Rails.env]

couch_protocol = couch_db_settings["protocol"]
couch_username = couch_db_settings["username"]
couch_password = couch_db_settings["password"]
couch_host = couch_db_settings["host"]
couch_db = "#{couch_db_settings["prefix"]}_#{couch_db_settings["suffix"]}"
couch_port = couch_db_settings["port"]

couch_mysql_path = Dir.pwd + "/config/database.yml"
db_settings = YAML.load_file(couch_mysql_path)
mysql_db_settings = db_settings[Rails.env]


$mysql_username = mysql_db_settings["username"]
$mysql_password = mysql_db_settings["password"]
$mysql_host = mysql_db_settings["host"] || '0.0.0.0'
$mysql_db = mysql_db_settings["database"]
$models = {}

Rails.application.eager_load!
ActiveRecord::Base.send(:subclasses).map(&:name).each do |n|
  $models[eval(n).table_name] = n
end


class Methods

  def self.angry_save(doc, seq)
    ordered_keys = (['core_person', 'person', 'users', 'user_role'] +
        doc.keys.reject{|k| ['_id', 'change_agent', '_rev', 'change_location_id', 'ip_addresses', 'location_id', 'type', 'district_id'].include?(k)}).uniq
    (ordered_keys || []).each do |table|
      next if doc[table].blank?
        doc[table].each do |p_value, data|
        record = eval($models[table]).find(p_value) rescue nil
        if !record.blank?
          record.update_columns(data)
        else
          record =  eval($models[table]).create(data) rescue nil

          if record.blank? || record == false
            id = "#{seq}"
            open("#{SETTINGS['main_ebrs_app']}/public/errors/#{id}", 'a') do |f|
              f << "#{doc['change_agent']}"
            end
          end
        end
      end
    end
  end

  def self.update_doc(doc, seq)

    person_id = doc['_id']
    change_agent = doc['change_agent']

    if doc['change_location_id'].present? && (doc['change_location_id'].to_s != $settings['location_id'].to_s)
      temp = {}
      if !doc['ip_addresses'].blank? && !doc['district_id'].blank?
        data = YAML.load_file("#{SETTINGS['main_ebrs_app']}/public/sites/#{doc['district_id']}.yml") rescue {}
        if data.blank?
          data = {}
        end
        temp = data
        if temp[doc['district_id'].to_i].blank?
          temp[doc['district_id'].to_i] = {}
        end
        temp[doc['district_id'].to_i]['ip_addresses'] = doc['ip_addresses']

        File.open("#{SETTINGS['main_ebrs_app']}/public/sites/#{doc['district_id']}.yml","w") do |file|
          YAML.dump(data, file)
          file.close
        end
      end

      begin
        self.angry_save(doc, seq)
      rescue => e
        puts e.to_s
        id = "#{seq}"
        open("#{SETTINGS['main_ebrs_app']}/public/errors/#{id}", 'a') do |f|
          f << "#{doc['change_agent']}"
          f << "\n\n#{e}"
        end
      end
    end
  end
end

cseq = CouchdbSequence.last
seq = cseq.seq rescue nil
if cseq.blank?
  CouchdbSequence.create(seq: 0)
end

seq = 0 if seq.blank?

changes_link = "#{couch_protocol}://#{couch_username}:#{couch_password}@#{couch_host}:#{couch_port}/#{couch_db}/_changes?include_docs=true&limit=500&since=#{seq}"

data = JSON.parse(RestClient.get(changes_link))
if (data['results'].count rescue 0) > 0
  puts "Loading  #{(data['results'].count rescue 0)} records"
end

FileUtils.touch("#{SETTINGS['main_ebrs_app']}/public/tap_sentinel")

(data['results'] || []).each do |result|
  seq = result['seq']
  Methods.update_doc(result['doc'], seq) rescue next
end

FileUtils.touch("#{SETTINGS['main_ebrs_app']}/public/tap_sentinel")

cseq = CouchdbSequence.last
cseq.seq = seq
cseq.save

errored = (`ls #{SETTINGS['main_ebrs_app']}/public/errors`.split("\n") rescue []) - ['test']

if errored.length > 0
  puts "Attempting to fix #{errored.length} failures"

  errored.each do |e|
   e_seq = (e.to_s.scan(/\d+/).first.to_i - 1) rescue nil
    next if e_seq.blank?
    err_link = "#{couch_protocol}://#{couch_username}:#{couch_password}@#{couch_host}:#{couch_port}/#{couch_db}/_changes?include_docs=true&limit=1&since=#{e_seq}"
    
    data = JSON.parse(RestClient.get(err_link))
   puts data['results'].length
    (data['results'] || []).each do |result|
      puts result['doc'].inspect
      `rm #{SETTINGS['main_ebrs_app']}/public/sites/#{e}`
      Methods.update_doc(result['doc'], seq) rescue next
     end
  end 
end 

ActiveRecord::Base.logger.level = 1
