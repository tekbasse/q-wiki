# q-wiki/q-wiki.tcl
# this page split into MVC components:
#  inputs (controller), actions (model), and outputs (view) sections

# INPUTS / CONTROLLER
# set defaults
# template_id is first page_id, subsequent revisions have same template_id, but new page_id
# flags are blank -- an unused db column / page attribute for extending the app for use cases
# url has to be a given (not validated), since this page may be fed $url via an index.vuh

set title "Q-Wiki"

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set write_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege write]
set admin_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege admin]
set delete_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege delete]

array set input_array [list \
                           url ""\
                           page_id ""\
                           page_name ""\
                           page_title ""\
                           page_contents ""\
                           keywords ""\
                           description ""\
                           page_comments ""\
                           page_template_id ""\
                           page_flags ""\
                           page_contents_default ""\
                           submit "" \
                           reset "" \
                           mode "v" \
                           next_mode "" \
                          ]

set user_message_list [list ]


# get previous form inputs if they exist
set form_posted [qf_get_inputs_as_array input_array]

set url $input_array(url)
# page_template_id and page_id gets checked against db for added security
set page_id $input_array(page_id)
set page_template_id $input_array(page_template_id)

set page_name $input_array(page_name)
set page_title $input_array(page_title)
set page_flags $input_array(page_flags)
set keywords $input_array(keywords)
set description $input_array(description)
set page_comments $input_array(page_comments)
set page_contents $input_array(page_contents)
set mode $input_array(mode)
set next_mode $input_array(next_mode)

if { $form_posted } {
    if { [info exists input_array(x) ] } {
        unset input_array(x)
    }
    if { [info exists input_array(y) ] } {
        unset input_array(y)
    }
    if { ![qf_is_natural_number $page_id] } {
        set page_id ""
    }

    set validated 0
    # validate input
    # cleanse data, verify values for consistency
    # determine input completeness

    # Modes
    # d = delete (template_id or page_id) then view as list
    # e = edit template_id (current page_id of template_id) (follows with w, perhaps preceeds also)
    # l = list of pages (current page_ids of instance_id)
    # n = create page (existing or new template_id, if edit has no page, it is new) ie w then v
    # r = revisions list of page (page_ids with same template_id)
    # t = trash (template_id or page_id)
    # v = view page_id (of template_id, defaults to current page_id of template_id)
    # w = write page_id of template_id, make page_id current for template_id, then view page_id (v)

    # url has to come from form in order to pass info via index.vuh
    # set conn_package_url [ad_conn package_url]
    # set page_url [string range $url [string length $conn_package_url] end]
    # get page_id from url, if any
    set page_id_from_url [qw_page_id_from_url $page_url $package_id]

    if { $page_id_from_url ne "" } {
        # page exists
        set page_stats_list [qw_page_stats $page_id $package_id $user_id]
        set page_template_id_from_db [lindex $page_stats_list 5]

        # check for form/db descrepencies
        if { $page_id ne "" && $page_id ne $page_id_from_url } {
            set  mode v
            set next_mode ""
            ns_log Notice "q-wiki/q-wiki.tcl page_id '$page_id' ne page_id_from_url '$page_id_from_url' "
            set user_message_list "There has been an internal processing error. Try again or report to [ad_admin_owner]"
        }
        if { $page_template_id ne "" && $page_template_id ne $page_template_id_from_db } {
            set mode v
            set next_mode ""
            ns_log Notice "q-wiki/q-wiki.tcl page_template_id '${page_template_id}' ne page_template_id_from_db '${page_template_id_from_db}'"
            set user_message_list "There has been an internal processing error. Try again or report to [ad_admin_owner]"
        }

        # get info to pass back to write proc

        # This is a place to enforce application specific permissions.
        # If package parameter says each template_id is an object_id, 
        # check user_id against object_id, otherwise check against package_id
        # However, original_page_creation_user_id is in the db, so that instance specific
        # user permissions can be supported.
        # set original_user_id \[lindex $page_stats_list_of_template_id 11\]
    }
    # validate input values for specific modes
    switch -exact -- $mode {
        d {
            if { [qw_page_id_exists $page_id $package_id] } {
                ns_log Notice "q-wiki.tcl validated for d"
                set validated 1
            } else {
                set mode "l"
                set next_mode ""
            } 
        }
        l {
            set validated 1
            ns_log Notice "q-wiki.tcl validated for l"
        }
        r {
            if { [qw_page_id_exists $page_id $package_id] } {
                set validated 1
                ns_log Notice "q-wiki.tcl validated for r"
            } else {
                set mode "l"
                set next_mode ""
            }
        }
        t {
            if { [qw_page_id_exists $page_id $package_id] } {
                set validated 1
                ns_log Notice "q-wiki.tcl validated for t"
            } else {
                set mode "l"
                set next_mode ""
            } 
        }
        e {
            # validate for new and existing pages. 
            # For new pages, template_id will be blank.
            # For revisions, page_id will be blank.

            # page_title cannot be blank
            if { $page_title eq "" && $template_id eq "" } {
                set page_title "[clock format [clock seconds] -format %Y%m%d-%X]"
            } elseif { $page_title eq "" } {
                set page_title "${template_id}"
            } else {
                set page_title_length [parameter::get -package_id $package_id -parameter PageTitleLen -default 80]
                incr page_title_length -1
                set page_title [string range $page_title 0 $page_title_length]
            }

            if { $template_id eq "" } {
                # this is a new page
                set page_url [ad_urlencode $page_name]
                set page_id ""
            } else {
                # Want to enforce unchangeable urls for pages?
                # If so, set url from db for template_id here.
            }

            # page_name is pretty version of url, cannot be blank
            if { $page_name eq "" } {
                set page_name $url
            } else {
                set page_name_length [parameter::get -package_id $package_id -parameter PageNameLen -default 40]
                incr page_name_length -1
                set page_name [string range $page_name 0 $page_name_length]
            }

            set validated 1
            if { $mode eq "n" } {
                set mode w
            }
            ns_log Notice "q-wiki.tcl validated for $mode"
        }
        default {
            if { [qw_page_id_exists $page_id $package_id] } {
                ns_log Notice "q-wiki.tcl validated for default"
                set validated 1
                set mode "v"
            } else {
                set mode "l"
                set next_mode ""
            } 
        }
    }
    #^ end switch

# ACTIONS, PROCESSES / MODEL
    if { $validated } {
        # execute process using validated input
        # IF is used instead of SWITCH, so multiple sub-modes can be processed as a single mode.
        if { $mode eq "d" } {
            #  delete.... removes context     
            ns_log Notice "q-wiki.tcl mode = delete"
            if { [qf_is_natural_number $page_id] } {
                qw_page_delete $page_id
            }
            set mode $next_mode
            set next_mode ""
        }
        if { $mode eq "t" } {
            #  trash
            ns_log Notice "q-wiki.tcl mode = trash"
            if { [qf_is_natural_number $page_id] && $write_p } {
                set trashed_p [lindex [qw_page_stats $page_id] 7]
                if { $trashed_p == 1 } {
                    set trash 0
                } else {
                    set trash 1
                }
                qw_page_trash $trash $page_id
            }
            set mode "p"
            set next_mode ""
        }
        if { $mode eq "w" } {
            set allow_adp_tcl_p [parameter::get -package_id $package_id -parameter AllowADPTCL -default 0]
            set flagged_list [list ]
            if { $allow_adp_tcl_p } {
                # screen page_contents before write
                set banned_proc_list [split [parameter::get -package_id $package_id -parameter BannedProc]]
                set allowed_proc_list [split [parameter::get -package_id $package_id -parameter AllowedProc]]

                set code_block_list [qf_tag_contents_list '<%' '%>' $page_contents]
                foreach code_block $code_block_list {
                    set code_segments_list [qf_tcl_code_parse_lines_list $code_block]
                    foreach code_segment $code_segments_list  {
                        # see filters in accounts-finance/tcl/modeling-procs.tcl
                        set executable_fragment_list [split $code_segment "["]
                        set executable_list [list ]
                        foreach executable_fragment $executable_fragment_list {
                            # clip it to just the executable for screening purposes
                            set space_idx [string first " " $executable_fragment]
                            if { $space_idx > -1 } {
                                set end_idx [expr { $space_idx - 1 } ]
                                set executable [string range $executable_fragment 0 $end_idx]
                            } else {
                                set executable $executable_fragment
                            }
                            # screen executable
                            if { [lsearch -glob $allowed_proc_list] > -1 } {
                                foreach banned_proc $banned_proc_list {
                                    set banned_proc_exp {[^a-z0-9_]}
                                    append banned_proc_exp $banned_proc
                                    append banned_proc_exp {[^a-z0-9_]}
                                    if { [regexp $banned_proc_exp " $executable " scratch] } {
                                        # banned executable found
                                        lappend flagged_list $executable
                                        lappend user_message_list "'$executable' is not allowed."
                                    }
                                }            
                            } else {
                                lappend flagged_list $executable
                                lappend user_message_list "'$executable' is not allowed."
                            }
                        }
                    }
                }
                if { [llength $flagged_list] == 0 } {
                    # content passed filters
                    set page_contents_filtered $page_contents
                } else {
                    set page_contents_filtered ""
                }
            } else {
                set page_contents_list [qf_remove_tag_contents '<%' '%>' $page_contents]
                set page_contents_filtered ""
                foreach page_segment $page_contents_list {
                    append page_contents_filtered $page_segment
                }
            }
            # use page_contents_filtered, was $page_contents
            set page_contents $page_contents_filtered
            
            if { [llength $flagged_list ] > 0 } {
                set mode e
            } else {
                # write the data
                # a different user_id makes new context based on current context, otherwise modifies same context
                # or create a new context if no context provided.
                # given:
                
                # create or write page
                if { $page_id eq "" } {
                    # create page
                    set page_id [qw_page_create $page_url $page_name $page_title $page_contents_filtered $keywords $description $page_comments $page_template_id $page_flags $package_id $user_id]
                    if { $page_id == 0 } {
                        ns_log Warning "q-wiki/q-wiki.tcl page write error for page_url '${page_url}'"
                        lappend user_messag_list "There was an error creating the wiki page at '${page_url}'."
                    }
                } else {
                    # write page
                    set success_p [qw_page_write $page_name $page_title $page_contents_filtered $keywords $description $page_comments $page_id $page_template_id $page_flags $package_id $user_id]
                    if { $success_p == 0 } {
                        ns_log Warning "q-wiki/q-wiki.tcl page write error for page_url '${page_url}'"
                        lappend user_messag_list "There was an error creating the wiki page at '${page_url}'."
                    }
                }
                # switch modes..
                
                set mode $next_mode
                set next_mode ""
            }
        }
    }
}


set menu_list [list [list Q-Wiki index]]
if { $write_p } {
    lappend menu_list [list new ?mode=n]
}

# OUTPUT / VIEW
switch -exact -- $mode {
    e {
        #  edit...... edit/form mode of current context
        ns_log Notice "q-wiki.tcl mode = edit"
        append title " edit"
        #requires page_id
        
        # get table from ID
        
        
        qf_form action q-wiki/index method get id 20120721
        qf_input type hidden value n name mode label ""
        
        if { [qf_is_natural_number $page_id] } {
            set page_stats_list [qw_page_stats $page_id]
            set page_name [lindex $page_stats_list 0]
            set page_title [lindex $page_stats_list 1]
            set page_comments [lindex $page_stats_list 2]
            set page_flags [lindex $page_stats_list 6]
            set page_template_id [lindex $page_stats_list 5]
            
            set page_lists [qss_page_read $page_id]
            set page_contents [qss_lists_to_text $page_lists]
            
            qf_input type hidden value $page_id name page_id label ""
            qf_input type hidden value $page_flags name page_flags label ""
            qf_input type hidden value $page_template_id name page_template_id label ""
            qf_append html "<h3>Q-Wiki page edit</h3>"
            qf_append html "<div style=\"width: 70%; text-align: right;\">"
            qf_input type text value $page_name name page_name label "Name:" size 40 maxlength 40
            qf_append html "<br>"
            qf_input type text value $page_title name page_title label "Title:" size 40 maxlength 80
            qf_append html "<br>"
            qf_textarea value $page_comments cols 40 rows 3 name page_comments label "Comments:"
            qf_append html "<br>"
            qf_textarea value $page_contents cols 40 rows 6 name page_contents label "Contents:"
            qf_append html "</div>"
        }
        
        qf_input type submit value "Save"
        qf_close
        set form_html [qf_read]
        
    }
    l {
        #  list...... presents a list of pages
        ns_log Notice "q-wiki.tcl mode = $mode ie. list of pages, index"
        append title " index" 
        # show page
        # sort by template_id, columns
        
        set page_ids_list [qw_pages $package_id]
        set page_stats_lists [list ]
        set page_trashed_lists [list ]
        set cell_formating_list [list ]
        set tables_stats_lists [list ]
        # we get the entire list, to sort it before processing
        foreach page_id $page_ids_list {
            
            set stats_mod_list [list $page_id]
            set stats_orig_list [qw_page_stats $page_id]
            foreach stat $stats_orig_list {
                lappend stats_mod_list $stat
            }
            # qw_stats:  name, title, keywords,description, template_id, flags, trashed, popularity, time last_modified, time created, user_id.
            # new: page_id, name, title, comments, keywords, description, template_id, flags, trashed, popularity, time last_modified, time created, user_id 
            lappend tables_stats_lists $stats_mod_list
        }
        set tables_stats_lists [lsort -index 6 -real $tables_stats_lists]
        set delete_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege delete]
        foreach stats_orig_list $tables_stats_lists {
            set stats_list [lrange $stats_orig_list 0 4]
            set page_id [lindex $stats_list 0]
            set name [lindex $stats_list 1]
            set template_id [lindex $stats_orig_list 6]
            set page_user_id [lindex $stats_orig_list 12]
            set trashed_p [lindex $stats_orig_list 8]
            
            # convert table row for use with html
            # change name to an active link
            set active_link "<a\ href=\"q-wiki?$p=${page_id}\">$name</a>"
            
            if { ( $admin_p || $page_user_id == $user_id ) && $trashed_p == 1 } {
                set trash_label "untrash"
                append active_link " \[<a href=\"q-wiki?p=${page_id}&mode=t\">${trash_label}</a>\]"
            } elseif { $page_user_id == $user_id || $admin_p } {
                set trash_label "trash"
                append active_link " \[<a href=\"q-wiki?$p=${page_id}&mode=t\">${trash_label}</a>\]"
            } 
            if { $delete_p } {
                append active_link " \[<a href=\"q-wiki?p=${page_id}&mode=d\">delete</a>\]"
            } 
            set stats_list [lreplace $stats_list 0 1 $active_link]
            if { $trashed_p == 1 } {
                lappend page_trashed_lists $stats_list
            } else {
                lappend page_stats_lists $stats_list
            }
            
        }
        # sort for now. Later, just get page_tables with same template_id
        set page_stats_sorted_lists $page_stats_lists
        set page_stats_sorted_lists [linsert $page_stats_sorted_lists 0 [list Name Title Comments] ]
        set page_tag_atts_list [list border 1 cellspacing 0 cellpadding 3]
        set page_stats_html [qss_list_of_lists_to_html_table $page_stats_sorted_lists $page_tag_atts_list $cell_formating_list]
        # trashed
        if { [llength $page_trashed_lists] > 0 && $write_p } {
            set page_trashed_sorted_lists $page_trashed_lists
            set page_trashed_sorted_lists [linsert $page_trashed_sorted_lists 0 [list Name Title Comments] ]
            set page_tag_atts_list [list border 1 cellspacing 0 cellpadding 3]
            
            set page_trashed_html "<h3>Trashed tables</h3>\n"
            append page_trashed_html [qss_list_of_lists_to_html_table $page_trashed_sorted_lists $page_tag_atts_list $cell_formating_list]
            append page_stats_html $page_trashed_html
        }
    }
    r {
        #  revisions...... presents a list of page revisions
        ns_log Notice "q-wiki.tcl mode = $mode ie. revisions"
        
        
        # show page
        # sort by template_id, columns
        
        set page_ids_list [qw_pages $package_id]
        set page_stats_lists [list ]
        set page_trashed_lists [list ]
        set cell_formating_list [list ]
        set tables_stats_lists [list ]
        # we get the entire list, to sort it before processing
        foreach page_id $page_ids_list {
            
            set stats_mod_list [list $page_id]
            set stats_orig_list [qw_page_stats $page_id]
            foreach stat $stats_orig_list {
                lappend stats_mod_list $stat
            }
            # qw_stats:  name, title, keywords,description, template_id, flags, trashed, popularity, time last_modified, time created, user_id.
            # new: page_id, name, title, comments, keywords, description, template_id, flags, trashed, popularity, time last_modified, time created, user_id 
            lappend tables_stats_lists $stats_mod_list
        }
        set tables_stats_lists [lsort -index 6 -real $tables_stats_lists]
        set delete_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege delete]
        foreach stats_orig_list $tables_stats_lists {
            set stats_list [lrange $stats_orig_list 0 4]
            set page_id [lindex $stats_list 0]
            set name [lindex $stats_list 1]
            set template_id [lindex $stats_orig_list 6]
            set page_user_id [lindex $stats_orig_list 12]
            set trashed_p [lindex $stats_orig_list 8]
            
            # convert table row for use with html
            # change name to an active link
            set active_link "<a\ href=\"q-wiki?$p=${page_id}\">$name</a>"
            
            if { ( $admin_p || $page_user_id == $user_id ) && $trashed_p == 1 } {
                set trash_label "untrash"
                append active_link " \[<a href=\"q-wiki?p=${page_id}&mode=t\">${trash_label}</a>\]"
            } elseif { $page_user_id == $user_id || $admin_p } {
                set trash_label "trash"
                append active_link " \[<a href=\"q-wiki?$p=${page_id}&mode=t\">${trash_label}</a>\]"
            } 
            if { $delete_p } {
                append active_link " \[<a href=\"q-wiki?p=${page_id}&mode=d\">delete</a>\]"
            } 
            set stats_list [lreplace $stats_list 0 1 $active_link]
            if { $trashed_p == 1 } {
                lappend page_trashed_lists $stats_list
            } else {
                lappend page_stats_lists $stats_list
            }
            
        }
        # sort for now. Later, just get page_tables with same template_id
        set page_stats_sorted_lists $page_stats_lists
        set page_stats_sorted_lists [linsert $page_stats_sorted_lists 0 [list Name Title Comments] ]
        set page_tag_atts_list [list border 1 cellspacing 0 cellpadding 3]
        set page_stats_html [qss_list_of_lists_to_html_table $page_stats_sorted_lists $page_tag_atts_list $cell_formating_list]
        # trashed
        if { [llength $page_trashed_lists] > 0 && $write_p } {
            set page_trashed_sorted_lists $page_trashed_lists
            set page_trashed_sorted_lists [linsert $page_trashed_sorted_lists 0 [list Name Title Comments] ]
            set page_tag_atts_list [list border 1 cellspacing 0 cellpadding 3]
            
            set page_trashed_html "<h3>Trashed tables</h3>\n"
            append page_trashed_html [qss_list_of_lists_to_html_table $page_trashed_sorted_lists $page_tag_atts_list $cell_formating_list]
            append page_stats_html $page_trashed_html
        }
    }
    v {
        #  view page(s) (standard, html page document/report)

# if page_url is different than ad_conn url stem, 303/305 redirect to page_id's primary page_url
        ns_log Notice "q-wiki.tcl mode = $mode ie. view table"
        if { [qf_is_natural_number $page_id] && $write_p } {
            lappend menu_list [list edit "${url}?page_id=${page_id}&mode=e"]
            set menu_e_p 1
        } else {
            set menu_e_p 0
        }
        if { [qf_is_natural_number $page_id] } {
            set page_stats_list [qw_page_stats $page_id]
            set page_name [lindex $page_stats_list 0]
            set page_title [lindex $page_stats_list 1]
            set page_comments [lindex $page_stats_list 2]
            set page_html "<h3>${page_title} (${page_name})</h3>\n"
            append page_html $page_contents
            append page_html "<p>${page_comments}</p>"
            
            if { !$menu_e_p && $write_p } {
                
                lappend menu_list [list edit "${url}?page_id=${page_id}&mode=e"]
            }
        }
        if { [qf_is_natural_number $page_id]  } {
            lappend menu_list [list compute "${url}?page_id=${page_id}&mode=c"]
        }
    }
    w {
        #  save.....  (write) page_id 
        # should already have been handled above
        ns_log Notice "q-wiki.tcl mode = save THIS SHOULD NOT BE CALLED."
        # it's called in validation section.
    }
    default {

        # page_contents_filtered
        set page_main_code [template::adp_compile -string $page_contents_filtered]
        set page_main_code_html [template::adp_eval $page_main_code]
        
    }
}
# end of switches
    
set menu_html ""
foreach item_list $menu_list {
    set menu_label [lindex $item_list 0]
    set menu_url [lindex $item_list 1]
    append menu_html "<a href=\"${menu_url}\">${menu_label}</a>&nbsp;"
}

set user_message_html ""
foreach user_message $user_message_list {
    append user_message_html "<li>${user_message}</li>"
}


set doc(title) $title
set context [list $title]
