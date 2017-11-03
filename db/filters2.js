{
  "filters" :
    {
        "my_location" : "function(doc, req){ if((req.query.location_id == doc.district_id) || doc.change_agent == 'user' || doc.change_agent == 'user_role'){ return true }else{ return false }}"
    }
}
