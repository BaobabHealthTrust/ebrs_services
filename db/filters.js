{
  "filters" :
    {
        "my_location" : "function(doc, req){ if(req.query.location_id == doc.location_id || doc.change_agent == 'users' || doc.change_agent == 'user_role'){ return true }else{ return false }}"
    }
}
