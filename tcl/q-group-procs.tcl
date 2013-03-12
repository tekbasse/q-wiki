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
    

    return $user_id_list
}

ad_proc -public qw_most_recent_edit_stats {
    {template_id ""}
    {instance_id ""}
} {
    Returns user_id and last_modified for most recent edit of template_id or instance_id
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    
    set page_exists_p [db_0or1row wiki_page_get_id {select name from qw_wiki_page where id = :page_id and instance_id = :instance_id } ]
    return $page_exists_p
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
    
    set page_exists_p [db_0or1row wiki_page_get_id {select name from qw_wiki_page where id = :page_id and instance_id = :instance_id } ]
    return $page_exists_p



}
