# q-wiki/q-wiki.tcl
# part of the Q-Wiki package 
# depends on OpenACS website toolkit at OpenACS.org
# copyrigh t
# released under GPL license
# this page split into MVC components:
#  inputs/observations (controller), actions (model), and outputs/reports (view) sections


# INPUTS / CONTROLLER

# set defaults
# template_id is first page_id, subsequent revisions have same template_id, but new page_id
# flags are blank -- an unused db column / page attribute for extending the app for use cases
# url has to be a given (not validated), since this page may be fed $url via an index.vuh

set title "Q-Wiki"

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set read_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege read]
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
set title $input_array(page_title)

# get previous form inputs if they exist
set form_posted [qf_get_inputs_as_array input_array]
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

# Is this a redirect from index.vuh ?
set file_name [file tail [ad_conn file]]
if { [ns_urldecode $input_array(url_referring)] eq "index.vuh" && $file_name eq "q-wiki.adp" } {
    # To do, when write_p == 1: index.vuh value should be replaced with a session continuity key passed via db.

    # If url is internal_redirecting from index.vuh, url should be same as:
    # set url [ad_conn path_info]

    # url_de-encode values
    set url $input_array(url)
    set page_name [ns_urldecode $page_name]
    set page_title [ns_urldecode $page_title]
    set page_flags [ns_urldecode $page_flags]
    set keywords [ns_urldecode $keywords]
    set description [ns_urldecode $description]
    set page_comments [ns_urldecode $page_comments]
    set page_contents [ns_urldecode $page_contents]

} elseif { $file_name eq "index.vuh" } {
    # is this code executing inside index.vuh?
    set url [ad_conn path_info]
    ns_log Notice "q-wiki.tcl(29): file_name ${file_name}. Setting url to $url"
} else {
    # A serious assumption has broken.
    ns_log Warning "q-wiki.tcl(75): quit with referr_url and file_name out of boundary. Check log for request details."
    ns_returnnotfound
    #  rp_internal_redirect /www/global/404.adp
    ad_script_abort
}
if { $url eq "" } {
    set url "index"
}
set page_id_from_url [qw_page_id_from_url $url $package_id]
if { $page_id_from_url ne "" && ![qf_is_natural_number $page_id_from_url] } {
ns_log Notice "q-wiki.tcl(62): page_id_from_url '$page_id_from_url'"
}
ns_log Notice "q-wiki.tcl(63): mode $mode next_mode $next_mode"
# Modes are views, or one of these compound action/views
    # d delete (d x) then view as before (where x = l, r or v)
    # t trash (d x) then view as before (where x = l, r or v)
    # w write (d x) , then view page_id (v)

# Actions
    # d = delete template_id or page_id
    # t = trash template_id or page_id
    # w = write page_id,template_id, make new page_id for template_id
# Views
    # e = edit page_url, presents defaults (new) if page doesn't exist
    # v = view page_url
    # l = list pages of instance
    # r = view/edit page_url revisions
    # default = 404 return

    # url has to come from form in order to pass info via index.vuh
    # set conn_package_url [ad_conn package_url]
    # set url [string range $url [string length $conn_package_url] end]
    # get page_id from url, if any

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

    set validated_p 0
    # validate input
    # cleanse data, verify values for consistency
    # determine input completeness

    
    if { $page_id_from_url ne "" } {
        # page exists
        set page_stats_list [qw_page_stats $page_id_from_url $package_id $user_id]
        set page_template_id_from_db [lindex $page_stats_list 5]
        ns_log Notice "q-wiki/www/q-wiki.tcl(106): page_template_id_from_db '$page_template_id_from_db'"

        # page_template_id and page_id gets checked against db for added security
        # check for form/db descrepencies
        if { $page_id ne "" && $page_id ne $page_id_from_url } {
            set  mode ""
            set next_mode ""
            ns_log Notice "q-wiki/q-wiki.tcl page_id '$page_id' ne page_id_from_url '$page_id_from_url' "
            lappend user_message_list "There has been an internal processing error. Try again or report to [ad_admin_owner]"
        }
        if { $page_template_id ne "" && $page_template_id ne $page_template_id_from_db } {
            set mode ""
            set next_mode ""
            ns_log Notice "q-wiki/q-wiki.tcl page_template_id '${page_template_id}' ne page_template_id_from_db '${page_template_id_from_db}'"
            lappend user_message_list "There has been an internal processing error. Try again or report to [ad_admin_owner]"
        }
        
        # A blank referrer means a direct request
        # otherwise make sure referrer is from same domain when editing
        set referrer_url [get_referrer]


        ns_log Notice "q-wiki.tcl(124): mode $mode next_mode $next_mode"
        # get info to pass back to write proc

        # This is a place to enforce application specific permissions.
        # If package parameter says each template_id is an object_id, 
        # check user_id against object_id, otherwise check against package_id
        # However, original_page_creation_user_id is in the db, so that instance specific
        # user permissions can be supported.
        # set original_user_id \[lindex $page_stats_list_of_template_id 11\]

    } elseif { $write_p && $mode ne "l" && $mode ne "w" } {
        # page does not exist
        # present an edit/new page
        set mode "e"
        set next_mode ""
        set validated_p 1
    } 
    # else should default to 404 at switch in View section.

    # validate input values for specific modes
    # failovers for permissions follow reverse order (skipping ok): admin_p delete_p write_p create_p read_p
    # possibilities are: d, t, w, e, v, l, r, "" where "" is invalid input or unreconcilable error condition.
    # options include    d, l, r, t, e, "", w, v
    ns_log Notice "q-wiki/www/q-wiki.tcl(141): initial mode $mode, next_mode $next_mode"
    if { $mode eq "d" } {
        if { $delete_p } {
            ns_log Notice "q-wiki.tcl validated for d"
            set validated_p 1
        } elseif { $read_p } {
            set mode "l"
            set next_mode ""
        } else {
            set mode ""
            set next_mode ""
        }
    }
    ns_log Notice "q-wiki.tcl(157): mode $mode next_mode $next_mode"
    if { $mode eq "w" } {
        if { $write_p } {
            set validated_p 1
        } elseif { $read_p } {
            # give the user a chance to save their changes elsewhere instead of erasing the input
            set mode "e"
        } else {
            set mode ""
            set next_mode ""
        }
    }
    ns_log Notice "q-wiki.tcl(169): mode $mode next_mode $next_mode"
    if { $mode eq "r" } {
        if { $write_p } {
            if { [qw_page_id_exists $page_id $package_id] } {
                set validated_p 1
                ns_log Notice "q-wiki.tcl validated for r"
            } elseif { $read_p } {
                # This is a 404 return, but we list pages for more convenient UI
                lappend user_message_list "Page not found. Showing a list of choices."
                set mode "l"
            }
        } else {
            set mode ""
        }
        set next_mode ""
    }
    ns_log Notice "q-wiki.tcl(185): mode $mode next_mode $next_mode"
    if { $mode eq "t" } {
        if { $write_p && [qw_page_id_exists $page_id $package_id] } {
            set validated_p 1
            ns_log Notice "q-wiki.tcl validated for t"
        } elseif { $read_p } {
            set mode "l"
        } else {
            set mode ""
        }
        set next_mode ""
    }

    if { $page_id_from_url eq "" && $write_p && $mode eq "" && $next_mode eq "" } {
        # page is blank
        # switch to edit mode automatically
        set mode "e"
    } 

    ns_log Notice "q-wiki.tcl(197): mode $mode next_mode $next_mode"
    if { $mode eq "e" } {
        # validate for new and existing pages. 
        # For new pages, template_id will be blank (template_exists_p == 0)
        # For revisions, page_id will be blank.
        set template_exists_p [qw_page_id_exists $page_template_id]
        if { !$template_exists_p } {
            set page_template_id ""
        }
        if { $write_p || ( $create_p && !$template_exists_p ) } {
            
            # page_title cannot be blank
            if { $page_title eq "" && $page_template_id eq "" } {
                set page_title "[clock format [clock seconds] -format %Y%m%d-%X]"
            } elseif { $page_title eq "" } {
                set page_title "${page_template_id}"
            } else {
                set page_title_length [parameter::get -package_id $package_id -parameter PageTitleLen -default 80]
                incr page_title_length -1
                set page_title [string range $page_title 0 $page_title_length]
            }
            
            if { $page_template_id eq "" && $page_name ne "" } {
                # this is a new page
                set url [ad_urlencode $page_name]
                set page_id ""
            } elseif { $page_template_id eq "" } {
                if { [regexp -nocase -- {[^a-z0-9\%\_\-\.]} $url] } {
                    # url contains unencoded characters
                    set url [ad_urlencode $url]
                    set page_id ""
                }
                
                # Want to enforce unchangeable urls for pages?
                # If so, set url from db for template_id here.
            }
            ns_log Notice "q-wiki.tcl(226): url $url"
            # page_name is pretty version of url, cannot be blank
            if { $page_name eq "" } {
                set page_name $url
            } else {
                set page_name_length [parameter::get -package_id $package_id -parameter PageNameLen -default 40]
                incr page_name_length -1
                set page_name [string range $page_name 0 $page_name_length]
            }
            set validated_p 1
            ns_log Notice "q-wiki.tcl validated for $mode"
        } elseif { $read_p && $template_exists_p } {
            set mode v
            set next_mode ""
        } else {
            set mode ""
            set next_mode ""
        }
    }
    ns_log Notice "q-wiki.tcl(252): mode $mode next_mode $next_mode"
    if { $mode eq "l" } {
        if { $read_p } {
            set validated_p 1
            ns_log Notice "q-wiki.tcl validated for l"
        } else {
            set mode ""
            set next_mode ""
        }
    }
    ns_log Notice "q-wiki.tcl(262): mode $mode next_mode $next_mode"
    if { $mode eq "v" } {
        if { $read_p } {
            # url vetted previously
            set validated_p 1
            if { $page_id_from_url ne "" } {
                # page exists
            } else {
                set mode "l"
                ns_log Notice "q-wiki.tcl(405): mode = $mode ie. list of pages, index"
            }
        } else {
            set mode ""
            set next_mode ""
        }
    }

    # ACTIONS, PROCESSES / MODEL
    ns_log Notice "q-wiki.tcl(268): mode $mode next_mode $next_mode validated $validated_p"
    if { $validated_p } {
        ns_log Notice "q-wiki.tcl Executing validated action mode $mode"
        # execute process using validated input
        # IF is used instead of SWITCH, so multiple sub-modes can be processed in a single mode.
        if { $mode eq "d" } {
            #  delete.... removes context     
            ns_log Notice "q-wiki.tcl mode = delete"
            if { $delete_p } {
                qw_page_delete $page_id
            }
            set mode $next_mode
            set next_mode ""
        }
        if { $mode eq "t" } {
            #  toggle trash
            ns_log Notice "q-wiki.tcl mode = trash"
            if { $write_p } {
                set trashed_p [lindex [qw_page_stats $page_id] 7]
                if { $trashed_p == 1 } {
                    set trash 0
                } else {
                    set trash 1
                }
                qw_page_trash $trash $page_id
                set mode $next_mode
            } else {
                lappend user_message_list "Trash operation could not be completed. You don't have permission."
                set mode "v"
            }
            set next_mode ""
        }
        if { $mode eq "w" } {
            if { $write_p } {
                ns_log Notice "q-wiki.tcl permission to write the write.."
                set page_contents_quoted $page_contents
                set page_contents [ad_unquotehtml $page_contents]
                set allow_adp_tcl_p [parameter::get -package_id $package_id -parameter AllowADPTCL -default 0]
                set flagged_list [list ]
                
                if { $allow_adp_tcl_p } {
                    ns_log Notice "q-wki.tcl(311): adp tags allowed. Fine grain filtering.."
                    # filter page_contents for allowed and banned procs in adp tags
                    set banned_proc_list [split [parameter::get -package_id $package_id -parameter BannedProc]]
                    set allowed_proc_list [split [parameter::get -package_id $package_id -parameter AllowedProc]]
                    
                    set code_block_list [qf_get_contents_from_tags_list "<%=" "%>" $page_contents]
                    foreach code_block $code_block_list {
#                        set code_segments_list \[qf_tcl_code_parse_lines_list $code_block\] <-- Doesn't need to be as complicated as a separate proc.
                        set code_segments_list [split $code_block \n\r]
                        foreach code_segment $code_segments_list  {
                            # see filters in accounts-finance/tcl/modeling-procs.tcl for inspiration
                            set executable_fragment_list [split $code_segment \[]
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
                                if { $executable eq "" } {
                                    # skip an empty executable, but log it just in case
                                    ns_log Notice "q-wiki.tcl(395): executable is empty. Screening incomplete?"
                                } else {
                                    # see if this proc is allowed
                                    set proc_allowed_p 0
                                    foreach allowed_proc $allowed_proc_list {
                                        if { [string match $allowed_proc $executable] } {
                                            set proc_allowed_p 1
                                        }
                                    }
                                    # see if this proc is banned
                                    if { $proc_allowed_p } {
                                        foreach banned_proc $banned_proc_list {
                                            if { [string match $banned_proc $executable] } {
                                                # banned executable found
                                                set proc_allowed_p 0
                                                lappend flagged_list $executable
                                                lappend user_message_list "'$executable' is banned from use."
                                            }
                                        }            
                                    } else {
                                        lappend flagged_list $executable
                                        lappend user_message_list "'$executable' is not allowed at this time."
                                    }
                                }

                            }
                        }
                    }
                    if { [llength $flagged_list] == 0 } {
                        # content passed filters
                        set page_contents_filtered $page_contents
                    } else {
                        set page_contents_filtered $page_contents_quoted
                    }
                } else {
                    # filtering out all adp tags (allow_adp_tcl_p == 0)
                    ns_log Notice "q-wiki.tcl(358): filtering out adp tags"
#                    ns_log Notice "q-wiki.tcl(359): range page_contents 0 120: '[string range ${page_contents} 0 120]'"
                    set page_contents_list [qf_remove_tag_contents "<%" "%>" $page_contents]
                    set page_contents_filtered [join $page_contents_list ""]
#ns_log Notice "q-wiki.tcl(427): range page_contents_filtered 0 120: '[string range ${page_contents_filtered} 0 120]'"
                }
                # use $page_contents_filtered, was $page_contents
                set page_contents [ad_quotehtml $page_contents_filtered]
                
                if { [llength $flagged_list ] > 0 } {
                    ns_log Notice "q-wiki.tcl(369): content flagged, changing to edit mode."
                    set mode e
                } else {
                    # write the data
                    # a different user_id makes new context based on current context, otherwise modifies same context
                    # or create a new context if no context provided.
                    # given:
                    
                    # create or write page
                    if { $page_id eq "" } {
                        # create page
                        set page_id [qw_page_create $url $page_name $page_title $page_contents_filtered $keywords $description $page_comments $page_template_id $page_flags $package_id $user_id]
                        if { $page_id == 0 } {
                            ns_log Warning "q-wiki/q-wiki.tcl page write error for url '${url}'"
                            lappend user_messag_list "There was an error creating the wiki page at '${url}'."
                        }
                    } else {
                        # write page
                        set success_p [qw_page_write $page_name $page_title $page_contents_filtered $keywords $description $page_comments $page_id $page_template_id $page_flags $package_id $user_id]
                        if { $success_p == 0 } {
                            ns_log Warning "q-wiki/q-wiki.tcl page write error for url '${url}'"
                            lappend user_messag_list "There was an error creating the wiki page at '${url}'."
                        }
                    }
                    # switch modes..
                    ns_log Notice "q-wiki.tcl(396): activating next mode $next_mode"
                    set mode $next_mode
                }
            } else {
                # does not have permission to write
                lappend user_message_list "Write operation could not be completed. You don't have permission."
                ns_log Notice "q-wiki.tcl(402) User attempting to write content without permission."
                if { $read_p } {
                    set mode "v"
                } else {
                    set mode ""
                }
            }
            # end section of write
            set next_mode ""
        }
    }
} else {
    # form not posted
    ns_log Warning "q-wiki.tcl(451): Form not posted. This shouldn't happen via index.vuh."
}


set menu_list [list [list Q-Wiki index]]

# OUTPUT / VIEW
# using switch, because there's only one view at a time
switch -exact -- $mode {
    l {
        #  list...... presents a list of pages
        if { $read_p } {
            ns_log Notice "q-wiki.tcl(427): mode = $mode ie. list of pages, index"
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
        } else {
            # does not have permission to read. This should not happen.
            ns_log Warning "q-wiki.tcl:(465) user did not get expected 404 error when not able to read page."
        }
    }
    r {
        #  revisions...... presents a list of page revisions
        if { $write_p } {
            ns_log Notice "q-wiki.tcl mode = $mode ie. revisions"
            append title " page revisions"
            
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
        } else {
            # no permission to write or edit page. This should not happen.
            ns_log Warning "q-wiki.tcl:(543) user did not get expected error when not able to write page."
        }
    }
    e {
        if { $write_p } {
            #  edit...... edit/form mode of current context

            ns_log Notice "q-wiki.tcl mode = edit"
            append title " edit"
            # for existing pages, add template_id
            set conn_package_url [ad_conn package_url]
            set post_url [file join $conn_package_url $url]

            ns_log Notice "q-wiki.tcl(636): conn_package_url $conn_package_url post_url $post_url"
            if { $page_id_from_url ne "" && [llength $user_message_list ] == 0 } {
                # get page info
                set page_list [qw_page_read $page_id_from_url $package_id $user_id ]
                set page_name [lindex $page_list 0]
                set page_title [lindex $page_list 1]
                set keywords [lindex $page_list 2]
                set description [lindex $page_list 3]
                set page_template_id [lindex $page_list 4]
                set page_flags [lindex $page_list 5]
                set page_contents [lindex $page_list 11]
                set page_comments [lindex $page_list 12]
            }

            qf_form action $post_url method get id 20130128
            qf_input type hidden value w name mode
            qf_input type hidden value v name next_mode
            qf_input type hidden value $page_flags name page_flags
            qf_input type hidden value $page_template_id name page_template_id
            #        qf_input type hidden value $page_id name page_id label ""
            qf_append html "<h3>Q-Wiki page edit</h3>"
            qf_append html "<div style=\"width: 70%; text-align: right;\">"
            set page_name_unquoted [ad_unquotehtml $page_name]
            qf_input type text value $page_name_unquoted name page_name label "Name:" size 40 maxlength 40
            qf_append html "<br>"
            set page_title_unquoted [ad_unquotehtml $page_title]
            qf_input type text value $page_title_unquoted name page_title label "Title:" size 40 maxlength 80
            qf_append html "<br>"
            set description_unquoted [ad_unquotehtml $description]
            qf_textarea value $description_unquoted cols 40 rows 1 name description label "Description:"
            qf_append html "<br>"
            set page_comments_unquoted [ad_unquotehtml $page_comments]
            qf_textarea value $page_comments_unquoted cols 40 rows 3 name page_comments label "Comments:"
            qf_append html "<br>"
            set page_contents_unquoted [ad_unquotehtml $page_contents]
            qf_textarea value $page_contents_unquoted cols 40 rows 6 name page_contents label "Contents:"
            qf_append html "<br>"
            set keywords_unquoted [ad_unquotehtml $keywords]
            qf_input type text value $keywords_unquoted name keywords label "Keywords:" size 40 maxlength 80
            qf_append html "</div>"
            qf_input type submit value "Save"
            qf_close
            set form_html [qf_read]
        } else {
            lappend user_message_list "Edit operation could not be completed. You don't have permission."
        }
    }
    v {
        #  view page(s) (standard, html page document/report)
        if { $read_p } {
            # if $url is different than ad_conn url stem, 303/305 redirect to page_id's primary url
            ns_log Notice "q-wiki.tcl(667): mode = $mode ie. view"

            # build menu options
            if { $write_p } {
                lappend menu_list [list edit "${url}?mode=e"]
                set menu_edit_p 1
                if { $delete_p } {
                    lappend menu_list [list delete ${url}?mode=d]
                } else {
                    # can only trash revisions, not entire page
                    lappend menu_list [list revisions ${url}?mode=r]
                }
            } else {
                set menu_edit_p 0
            }

            # get page info
            # cannot use previous $page_id_from_url, because it might be modified from an ACTION
            # Get it again.
            set page_id_from_url [qw_page_id_from_url $url $package_id]
            set page_list [qw_page_read $page_id_from_url $package_id $user_id ]
            set page_title [lindex $page_list 1]
            set keywords [lindex $page_list 2]
            set description [lindex $page_list 3]
            set page_contents [lindex $page_list 11]

            if { $keywords ne "" } {
                template::head::add_meta -name keywords -content $keywords
            }
            if { $description ne "" } {
                template::head::add_meta -name description -content $description
            }
            set title $page_title
            # page_contents_filtered
            set page_contents_unquoted [ad_unquotehtml $page_contents]
            set page_main_code [template::adp_compile -string $page_contents_unquoted]
            set page_main_code_html [template::adp_eval page_main_code]

        } else {
            # no permission to read page. This should not happen.
            ns_log Warning "q-wiki.tcl:(619) user did not get expected 404 error when not able to read page."
        }
    }
    w {
        #  save.....  (write) page_id 
        # should already have been handled above
        ns_log Warning "q-wiki.tcl(575): mode = save/write THIS SHOULD NOT BE CALLED."
        # it's called in validation section.
    }
    default {
        # return 404 not found or not validated (permission or other issue)
        # this should use the base from the config.tcl file
        if { [llength $user_message_list ] == 0 } {
            ns_returnnotfound
            #  rp_internal_redirect /www/global/404.adp
            ad_script_abort
        }
    }
}
# end of switches

set user_message_html ""
foreach user_message $user_message_list {
    append user_message_html "<li>${user_message}</li>"
}

set menu_html ""
if { $validated_p } {
    foreach item_list $menu_list {
        set menu_label [lindex $item_list 0]
        set menu_url [lindex $item_list 1]
        append menu_html "<a href=\"${menu_url}\">${menu_label}</a>&nbsp;"
    }
} 
set doc(title) $title
set context [list $title]
