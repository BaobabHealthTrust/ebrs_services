class PersonRecordStatus < ActiveRecord::Base
    self.table_name = :person_record_statuses
    self.primary_key = :person_record_status_id
    include EbrsAttribute

    belongs_to :person, foreign_key: "person_id"
    belongs_to :status, foreign_key: "status_id"


    def self.new_record_state(person_id, state, change_reason='', user_id=nil)
    
     begin

      user_id = User.current.id if user_id.blank?
      state_id = Status.where(:name => state).first.id
      trail = self.where(:person_id => person_id, :voided => 0)
      trail.each do |state|
        state.update_attributes(
            voided: 1,
            date_voided: Time.now,
            voided_by: user_id
        )
      end

      self.create(
          person_id: person_id,
          status_id: state_id,
          voided: 0,
          creator: user_id,
          comments: change_reason
      )

      birth_details = PersonBirthDetail.where(person_id: person_id).last

        if ['HQ-CAN-PRINT', 'HQ-CAN-RE-PRINT'].include?(state) && birth_details.national_serial_number.blank?
            allocation = IdentifierAllocationQueue.new
            allocation.person_id = person_id
            allocation.assigned = 0
            allocation.creator = User.current.id
            allocation.person_identifier_type_id = PersonIdentifierType.where(:name => "Birth Registration Number").last.person_identifier_type_id
            allocation.created_at = Time.now
            allocation.save
        end
    rescue StandardError => e
         self.log_error(e.message,person_id)
     end
  end

  def self.status(person_id)
      self.where(:person_id => person_id, :voided => 0).last.status.name
  end

  def self.log_error(error_msge, content)

      file_path = "#{Rails.root}/app/assets/data/error_log.txt"
      if !File.exists?(file_path)
             file = File.new(file_path, 'w')
      else
         File.open(file_path, 'a') do |f|
            f.puts "#{error_msge} >>>>>> #{content}"
        end
      end

  end

  def self.stats(types=['Normal', 'Adopted', 'Orphaned', 'Abandoned'], approved=true, locations = [])

    status_map          = Status.all.inject({}) { |r, d| r[d.id] = d.name; r }
    result = {}
    birth_type_ids = BirthRegistrationType.where(" name IN ('#{types.join("', '")}')").map(&:birth_registration_type_id) + [-1]
    loc_str = ""
    if !locations.blank?
      loc_str = " AND p.location_created_at IN (#{locations.join(', ')})"
    end

    PersonRecordStatus.find_by_sql("
      SELECT s.status_id, COUNT(*) c FROM person_record_statuses s
        INNER JOIN person_birth_details p ON p.person_id = s.person_id AND p.birth_registration_type_id IN (#{birth_type_ids.join(', ')})
        WHERE s.voided = 0
        GROUP BY s.status_id
    ").each do |row|
      result[status_map[row['status_id']]] = row['c']
    end

    unless approved == false
      excluded_states = ['HQ-REJECTED', 'HQ-VOIDED', 'HQ-PRINTED', 'HQ-DISPATCHED'].collect{|s| Status.find_by_name(s).id}
      included_states = Status.where("name like 'HQ-%' ").map(&:status_id)

      result['APPROVED BY ADR'] =  self.find_by_sql("
    SELECT COUNT(*) c FROM person_record_statuses
    WHERE voided = 0 AND status_id NOT IN (#{excluded_states.join(', ')}) AND status_id IN (#{included_states.join(', ')})")[0]['c']
    end
    result
  end

  def self.type_stats(states=nil, old_state=nil, old_state_creator=nil)
    result = {}
    return result if states.blank?
    had_query = ''

    if old_state.present?

      prev_status_ids = Status.where(" name IN ('#{old_state.split("|").join("', '")}')").map(&:status_id)
      had_query = "INNER JOIN person_record_statuses prev_s ON prev_s.person_id = s.person_id AND prev_s.status_id IN (#{prev_status_ids.join(', ')})"

      if old_state_creator.present?
        user_ids = UserRole.where(role_id: Role.where(role: old_state_creator).last.id).map(&:user_id)
        user_ids = [-1] if user_ids.blank?

        had_query += " AND prev_s.creator IN (#{user_ids.join(', ')})"
      end
    end

    status_ids = states.collect{|s| Status.where(name: s).last.id} rescue Status.all.map(&:status_id)

    data = self.find_by_sql("
    SELECT t.name, COUNT(*) c FROM person_birth_details d
      INNER JOIN person_record_statuses s ON d.person_id = s.person_id
      INNER JOIN birth_registration_type t ON t.birth_registration_type_id = d.birth_registration_type_id
        #{had_query}
      WHERE s.voided = 0 AND s.status_id IN (#{status_ids.join(', ')}) GROUP BY d.birth_registration_type_id")

    (data || []).each do |r|
      result[r['name']] = r['c']
    end
    result
  end
end
