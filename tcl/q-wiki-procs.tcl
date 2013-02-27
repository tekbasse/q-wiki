ad_library {

    API for q-wiki 
    @creation-date 17 Jul 2012
    @cs-id $Id:
}

ad_proc -public qw_page_id_exists { 
    page_id
    {instance_id ""}
} {
    Returns 1 if page_id exists for instance_id, else returns 0
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    
    set page_exists_p [db_0or1row wiki_page_get_id {select name from qw_wiki_page where id = :page_id and instance_id = :instance_id } ]
    return $page_exists_p
}

ad_proc -public qw_page_id_from_url { 
    page_url
    {instance_id ""}
} {
    Returns page_id if page_url exists for instance_id, else returns empty string.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set user_id [ad_conn user_id]
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]    
    if { $write_p } {
        # okay to return trashed pages
        set page_exists_p [db_0or1row wiki_page_get_id_from_url {select page_id from qw_page_url_map where url = :page_url and instance_id = :instance_id } ]
    } else {
        set page_exists_p [db_0or1row wiki_page_get_id_from_url {select page_id from qw_page_url_map where url = :page_url and instance_id = :instance_id and not ( trashed = '1' ) } ]
    }
    if { !$page_exists_p } {
        set page_id ""
    }
    return $page_id
}

ad_proc -public qw_page_url_from_id { 
    page_id
    {instance_id ""}
} {
    Returns page_url if page_id exists for instance_id, else returns empty string.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set user_id [ad_conn user_id]
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]    
    if { $write_p } {
        # okay to return trashed pages
        set page_exists_p [db_0or1row wiki_page_get_all_url_from_id {select url as page_url from qw_page_url_map where page_id = :page_id and instance_id = :instance_id } ]
    } else {
        set page_exists_p [db_0or1row wiki_page_get_untrashed_url_from_id {select url as page_url from qw_page_url_map where page_id = :page_id and instance_id = :instance_id and not ( trashed = '1' ) } ]
    }
    if { !$page_exists_p } {
        set page_stat_list [qw_page_stats $page_id]
        set template_id [lindex $page_stat_list 5]
        if { $template_id ne "" } {
            # get page_id this way: 
            select url as page_url from qw_page_url_map where page_id in ( select id as page_id from qw_wiki_page where instance_id = :instance_id and template_id = :template_id )
        } else {
            set page_url ""
        }
    }
    return $page_url
}


ad_proc -public qw_page_create { 
    url
    name
    title
    content
    keywords
    description
    comments
    {template_id ""}
    {flags ""}
    {instance_id ""}
    {user_id ""}
} {
    Creates wiki page. returns page_id, or 0 if error. instance_id is usually package_id
} {

    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set return_page_id 0
    set create_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege create]
    ns_log Notice "qw_page_create: create_p $create_p"
    if { $create_p } {
        set template_id ""
        set trashed_p 0
        set page_url_exists_p [db_0or1row wiki_url_get_page_id {select page_id from qw_page_url_map where url = :url and instance_id = :instance_id } ]
        if { $page_url_exists_p } {
            set page_id_exists_p [db_0or1row wiki_url_get_id { select page_id from qw_page_url_map where page_id = :page_id and instance_id = :instance_id } ]
            if { $page_id_exists_p } { 
                set page_id_stats_list [qw_page_stats $page_id $instance_id $user_id]
                set template_id [lindex $page_id_stats_list 5]
            }
        } else {
            set page_id_exists_p 0
        }
        set page_id [db_nextval qw_page_id_seq]
        if { $template_id eq "" } {
            set template_id $page_id
        }
        db_transaction {
            ns_log Notice "qw_page_create: wiki_page_create id '$page_id' template_id '$template_id' name '$name' instance_id '$instance_id' user_id '$user_id'"
            db_dml wiki_page_create { insert into qw_wiki_page
                (id,template_id,name,title,keywords,description,content,comments,instance_id,user_id,last_modified,created)
                values (:page_id,:template_id,:name,:title,:keywords,:description,:content,:comments,:instance_id,:user_id,current_timestamp,current_timestamp) }
            
            # Add entry to qw_page_url_map if new page, otherwise update existing record.
            # A new record is only when template_id = page_id
            if { $page_id eq $template_id } {
                ns_log Notice "qw_page_create: wiki_url_create url '$url' page_id '$page_id' trashed_p '$trashed_p' instance_id '$instance_id'"
                db_dml wiki_page_url_create { insert into qw_page_url_map
                    ( url, page_id, trashed, instance_id )
                    values ( :url, :page_id, :trashed_p, :instance_id ) }
            } else {
                ns_log Notice "qw_page_create: wiki_url_update url '$url' page_id '$page_id' trashed_p '$trashed_p' instance_id '$instance_id'"
                db_dml wiki_page_url_update { update qw_page_url_map
                    set page_id = :page_id where url = :url }
            }
            set return_page_id $page_id
            
        } on_error {
            set return_page_id 0
            ns_log Error "qw_page_create: general psql error during db_dml for url $url"
        }
    }
    return $return_page_id
}

ad_proc -public qw_page_stats { 
    page_id
    {instance_id ""}
    {user_id ""}
} {
    Returns page stats as a list: name, title, comments, keywords, description, template_id, flags, trashed, popularity, time last_modified, time created, user_id
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    # check permissions
    set read_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege read]

    if { $read_p } {
        set return_list_of_lists [db_list_of_lists wiki_page_stats { select name, title, comments, keywords, description, template_id, flags, trashed, popularity, last_modified, created, user_id from qw_wiki_page where id = :page_id and instance_id = :instance_id } ] 
        # convert return_lists_of_lists to return_list
        set return_list [lindex $return_list_of_lists 0]
        # data consistency measure
        if { [llength $return_list] > 1 && [lindex $return_list 7] eq "" } {
            set return_list [lreplace $return_list 7 7 0]
        }

    } else {
        set return_list [list ]
    }
    return $return_list
}

ad_proc -public qw_pages { 
    {instance_id ""}
    {user_id ""}
    {template_id ""}
} {
    Returns a list of q-wiki page_ids. If template_id is included, the results are scoped to pages with same template (aka revisions). If user_id is included, the results are scoped to the user.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set party_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    } else {
        set party_id $user_id
    }
    set read_p [permission::permission_p -party_id $party_id -object_id $instance_id -privilege read]

    if { $read_p } {
        if { $template_id eq "" } {
            if { $user_id ne "" } {
                set return_list [db_list wiki_pages_user_list { select id from qw_wiki_page where instance_id = :instance_id and user_id = :user_id and id in ( select page_id from qw_page_url_map where instance_id = :instance_id ) } ]
            } else {
                set return_list [db_list wiki_pages_list { select id from qw_wiki_page where instance_id = :instance_id and id in ( select page_id from qw_page_url_map where instance_id = :instance_id ) } ]
            }
        } else {
            set has_template [db_0or1row wiki_page_template "select template_id as db_template_id from qw_wiki_page where template_id= :template_id"]
            if { $has_template && [info exists db_template_id] && $template_id > 0 } {
                if { $user_id ne "" } {
                    set return_list [db_list wiki_pages_t_u_list { select id from qw_wiki_page where instance_id = :instance_id and user_id = :user_id and template_id = :template_id } ]
                } else {
                    set return_list [db_list wiki_pages_list { select id from qw_wiki_page where instance_id = :instance_id and template_id = :template_id } ]
                }
            } else {
                set return_list [list ]
            }
        }
    } else {
        set return_list [list ]
    }
    return $return_list
} 

ad_proc -public qw_page_read { 
    page_id
    {instance_id ""}
    {user_id ""}
    
} {
    Reads page with id. Returns page as list of attribute values: name, title, keywords, description, template_id, flags, trashed, popularity, last_modified, created, user_id, content, comments
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set read_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege read]
    set return_list [list ]
    if { $read_p } {
        set return_list_of_lists [db_list_of_lists wiki_page_get { select name, title, keywords, description, template_id, flags, trashed, popularity, last_modified, created, user_id, content, comments from qw_wiki_page where id = :page_id and instance_id = :instance_id } ] 
        # convert return_lists_of_lists to return_list
        set return_list [lindex $return_list_of_lists 0]
    }
    return $return_list
}

ad_proc -public qw_page_write {
    name
    title
    content
    keywords
    description
    comments
    page_id
    {template_id ""}
    {flags ""}
    {instance_id ""}
    {user_id ""}
} {
    Writes a new revision of an existing q-wiki page. page_id is the current value from qw_page_url_map.page_id (before this write).
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]
    if { $write_p } {
        set page_exists_p [db_0or1row wiki_page_get_id {select user_id as creator_id from qw_wiki_page where id = :page_id } ]
        if { $page_id_exists_p } { 
            set page_id_stats_list [qw_page_stats $page_id $instance_id $user_id]
            set template_id [lindex $page_id_stats_list 5]
        }

        if { $page_exists_p } {
            set old_page_id $page_id
            set new_page_id [db_nextval qw_page_id_seq]
            ns_log Notice "qw_page_write: wiki_page_create id '$page_id' template_id '$template_id' name '$name' instance_id '$instance_id' user_id '$user_id'"
            db_transaction {
                db_dml wiki_page_create { insert into qw_wiki_page
                    (id,template_id,name,title,keywords,description,content,comments,instance_id,user_id, last_modified, created)
                    values (:new_page_id,:template_id,:name,:title,:keywords,:description,:content,:comments,:instance_id,:user_id, current_timestamp, current_timestamp) }
                ns_log Notice "qw_page_create: wiki_page_id_update page_id '$new_page_id' instance_id '$instance_id' old_page_id '$old_page_id'"
                db_dml wiki_page_id_update { update qw_page_url_map
                    set page_id = :new_page_id where instance_id = :instance_id and page_id = :old_page_id }
            } on_error {
                set success 0
                ns_log Error "qw_page_write: general db error during db_dml"
            }
        } else {
            set success 0
            ns_log Warning "qw_page_write: no page exists for page_id $page_id"
        }
        set success 1
    } else {
        set success 0
    }
    return $success
}


ad_proc -public qw_page_delete {
    {page_id ""}
    {template_id ""}
    {instance_id ""}
    {user_id ""}
} {
    page_id can be a list of page_id's. Deletes page_id (subject to permission check) and item already trashed.
    Returns 1 if deleted. Returns 0 if there were any issues.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set delete_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege delete]
    set success $delete_p
    if { $delete_p && $page_id > 0 } {
        db_transaction {
            db_dml wiki_page_delete { delete from qw_wiki_page 
                where id=:page_id and instance_id =:instance_id and user_id=:user_id }
            set page_id_active [db0or1row qw_url_from_page_id { select url from qw_page_id_url where page_id = :page_id and instance_id = :instance_id } ]
            if { $page_id_active } {
                # change the page_id
                set template_id [lindex [qw_page_stats $page_id $instance_id] 5]
                db0or1row qw_previous_page_id { select page_id as new_page_id, created from qw_wiki_page where template_id = :template_id and instance_id = :instance_id and trashed = '0' order by created limit 1 }
                if { [info exists new_page_id] } {
                    #  point to the most recent untrashed revision
                    db_dml wiki_page_id_update { update qw_page_url_map
                        set page_id = :new_page_id where instance_id = :instance_id and page_id = :old_page_id }
                } else {
                    # point to the most recent trashed version, then trash the entire page
                    db0or1row qw_previous_page_id { select page_id as new_page_id, created from qw_wiki_page where template_id = :template_id and instance_id = :instance_id order by created limit 1 }
                    if { [info exists new_page_id] } {
                        db_dml wiki_page_id_update { update qw_page_url_map
                            set page_id = :new_page_id where instance_id = :instance_id and page_id = :old_page_id }
                    } 
                    db_dml wiki_page_id_update { update qw_page_url_map
                        set trashed = '1' where page_id = :page_id and instance_id = :instance_id }
                }
            }
            set success 1
        } on_error {
            set success 0
            ns_log Error "qw_page_delete: general db error during db_dml wiki_page_delete"
        }
    } elseif { $delete_p && $template_id > 0 } {

        db_transaction {
            db_dml wiki_template_delete { delete from qw_wiki_page 
                where template_id=:template_id and instance_id =:instance_id and user_id=:user_id }
            set success 1
        } on_error {
            set success 0
            ns_log Error "qw_page_delete: general db error during db_dml wiki_template_delete"
        }
    }
        
    return $success
}

ad_proc -public qw_page_trash {
    {trash_p "1"}
    {page_id ""}
    {template_id ""}
    {instance_id ""}
    {user_id ""}
} {
    page_id can be a list of page_id's. Trashes/untrashes page_id (subject to permission check).
    set trash_p to 1 (default) to trash page. Set trash_p to '0' to untrash. 
    Returns 1 if successful, otherwise returns 0
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set delete_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege delete]
    if { $delete_p } {
        if { $page_id > 0 } {
            if { $trash_p } {
                db_dml wiki_page_trash_tog { update qw_wiki_page set trashed = '1'
                    where id=:page_id and instance_id =:instance_id and user_id=:user_id }
            } else {
                db_dml wiki_page_trash_tog { update qw_wiki_page set trashed = '0'
                    where id=:page_id and instance_id =:instance_id and user_id=:user_id }
            } 
        } elseif { $template_id > 0 } {
            if { $trash_p } {
                db_dml wiki_template_trash_tog { update qw_wiki_page set trashed = '1'
                    where template_id=:template_id and instance_id =:instance_id and user_id=:user_id }
            } else {
                db_dml wiki_template_trash_tog { update qw_wiki_page set trashed = '0'
                    where template_id=:template_id and instance_id =:instance_id and user_id=:user_id }
### also need to trash the qw_page_id_url_map
            }
        }
    }

    # does the current, active wiki page_id need to be updated?
    set page_id_active [db0or1row qw_url_from_page_id { select url from qw_page_id_url where page_id = :page_id and instance_id = :instance_id } ]
    if { $page_id_active } {
                # change the page_id
                set template_id [lindex [qw_page_stats $page_id $instance_id] 5]
                db0or1row qw_previous_page_id { select page_id as new_page_id, created from qw_wiki_page where template_id = :template_id and instance_id = :instance_id and trashed = '0' order by created limit 1 }
                if { [info exists new_page_id] } {
                    #  point to the most recent untrashed revision
                    db_dml wiki_page_id_update { update qw_page_url_map
                        set page_id = :new_page_id where instance_id = :instance_id and page_id = :old_page_id }
                } else {
                    # point to the most recent trashed version, then trash the entire page
                    db0or1row qw_previous_page_id { select page_id as new_page_id, created from qw_wiki_page where template_id = :template_id and instance_id = :instance_id order by created limit 1 }
                    if { [info exists new_page_id] } {
                        db_dml wiki_page_id_update { update qw_page_url_map
                            set page_id = :new_page_id where instance_id = :instance_id and page_id = :old_page_id }
                    } 
                    db_dml wiki_page_id_update { update qw_page_url_map
                        set trashed = '1' where page_id = :page_id and instance_id = :instance_id }
                }
            }


    return $delete_p
}

