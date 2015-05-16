ad_library {

    API for q-wiki templates 
    @creation-date 17 Jul 2012
    @Copyright (c) 2012-5 Benjamin Brink
    @license GNU General Public License 3, see project home or http://www.gnu.org/licenses/gpl-3.0.en.html
    @project home: http://github.com/tekbasse/q-wiki
    @address: po box 20, Marylhurst, OR 97036-0020 usa
    @email: tekbasse@yahoo.com
}

ad_proc -public qw_template_custom_read {
    report_ref
    default_fields
    {instance_id ""}
    {user_id ""}
} {
    This procedure returns a custom order for use with templates, where a template contains ordered references, 
    $1 .. $9. By supplying a custom order of fields for a report, admins (and possibly users) can control the
    order of fields displayed in a table or responsive list substitute for an html TABLE.
    The default is to return default_fields in the sequence passed to this proc. Limit length of space separated list: 320 characters.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set custom_fields $default_fields
    set report_ref [string range $report_ref 0 79]
    if { [qf_is_natural_number $user_id] } {
        set possible_lists [db_list_of_lists qw_template_custom_map_read_w_u "select custom_order, user_id from qw_template_custom_map where instance_id =:instance_id and report_ref=:report_ref and default_fields =:default_fields and ( user_id =:user_id or user_id is null)"]
        # There should be only 2 possibilities max
        if { [llength $possible_lists > 1 ] } {
            # choose the one with the user_id
            foreach row_list $possible_lists {
                if { [lindex $row_list 1] eq $user_id } {
                    set custom_fields [lindex $row_list 0]
                }
            }
        } else {
            set custom_fields [lindex $possible_lists 0]
        }
    } else {
        # defaults to use custom_fields from above if no rows found
        db_0or1row qw_template_custom_map_read "select custom_order as custom_fields from qw_template_custom_map where instance_id =:instance_id and report_ref=:report_ref and default_fields =:default_fields and user_id is null"
    }
    return $custom_fields
}

ad_proc -public qw_template_custom_set {
    report_ref
    default_fields
    custom_fields
    {instance_id ""}
    {user_id ""}
} {
    This procedure sets a custom order for use with templates, where a template contains ordered references, 
    $1 .. $9. By supplying a custom order of fields for a report, admins (and possibly users) can control the
    order of fields displayed in a table or responsive list substitute for an html TABLE.
     Limit length of space separated list: 320 characters.
} {
    if { $instance_id eq "" } {
        # set instance_id package_id
        set instance_id [ad_conn package_id]
    }
    set success_p 1
    # get current custom (if any) to see if a write is necessary
    set custom_fields_old [qw_template_custom_read $report_ref $default_fields $instance_id $user_id]
    if { $custom_fields_old ne $custom_fields } {
        # update or create it
        set report_ref [string range $report_ref 0 79]
        if { $user_id eq "" } {
            # set for all cases
            db_0or1row qw_template_custom_map_all_ck "select custom_order as custom_order_old2 from qw_template_custom_map where instance_id =:instance_id and report_ref=:report_ref and default_fields =:default_fields and user_id is null"
            if { [info exists custom_order_old2] } {
                # record exists. 
                if { $custom_order_old2 ne $custom_fields } {
                    # update record
                    db_dml { update qw_template_custom_map 
                        set custom_order =:custom_fields where instance_id=:instance_id and report_ref=:report_ref and default_fields=:default_fields and  user_id is null
                    }
                }
            } else {
                # create record
                db_dml { insert into qw_template_custom_map 
                    (custom_fields,instance_id,report_ref,default_fields)
                    values (:custom_order,:instance_id,:report_ref,:default_fields)
                }
            }
        } elseif { [qf_is_natural_number $user_id] } {
            # set for this user
            db_0or1row qw_template_custom_map_all_ck "select custom_order as custom_order_old2 from qw_template_custom_map where instance_id =:instance_id and report_ref=:report_ref and default_fields =:default_fields and user_id =:user_id"
            if { [info exists custom_order_old2] } {
                # record exists. 
                if { $custom_order_old2 ne $custom_fields } {
                    # update record
                    db_dml { update qw_template_custom_map 
                        set custom_order =:custom_fields where instance_id=:instance_id and report_ref=:report_ref and default_fields=:default_fields and  user_id =:user_id
                    }
                }
            } else {
                # create record
                db_dml { insert into qw_template_custom_map 
                    (custom_fields,instance_id,report_ref,default_fields,:user_id)
                    values (:custom_order,:instance_id,:report_ref,:default_fields,:user_id)
                }
            }
        } else {
            set success_p 0
        }
    }
    return $success_p 
}
