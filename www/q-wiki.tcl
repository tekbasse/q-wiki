# set defaults
set title "Q-Wiki"
set doc(title) $title
set context [list $title]

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set write_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege write]
set admin_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege admin]

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
                           mode "p" \
                           next_mode "p" \
                          ]

set user_message_list [list ]

# get previous form inputs if they exist
set page_contents_default $input_array(page_contents_default)
set page_contents $page_contents_default
set form_posted [qf_get_inputs_as_array input_array]
set page_id $input_array(page_id)
set url $input_array(url)
set mode $input_array(mode)
set next_mode $input_array(next_mode)

if { $form_posted } {
    if { [info exists input_array(x) ] } {
        unset input_array(x)
    }
    if { [info exists input_array(y) ] } {
        unset input_array(y)
    }

    set validated 0
    # validate input
    # cleanse, validate mode
    # determine input completeness
    # form has modal inputs, so validation is a matter of cleansing data and verifying references

    # d = delete (template_id or page_id)
    # e = edit template_id (current page_id of template_id) (follows with w)
    # l = list of pages (current page_ids of instance_id)
    # n = create page (new template_id)
    # r = revisions list of page (page_ids with same template_id)
    # t = trash (template_id or page_id)
    # v = view page_id (of template_id, defaults to current page_id of template_id)
    # w/v = write page_id of template_id, make page_id current for template_id, show page_id
    if { ![ecds_is_natural_number $page_id] } {
        set page_id ""
    }
    
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
        e {
            if { [qw_page_id_exists $page_id $package_id] } {
                ns_log Notice "q-wiki.tcl validated for e"
                set validated 1
            } else {
                set mode "n"
                set next_mode ""
            } 
        }
        l {
            set validated 1
            ns_log Notice "q-wiki.tcl validated for l"
        }
        n {
            set validated 1
            ns_log Notice "q-wiki.tcl validated for n"
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
        w {
            set page_name $input_array(page_name)
            set page_title $input_array(page_title)
            set page_contents $input_array(page_contents)
            set keywords $input_array(keywords)
            set description $input_array(description)
            set page_comments $input_array(page_comments)
            # page_template_id gets checked against db for added security
            set page_template_id $input_array(page_template_id)
            set page_flags $input_array(page_flags)
            
            set allow_adp_tcl_p [parameter::get -package_id $package_id -parameter AllowADPTCL -default 0]
            if { $allow_adp_tcl_p } {
                # screen page_contents
                set banned_proc_list [split [parameter::get -package_id $package_id -parameter BannedProc]]
                set allowed_proc_list [split [parameter::get -package_id $package_id -parameter AllowedProc]]
                set flagged_list [list ]
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
            # set page_contents_filtered was $page_contents
            if { [llength $flagged_list ] > 0 } {
                set mode e
                set next_mode ""
            } else {
                set next_mode v
            }
            set validated 1
            ns_log Notice "q-wiki.tcl validated for $mode"
        }
        default {
            if { [qw_page_id_exists $page_id $package_id] } {
                ns_log Notice "q-wiki.tcl validated for v"
                set validated 1
                set mode "v"
            } else {
                set mode "l"
                set next_mode ""
            } 
        }
        
    }
    #^ end switch

    if { $validated } {
        # execute validated input
        
        if { $mode eq "d" } {
            #  delete.... removes context     
            ns_log Notice "q-wiki.tcl mode = delete"
            if { [ecds_is_natural_number $page_id] } {
                qw_page_delete $page_id
            }
            set mode $next_mode
            set next_mode ""
        }
        if { $mode eq "t" } {
            #  trash
            ns_log Notice "q-wiki.tcl mode = trash"
            if { [ecds_is_natural_number $page_id] && $write_p } {
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
            # write the data
            # a different user_id makes new context based on current context, otherwise modifies same context
            # or create a new context if no context provided.
            # given:
            if { [string length $page_contents] > 0 && $page_contents ne $page_contents_default } {
                
                
                if { $input_array(page_name) eq "" && $page_id eq "" } {
                    set page_name "[clock format [clock seconds] -format %Y%m%d-%X]"
                } elseif { $input_array(page_name) eq "" } {
                    set page_name "${page_id}"
                } else {
                    set page_name $input_array(page_name)
                }
                # page_title 
                if { $input_array(page_title) eq "" && $page_id eq "" } {
                    set page_title "[clock format [clock seconds] -format %Y%m%d-%X]"
                } elseif { $input_array(page_title) eq "" } {
                    set page_title "${page_id}"
                } else {
                    set page_title $input_array(page_title)
                }
                # page_comments Comments
                set page_comments $input_array(page_comments)
                # page_contents
                
                qw_page_create $page_name $page_title $page_contents $keywords $description $page_comments $page_template_id $page_flags $package_id $user_id
                
            }
            
            set mode $next_mode
            set next_mode ""
        }
        
    }
    # end validated input if
    
}


set menu_list [list [list Q-Wiki ""]]
if { $write_p } {
    lappend menu_list [list new mode=n]
}

switch -exact -- $mode {
    e {
        #  edit...... edit/form mode of current context
        ns_log Notice "q-wiki.tcl mode = edit"
        #requires page_id
        
        # get table from ID
        
        
        qf_form action q-wiki/index method get id 20120721
        qf_input type hidden value w name mode label ""
        
        if { [ecds_is_natural_number $page_id] } {
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
    n {
        #  new....... creates new, blank context (form)    
        ns_log Notice "q-wiki.tcl mode = new"
        #requires no page_id
        # make a form with no existing page_id
        
        qf_form action q-wiki/index method get id 20120722
        
        qf_input type hidden value w name mode label ""
        if { $page_id > 0 } {
            ns_log Warning "mode n while page_id exist"
        }
        qf_append html "<h3>Q-Wiki new page</h3>"
        qf_append html "<div style=\"width: 70%; text-align: right;\">"
        qf_input type text value "" name page_name label "Name:" size 40 maxlength 40
        qf_append html "<br>"
        qf_input type text value "" name page_title label "Title:" size 40 maxlength 80
        qf_append html "<br>"
        qf_textarea value "" cols 40 rows 3 name page_comments label "Comments:"
        qf_append html "<br>"
        qf_textarea value $page_contents cols 40 rows 6 name page_contents label "Contents:"
        qf_append html "</div>"
        
        
        qf_input type submit value "Save"
        qf_close
        set form_html [qf_read]
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
        ns_log Notice "q-wiki.tcl mode = $mode ie. view table"
        if { [ecds_is_natural_number $page_id] && $write_p } {
            lappend menu_list [list edit "page_id=${page_id}&mode=e"]
            set menu_e_p 1
        } else {
            set menu_e_p 0
        }
        if { [ecds_is_natural_number $page_id] } {
            set page_stats_list [qw_page_stats $page_id]
            set page_name [lindex $page_stats_list 0]
            set page_title [lindex $page_stats_list 1]
            set page_comments [lindex $page_stats_list 2]
            set page_html "<h3>${page_title} (${page_name})</h3>\n"
            append page_html $page_contents
            append page_html "<p>${page_comments}</p>"
            
            if { !$menu_e_p && $write_p } {
                
                lappend menu_list [list edit "page_id=${page_id}&mode=e"]
            }
        }
        if { [ecds_is_natural_number $page_id]  } {
            lappend menu_list [list compute "page_id=${page_id}&mode=c"]
        }
    }
    w {
        #  save.....  (write) page_id 
        # should already have been handled above
        ns_log Notice "q-wiki.tcl mode = save THIS SHOULD NOT BE CALLED."
        # it's called in validation section.
    }
    default {
        set allow_adp_tcl_p [parameter::get -package_id $package_id -parameter AllowADPTCL -default 0]
        # page_contents

        #  screen existing content 
        if { $allow_adp_tcl_p } {
            # screen page_contents
            set banned_proc_list [split [parameter::get -package_id $package_id -parameter BannedProc]]
            set allowed_proc_list [split [parameter::get -package_id $package_id -parameter AllowedProc]]
            set flagged_list [list ]
            set code_block_list [qf_tag_contents_list '<%' '%>' $page_contents]
            foreach code_block $code_block_list {
                set code_segments_list [qf_tcl_code_parse_lines_list $code_block]
                foreach code_segment $code_segments_list  {
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
                                    ns_log Warning "q-wiki.tcl(549) blocked executable '$executable' found in page $page_id."
                                }
                            }            
                        } else {
                            lappend flagged_list $executable
                            ns_log Warning "q-wiki.tcl(555) blocked executable '$executable' found in page $page_id."
                        }
                    }
                }
            }
            if { [llength $flagged_list] == 0 } {
                # content passed filters
                set page_contents_filtered $page_contents
            } else {
                set page_contents_filtered ""
                ns_log Notice "q-wiki.tcl(564) trashing page $page_id due to existing banned procs."
                qw_page_trash $trash $page_id
            }
        } else {
            set page_contents_list [qf_remove_tag_contents '<%' '%>' $page_contents]
            set page_contents_filtered ""
            foreach page_segment $page_contents_list {
                append page_contents_filtered $page_segment
            }
        }
        # set page_contents_filtered was $page_contents


        # page_contents_filtered
        set page_main_code [template::adp_compile -string $page_contents_filtered]
        set page_main_code_html [template::adp_eval page_main_code]
        
    }
}
# end of switches
    
set menu_html ""
foreach item_list $menu_list {
    set menu_label [lindex $item_list 0]
    set menu_url [lindex $item_list 1]
    append menu_html "<a href=\"${url}?${menu_url}\">${menu_label}</a>&nbsp;"
}

set user_message_html ""
foreach user_message $user_message_list {
    append user_message_html "<li>${user_message}</li>"
}
