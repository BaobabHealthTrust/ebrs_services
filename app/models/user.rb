class User < ActiveRecord::Base
  self.table_name = :users
  self.primary_key = :user_id
  include EbrsAttribute
  default_scope { where(voided: 0) }

  cattr_accessor :current
end





