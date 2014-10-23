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

ad_proc -public qw_change_page_id_for_url {
    page_id_new
    page_url
    {instance_id ""}
} {
    Changes the active revision (page_id) for page_url. Returns 1 if successful, otherwise 0.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set user_id [ad_conn user_id]
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write] 
    set success_p 0
    if { $write_p } {
        # new page
        set page_new_stats_list [qw_page_stats $page_id_new $instance_id]
        set template_id_new [lindex $page_new_stats_list 5]
        set trashed_p_new [lindex $page_new_stats_list 7]
        set page_url_new [qw_page_url_from_id $page_id_new $instance_id]
        # new and current page
        if { $page_url_new ne "" && $page_url eq $page_url_new && !$trashed_p_new } {
            db_dml wiki_change_revision { update qw_page_url_map
            set page_id = :page_id_new where url = :page_url and instance_id = :instance_id }
            db_dml wiki_change_revision_active { update qw_wiki_page
                set last_modified = current_timestamp where id = :page_id_new and instance_id = :instance_id }
            set success_p 1
        }
    }
    return $success_p
}

# qw_page_rename start
ad_proc -public qw_page_rename {
    page_url
    page_name
    {instance_id ""}
} {
    Changes the url where the page is served from page_url to page_name. Returns 1 if successful, otherwise 0.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set user_id [ad_conn user_id]
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write] 
    set success_p 0
    if { $write_p && $page_url ne "" && $page_name ne "" } {
        set page_urls_id [qw_page_id_from_url $page_url $instance_id]
        set page_stats_list [qw_page_stats $page_urls_id $instance_id]
        set template_id [lindex $page_stats_list 5]
        # does page_name already exist? 
        set pn_page_id  [qw_page_id_from_url $page_name $instance_id]

        if { $pn_page_id ne "" } {
            set pn_stats_list [qw_page_stats $pn_page_id $instance_id]
            set pn_template_id [lindex $pn_stats_list 5]
            # just:
            # mv the template_id of page_url revisions to page_name revisions template_id
            db_dml wiki_name_change_template_id { update qw_wiki_page
                set last_modified = current_timestamp, template_id =:pn_template_id, name =:page_name where template_id = :template_id and instance_id = :instance_id }
            # get rid of the existing page_name entry
            db_dml wiki_name_change_url_del { delete from qw_page_url_map
                where url = :page_url and instance_id = :instance_id }
            
        } else {
            # update qw_page_url_map.url qw_wiki_page.page_name to page_name for template_id, instance_id
            db_dml wiki_name_change_pages { update qw_wiki_page
                set last_modified = current_timestamp, name = :page_name where template_id = :template_id and instance_id = :instance_id }
            db_dml wiki_name_change_url { update qw_page_url_map
                set url = :page_name where url = :page_url and instance_id = :instance_id }
        }
        set success_p 1
    }
    return $success_p
}


#
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
        set page_exists_p [db_0or1row wiki_page_get_id_from_url {select page_id from qw_page_url_map 
            where url = :page_url and instance_id = :instance_id } ]
    } else {
        set page_exists_p [db_0or1row wiki_page_get_id_from_url {select page_id from qw_page_url_map 
            where url = :page_url and instance_id = :instance_id and not ( trashed = '1' ) } ]
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
    Returns page_url if page_id exists for instance_id, even if page_id is not the active revision, else returns empty string.
} {
    set page_url ""
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set user_id [ad_conn user_id]
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]    
    if { $write_p } {
        # okay to return trashed pages
        set page_exists_p [db_0or1row wiki_page_get_all_url_from_id { select url as page_url from qw_page_url_map 
            where page_id = :page_id and instance_id = :instance_id } ]
    } else {
        set page_exists_p [db_0or1row wiki_page_get_untrashed_url_from_id { select url as page_url from qw_page_url_map 
            where page_id = :page_id and instance_id = :instance_id and not ( trashed = '1' ) } ]
    }
    if { !$page_exists_p } {
        set page_stat_list [qw_page_stats $page_id]
        set template_id [lindex $page_stat_list 5]
#        ns_log Notice "qw_page_url_from_id: page_id '$page_id' template_id '$template_id'"
        if { $template_id ne "" } {
            # get page_url from template_id
            db_0or1row wiki_page_get_url_from_ids_template { select url as page_url from qw_page_url_map 
                where page_id in ( select id as page_id from qw_wiki_page 
                                   where instance_id = :instance_id and template_id = :template_id ) } 
        } 
        if { $page_url eq "" } {
            # maybe page_id doesn't exist, but page_id is a template_id 
            db_0or1row wiki_page_get_url_from_template_id { select url as page_url from qw_page_url_map 
                where page_id in ( select id as page_id from qw_wiki_page 
                                   where instance_id = :instance_id and template_id = :page_id ) } 
        }
    }
    return $page_url
}

ad_proc -public qw_page_url_id_from_template_id { 
    template_id
    {instance_id ""}
} {
    Returns page_id mapped to the url mapped to template_id, else returns empty string.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set page_id ""
    db_0or1row wiki_page_get_url_from_template_id { select page_id from qw_page_url_map 
        where instance_id = :instance_id and page_id in ( select id as page_id from qw_wiki_page 
                                                          where instance_id = :instance_id and template_id = :template_id ) }
    return $page_id
}


ad_proc -public qw_page_from_url { 
    page_url
    {instance_id ""}
} {
    Returns page_id if page is published (untrashed) for instance_id, else returns empty string.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set page_exists_p [db_0or1row wiki_page_get_id_from_url2 {select page_id from qw_page_url_map 
        where url = :page_url and instance_id = :instance_id and not ( trashed = '1' ) } ]
    if { !$page_exists_p } {
        set page_id ""
    }
    return $page_id
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
                    set page_id = :page_id where url = :url and instance_id = :instance_id }
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
        # convert trash null/empty value to logical 0
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
    Returns a list of q-wiki page_ids. If template_id is included, the results are scoped to pages with same template (aka revisions).
    If user_id is included, the results are scoped to the user. If nothing found, returns and empty list.
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
                # get a list of page_ids that are mapped to a url for instance_id and where the current revision was created by user_id
                set return_list [db_list wiki_pages_user_list { select id from qw_wiki_page where instance_id = :instance_id and user_id = :user_id and id in ( select page_id from qw_page_url_map where instance_id = :instance_id ) order by last_modified desc } ]
            } else {
                # get a list of all page_ids mapped to a url for instance_id.
                set return_list [db_list wiki_pages_list { select id as page_id from qw_wiki_page where id in ( select page_id from qw_page_url_map where instance_id = :instance_id ) order by last_modified desc } ]
            }
        } else {
            # is the template_id valid?
            set has_template [db_0or1row wiki_page_template { select template_id as db_template_id from qw_wiki_page where template_id= :template_id limit 1 } ]
            if { $has_template && [info exists db_template_id] && $template_id > 0 } {
                if { $user_id ne "" } {
                    # get a list of all page_ids of the revisions of page (template_id) that user_id created.
                    set return_list [db_list wiki_pages_t_u_list { select id from qw_wiki_page where instance_id = :instance_id and user_id = :user_id and template_id = :template_id order by last_modified desc } ]
                } else {
                    # get a list of all page_ids of the revisions of page (template_id) 
                    set return_list [db_list wiki_pages_list { select id from qw_wiki_page where instance_id = :instance_id and template_id = :template_id order by last_modified } ]
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
    Returns page contents of page_id. Returns page as list of attribute values: name, title, keywords, description, template_id, flags, trashed, popularity, last_modified, created, user_id, content, comments
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
        # convert trash null/empty value to logical 0
        if { [llength $return_list] > 1 && [lindex $return_list 6] eq "" } {
            set return_list [lreplace $return_list 6 6 0]
        }

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
    Writes a new revision of an existing q-wiki page. page_id is an existing revision of template_id. returns the new page_id or a blank page_id if unsuccessful.
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
    set new_page_id ""

    if { $write_p } {
        set page_exists_p [db_0or1row wiki_page_get_user_id {select user_id as creator_id from qw_wiki_page where id = :page_id } ]
        if { $page_exists_p } { 
            set page_id_stats_list [qw_page_stats $page_id $instance_id $user_id]
            set template_id [lindex $page_id_stats_list 5]
        }

        if { $page_exists_p } {
            set old_page_id $page_id
            set url qw_page_url_from_id $old_page_id
            set new_page_id [db_nextval qw_page_id_seq]
            ns_log Notice "qw_page_write: wiki_page_create id '$page_id' template_id '$template_id' name '$name' instance_id '$instance_id' user_id '$user_id'"
            db_transaction {
                db_dml wiki_page_create { insert into qw_wiki_page
                    (id,template_id,name,title,keywords,description,content,comments,instance_id,user_id, last_modified, created)
                    values (:new_page_id,:template_id,:name,:title,:keywords,:description,:content,:comments,:instance_id,:user_id, current_timestamp, current_timestamp) }
                ns_log Notice "qw_page_write: wiki_page_id_update page_id '$new_page_id' instance_id '$instance_id' old_page_id '$old_page_id'"
                db_dml wiki_page_id_update { update qw_page_url_map
                    set page_id = :new_page_id where instance_id = :instance_id and url = :url }
            } on_error {
                set success_p 0
                ns_log Error "qw_page_write: general db error during db_dml"
            }
        } else {
            set success_p 0
            ns_log Warning "qw_page_write: no page exists for page_id $page_id"
        }
        set success_p 1
    } else {
        set success_p 0
    }
    return $new_page_id
}


ad_proc -public qw_page_delete {
    {page_id ""}
    {template_id ""}
    {instance_id ""}
    {user_id ""}
} {
    Deletes all revisions of template_id if not null, or if page_id not null, deletes page_id.
    Returns 1 if deleted. Returns 0 if there were any issues.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
    }
    set delete_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege delete]
    set success_p 0
    set page_id_active_p 0
    ns_log Notice "qw_page_delete: delete_p '$delete_p' page_id '$page_id' template_id '$template_id'"
    if { $delete_p } {
        
        if { $page_id ne "" } {
            set template_id [lindex [qw_page_stats $page_id $instance_id] 5]
            # delete a revision
            db_dml wiki_page_delete { delete from qw_wiki_page 
                where id=:page_id and instance_id =:instance_id and trashed = '1' }
            # is page_id the active revision for template_id?
            set page_id_active_p [db_0or1row qw_url_from_page_id { select url from qw_page_url_map 
                where page_id = :page_id and instance_id = :instance_id } ]
        } elseif { $template_id ne "" } {
            # delete all revisions of template_id and the url_mapped to it
            # get active page_id for reference later
            set page_id [qw_page_url_id_from_template_id $template_id $instance_id]
            # delete all revisions
            db_dml wiki_template_delete { delete from qw_wiki_page 
                where template_id=:template_id and instance_id =:instance_id and trashed = '1' }
            set page_id_active_p 1
        }

    } else {

        # a user can only delete their own creations
        if { $page_id ne "" } {
            set template_id [lindex [qw_page_stats $page_id $instance_id] 5]
            # delete a revision
            db_dml wiki_page_delete_u { delete from qw_wiki_page 
                where id=:page_id and instance_id =:instance_id and user_id=:user_id and trashed = '1' }
            # is page_id the active revision for template_id?
            set page_id_active_p [db_0or1row qw_url_from_page_id { select url from qw_page_url_map 
                where page_id = :page_id and instance_id = :instance_id } ]
            set success_p 1
        } elseif { $template_id ne "" } {
            # delete all revisions of template_id and the url_mapped to it
            # get active page_id for reference later
            set page_id [qw_page_url_id_from_template_id $template_id $instance_id]
            # delete all revisions
            db_dml wiki_template_delete_u { delete from qw_wiki_page 
                where template_id=:template_id and instance_id =:instance_id and user_id = :user_id and trashed = '1' }
            set page_id_active_p 1
        }
        
    }

    if { $page_id_active_p } {
        # change the page_id mapped to the url, or delete it if no alternates exist
        # find the most recent untrashed revision
        set new_untrashed_id_exists_p [db_0or1row qw_previous_page_id { select id as new_page_id from qw_wiki_page 
            where template_id = :template_id and instance_id = :instance_id and not ( trashed = '1') and not ( id = :page_id ) order by created desc limit 1 } ]
        if { $new_untrashed_id_exists_p } {
            #  point to the most recent untrashed revision
            db_dml wiki_page_id_update { update qw_page_url_map set page_id = :new_page_id 
                where instance_id = :instance_id and page_id = :page_id }
        } else {
            # point to the most recent trashed revision, and trash the mapped url status for consistency
            set new_trashed_id_exists_p [db_0or1row qw_previous_page_id2 { select id as new_page_id from qw_wiki_page 
                where template_id = :template_id and instance_id = :instance_id and not ( id = :page_id ) order by created desc limit 1 } ]
            if { $new_trashed_id_exists_p } {
                db_dml wiki_page_id_update_trashed { update qw_page_url_map
                    set page_id = :new_page_id, trashed = '1'
                    where instance_id = :instance_id and page_id = :page_id }
            } else {
                # the revision being deleted is the last revision, delete the mapped url entry
                set url [qw_page_url_from_id $template_id]
                db_dml wiki_page_url_delete { delete from qw_page_url_map
                    where url =:url and instance_id =:instance_id }
            }
        }
    }
    return 1
}



ad_proc -public qw_page_trash {
    {page_id ""}
    {trash_p "1"}
    {template_id ""}
    {instance_id ""}
    {user_id ""}
} {
    Trashes/untrashes page_id or template_id (subject to permission check).
    set trash_p to 1 (default) to trash page. Set trash_p to '0' to untrash. 
    Returns 1 if successful, otherwise returns 0
} {
    # page_id can be unpublished revision or the published revision, trashed or untrashed
    set url ""

    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
        set untrusted_user_id [ad_conn untrusted_user_id]
    }
    set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]
    set page_id_active_p 0

    # if write_p, don't need to scope to user_id == page_user_id
    if { $write_p } {

        if { $page_id ne "" } {
            # trash revision
            set template_id [lindex [qw_page_stats $page_id $instance_id] 5]
            set url [qw_page_url_from_id $template_id]
            # wtr = write privilege trash revision
            db_dml wiki_page_trash_wtr { update qw_wiki_page set trashed =:trash_p, last_modified = current_timestamp
                where id=:page_id and instance_id =:instance_id }
            # is page_id associated with a url ie published?
            set page_id_active_p [db_0or1row qw_url_from_page_id { select url from qw_page_url_map 
                where page_id = :page_id and instance_id = :instance_id } ]

        } elseif { $template_id ne "" } {
            set url [qw_page_url_from_id $template_id]
            # template_id affects all revisions. 
            # page_id is blank. set page_id to page url's page_id
            set page_id [qw_page_id_from_url $url]
            # wtp = write privilege trash page ie bulk trashing revisions
            db_dml wiki_page_trash_wtp { update qw_wiki_page set trashed =:trash_p, last_modified = current_timestamp
                where template_id=:template_id and instance_id =:instance_id }
            set page_id_trash_p 1
        }

    } else {

        # a user can only un/trash their own entries
        # the user_id scope is applied in the query
        if { $page_id ne "" } {
            # trash one revision
            set template_id [lindex [qw_page_stats $page_id $instance_id] 5]            
            set url [qw_page_url_from_id $template_id]
            # utr = user privilege trash revision
            db_dml wiki_page_trash_utr { update qw_wiki_page set trashed =:trash_p, last_modified = current_timestamp
                where id=:page_id and instance_id =:instance_id and user_id=:user_id }
            # is page_id associated with a url ie published?
            set page_id_active_p [db_0or1row qw_url_from_page_id { select url from qw_page_url_map 
                where page_id = :page_id and instance_id = :instance_id } ]
            
        } elseif { $template_id ne "" 0 } {
            # trash for all revisions possible for same template_id
            set url [qw_page_url_from_id $template_id]
            set page_id [qw_page_id_from_url $url]
            
            # utp = user privilege trash page (as many revisions as they created)
            db_dml wiki_page_trash_utp { update qw_wiki_page set trashed =:trash_p, last_modified = current_timestamp
                where template_id=:template_id and instance_id =:instance_id and user_id=:user_id }            
            set page_id_active_p 1
        }
        
    }

#    ns_log Notice "qw_page_trash: page_id_active_p '$page_id_active_p' trash_p '$trash_p'"

    if { $page_id_active_p && $trash_p } {
        #  need to choose an alternate page_id if available, since this page_id is trashed
        ns_log Notice "qw_page_trash(529). need to change page_id"
        # page_id is old_page_id  
        # select most recent, available new_page_id
        set new_page_id_exists [db_0or1row qw_available_page_id { select id as new_page_id from qw_wiki_page 
            where template_id = :template_id and instance_id = :instance_id and not (trashed = '1') and not ( id =:page_id ) order by created desc limit 1 } ]
        if { $new_page_id_exists } {
            ns_log Notice "qw_page_trash(583): new_page_id $new_page_id"
            #  point to the most recent untrashed revision
            if { $page_id ne $new_page_id } {
                ns_log Notice "qw_page_trash: changing active page_id from $page_id to $new_page_id"
                db_dml wiki_page_url_id_update { update qw_page_url_map set page_id = :new_page_id 
                    where instance_id = :instance_id and page_id = :page_id }
                # we avoided having to update trashed status for url_map
                set $page_id_active_p 0
            }
        } 
    }

    if { !$trash_p } {
        # if page_id of url_map is trashed, untrash it.

        db_0or1row qw_page_url_trashed_p { select trashed as url_trashed_p from qw_page_url_map
            where url = :url and instance_id = :instance_id }
        set url_trashed_p_exists_p [info exists url_trashed_p]
        if { !$url_trashed_p_exists_p || ( $url_trashed_p_exists_p && $url_trashed_p ne "1" ) } {
            set url_trashed_p 0
        }
        if { $url_trashed_p } {
            set url_page_id [qw_page_id_from_url $url $instance_id]
 #           ns_log Notice "qw_page_trash(603): updating trash and page_id '$url_page_id' for url '$url' to page_id '$page_id' untrashed"
            db_dml wiki_page_url_map_update2 { update qw_page_url_map set page_id = :page_id, trashed = :trash_p
                    where instance_id = :instance_id and page_id = :url_page_id }
            set page_id_active_p 0
        }
        # untrash the url
    }

    # if page_id active or untrashing page_id and page_url trashed
    if { $page_id_active_p } {
        # published page_id is affected, set mapped page trash also.
        ns_log Notice "qw_page_trash: updating qw_page_url_map page_id '$page_id' instance_id '$instance_id'"
        db_dml wiki_page_url_trash_update { update qw_page_url_map set trashed = :trash_p 
            where page_id = :page_id and instance_id = :instance_id }
    }
    return 1
}
