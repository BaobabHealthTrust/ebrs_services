if ['DC', 'FC'].include?(SETTINGS['application_mode'])
  SyncCheck.perform_in(5)
end
