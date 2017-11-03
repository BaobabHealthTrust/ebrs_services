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

couch_db_settings = db_settings['production']

couch_protocol = couch_db_settings["protocol"]
couch_username = couch_db_settings["username"]
couch_password = couch_db_settings["password"]
couch_host = couch_db_settings["host"]
couch_db = "#{couch_db_settings["prefix"]}_#{couch_db_settings["suffix"]}"
couch_port = couch_db_settings["port"]


couch_mysql_path = Dir.pwd + "/config/database.yml"
db_settings = YAML.load_file(couch_mysql_path)
mysql_db_settings = db_settings[Rails.env]

mysql_username = mysql_db_settings["username"]
mysql_password = mysql_db_settings["password"]
mysql_host = mysql_db_settings["host"] || '0.0.0.0'
mysql_db = mysql_db_settings["database"]

$mysql_username = mysql_db_settings["username"]
$mysql_password = mysql_db_settings["password"]
$mysql_host = mysql_db_settings["host"] || '0.0.0.0'
$mysql_db = mysql_db_settings["database"]
mysql_port = mysql_db_settings["port"] || '3306'
mysql_adapter = mysql_db_settings["adapter"]
#reading db_mapping

$models = {}


Rails.application.eager_load!
ActiveRecord::Base.send(:subclasses).map(&:name).each do |n|
  $models[eval(n).table_name] = n
end


class Methods

  def self.angry_save(doc)
    ordered_keys = (['core_person', 'person', 'user', 'user_role'] +
        doc.keys.reject{|k| ['_id', 'change_agent', '_rev', 'change_location_id', 'ip_addresses', 'location_id', 'type', 'district_id'].include?(k)}).uniq
    (ordered_keys || []).each do |table|
      next if doc[table].blank?
      doc[table].each do |p_value, data|
        puts table
        record = eval($models[table]).find(p_value) rescue nil
        if !record.blank?
          record.update_columns(data)
        else
          record =  eval($models[table]).new(data)
          query = record.class.arel_table.create_insert.tap { |im| im.insert(record.send(
                                                                                 :arel_attributes_with_values_for_create,
                                                                                 record.attribute_names)) }.to_sql
          ActiveRecord::Base.connection.execute(<<-EOQ)
#{query}
          EOQ
        end
      end
    end
  end

  def self.update_doc(doc, seq)
    FileUtils.touch("#{Rails.root}/public/tap_sentinel")

    person_id = doc['_id']
    change_agent = doc['change_agent']

    if doc['change_location_id'].present? && (doc['change_location_id'].to_s != $settings['location_id'].to_s)
      temp = {}
      if !doc['ip_addresses'].blank? && !doc['district_id'].blank?
        data = YAML.load_file("#{Dir.pwd}/public/sites/#{doc['district_id']}.yml") rescue {}
        if data.blank?
          data = {}
        end
        temp = data
        if temp[doc['district_id'].to_i].blank?
          temp[doc['district_id'].to_i] = {}
        end
        temp[doc['district_id'].to_i]['ip_addresses'] = doc['ip_addresses']

        File.open("#{Dir.pwd}/public/sites/#{doc['district_id']}.yml","w") do |file|
          YAML.dump(data, file)
          file.close
        end
      end
      %x[
        mysql -h#{$mysql_host} -u#{$mysql_username} -p#{$mysql_password} -e "SET GLOBAL foreign_key_checks=0"
      ]

      begin
        self.angry_save(doc)
      rescue => e
        puts e.to_s
        id = "#{p_value}_#{seq}"
        open("#{Dir.pwd}/public/errors/#{id}", 'a') do |f|
          f << "#{record}"
          f << "\n\n#{e}"
        end
      end

      %x[
        mysql -h#{$mysql_host} -u#{$mysql_username} -p#{$mysql_password} -e "SET GLOBAL foreign_key_checks=1"
      ]
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
(data['results'] || []).each do |result|
  seq = result['seq']
  Methods.update_doc(result['doc'], seq) rescue next
end

cseq = CouchdbSequence.last
cseq.seq = seq
cseq.save

ActiveRecord::Base.logger.level = 1

CouchSQL.perform_in(2)
