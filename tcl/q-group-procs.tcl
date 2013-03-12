ad_library {

    q-wiki user collaboration and contribution procedures
    @creation-date 11 Mar 2013
    @cs-id $Id:
}

# contributors of a page or instance (by most recent contributions, or user last_name)
# most_recent_edit (by and time)
# revisions contributed by a user? --not necessary, use page revisions
# pages with contributions by a user (a user's most recent contributions)

ad_proc -public qw_contributors { 
    {template_id ""}
    {instance_id ""}
} {
    Returns list of contributors of template_id or instance_id
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $template_id ne "" } {
        set rev_user_ids_list [db_list_of_lists qw_pg_contributor_user_ids { select user_id from qw_wiki_page where template_id = :template_id and instance_id =:instance_id order by last_modified desc } ]
    } else {
        set rev_user_ids_list [db_list_of_lists qw_contributor_user_ids { select user_id from qw_wiki_page where instance_id =:instance_id order by last_modified desc } ]
    }
    set user_id_list [list ]
    foreach rev_user_id_list $rev_user_ids_list {
        set user_id [lindex $rev_user_id_list 0]
        if { [lsearch -exact $user_id_list $user_id] == -1 } {
            lappend user_id_list $user_id
        }
    }
    return $user_id_list
}

ad_proc -public qw_most_recent_edit_stats {
    {template_id ""}
    {instance_id ""}
} {
    Returns user_id, last_modified and page_id (revision) as list for most recent edit of template_id or instance_id
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $template_id ne "" } {
        set rev_exists_p [db_0or1row qw_most_recent_template_edits { select user_id, last_modified, id as page_id from qw_wiki_page where template_id = :template_id and instance_id = :instance_id order by last_modified desc limit 1 } ]
    } else {
        set  rev_exists_p [db_0or1row qw_most_recent_instance_edits { select user_id, last_modified, id as page_id from qw_wiki_page where instance_id = :instance_id order by last_modified desc limit 1 } ]
    }
    if { $rev_exists_p } {
        set stats_list [list $user_id $last_modified $page_id]
    } else {
        set stats_list [list ]
    }
    return $stats_list
}

ad_proc -public qw_user_contributions {
    {user_id ""}
    {instance_id ""}
} {
    Returns page_ids that user has contributed revisions (not necessarily current revisions)
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
    }
    set page_ids_list [db_list_of_lists qw_contributor_page_ids { select id from qw_wiki_page where instance_id =:instance_id order by last_modified desc } ]    

    return $page_ids_list
}
