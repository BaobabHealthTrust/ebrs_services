#This file is used to sync data birectional from and to all enabled sites
#Kenneth Kapundi@21/Sept/2017

require 'open3'
def is_up?(host)
  host, port = host.split(':')
  a, b, c = Open3.capture3("nc -vw 5 #{host} #{port}")
  b.scan(/succeeded/).length > 0
end


district_tag_id = LocationTag.where(name: "District").last.id
LocationTagMap.where(location_tag_id: district_tag_id).map(&:location_id).each do |loc_id|
  if !File.exist?("#{SETTINGS['main_ebrs_app']}/public/sites/#{loc_id}.yml")
    File.open("#{SETTINGS['main_ebrs_app']}/public/sites/#{loc_id}.yml","w") do |file|
      data = {loc_id =>
        {
          online: false
        }
      }
      file.write data.to_yaml
      file.close
    end
  end
end

files = Dir.glob( File.join("#{SETTINGS['main_ebrs_app']}/public/sites", '**', '*.yml')).to_a
(files || []).each do |f|
  data = YAML.load_file(f) rescue {}
  (data || []).each do |site_id, d|
    next if d.blank?
    up = false
    (d['ip_addresses'] || []).each do |adr|
      if is_up?(adr)
        up = true
        data[site_id]['online'] = true
        data[site_id]['last_seen'] = "#{Time.now}"
        next
      end

      if up == true
        data[site_id]['online'] = true
        data[site_id]['last_seen'] = "#{Time.now}"
      else
        data[site_id]['online'] = false
      end
    end

    File.open("#{SETTINGS['main_ebrs_app']}/public/sites/#{site_id}.yml","w") do |file|
      file.write data.to_yaml
    end
  end

end


    @last_twelve_months_reported_births = {}
    last_year = Date.today.ago(11.month).beginning_of_month.strftime('%Y-%m-%d 00:00:00')
    curr_year = Date.today.strftime('%Y-%m-%d 23:59:59') 
    
    location_tag = LocationTag.where(name: 'District').first

    locations = Location.group("location.location_id").where("parent_location IS NULL AND t.location_tag_id = ?",
      location_tag.id).joins("INNER JOIN location_tag_map m 
      ON m.location_id = location.location_id
      INNER JOIN location_tag t 
      ON t.location_tag_id = m.location_tag_id").order("location.location_id ASC")

    (locations || []).each_with_index do |l, i|
      district_code = l.code
      if @last_twelve_months_reported_births[district_code].blank?
        @last_twelve_months_reported_births[district_code] = {} 
      end
    end

    @stats_months = []

    (0.upto(11)).each_with_index do |num, i|
      start_date  = Date.today.ago(num.month).beginning_of_month.strftime('%Y-%m-%d 00:00:00')
      end_date    = start_date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
      @stats_months << "#{start_date.to_date.month}#{start_date.to_date.year}".to_i #end_date.to_date.month

      (@last_twelve_months_reported_births.keys || []).each do |code|
        details = PersonBirthDetail.where("date_reported BETWEEN ? AND ?
          AND LEFT(district_id_number,#{code.length}) = ?",
          start_date, end_date, code).count

        @last_twelve_months_reported_births[code]["#{start_date.to_date.month}#{start_date.to_date.year}".to_i] = details
      end
    end

   File.open("#{SETTINGS['main_ebrs_app']}/dashboard_data.json", 'w'){|f| 
	f.write({"last_twelve_months_reported_births" => @last_twelve_months_reported_births, "stats_months" => @stats_months}.to_json)
   }


FileUtils.touch("#{SETTINGS['main_ebrs_app']}/public/ping_sentinel")

available = false
url = YAML.load_file("#{SETTINGS['main_ebrs_app']}/config/settings.yml")["query_by_nid_address"]
remote_data = JSON.parse(RestClient.post(url, "RRJ5QAE4".to_json, content_type: "application/json", accept: "json")) rescue nil
if !remote_data.blank? && remote_data.has_key?("FirstName")
    available = true
end

File.open("#{SETTINGS['main_ebrs_app']}/public/nris_status", 'w'){|f|
    f.write(available)
}

PersonRecordStatus.find_by_sql(
    "SELECT prs.person_record_status_id FROM person_record_statuses prs
    LEFT JOIN person_record_statuses prs2 ON prs.person_id = prs2.person_id AND prs.voided = 0 AND prs2.voided = 0
    WHERE prs.created_at < prs2.created_at").map(&:person_record_status_id).each{|s|

    prs  = PersonRecordStatus.find(s)
    prs.voided = 1
    prs.save
}

stats       = PersonRecordStatus.stats

File.open("#{SETTINGS['main_ebrs_app']}/stats.json", 'w'){|f|
  f.write(stats.to_json)
}



