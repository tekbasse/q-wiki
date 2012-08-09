# generic header for static .adp pages

set title "file utility"
set context [list $title]


set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set write_p 0
set create_p 0
set delete_p 0
set admin_p 0
set read_p 0
if { $user_id > 0 } {
    # we don't ever want the public to see anything from file-utility
    set read_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege read]
    set write_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege write]
    set create_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege create]
    set delete_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege delete]
    set admin_p [permission::permission_p -party_id $user_id -object_id $package_id -privilege admin]
}
set trash_p $write_p
# tid = table_id
#p = url path, as if coming from an http request
array set input_array [list \
    p "/fractals/resources" \
    new_name ""\
    submit "" \
    reset "" \
    mode "" \
    next_mode "" \
			   ]

array set title_array [list \
    submit "Submit" \
    reset "Reset" \
			   ]

set user_message_list [list ]

set acs_root_dir [acs_root_dir]
set sitewide_seg www
set fu_trash_seg [file join file-utility trash]
#set package_dir [fs::get_root_folder -package_id $package_id]
#set package_dir2 [site_node::conn_url]
    # make it relative
#    set package_dir2 [string range $package_dir2 1 end]
set full_package_dir [ad_conn package_url]
set package_dir [string range $full_package_dir 1 end]
#set package_dir2 /[ad_conn url/]
set local_root_seg resources

set oacs_fullpath_root_dir [file join $acs_root_dir $sitewide_seg $package_dir $local_root_seg]
set url_fullpath_root_dir [file join $full_package_dir $local_root_seg]
ns_log Notice "file-utility.tcl oacs_fullpath_root_dir ${oacs_fullpath_root_dir} url_fullpath_root_dir ${url_fullpath_root_dir}"
#ns_log Notice "file-utility.tcl: acs_root_dir $acs_root_dir fu_trash_seg $fu_trash_seg package_dir '${package_dir}' package_dir2 '${package_dir2}' local_root_seg '$local_root_seg' package_id $package_id package_dir_apm $package_dir_apm"
#ns_log Notice "file-utility.tcl: package_dir '${package_dir}' package_dir2 '${package_dir2}'"
# get previous form inputs if they exist
set form_posted [qf_get_inputs_as_array input_array]
set mode $input_array(mode)
set next_mode $input_array(next_mode)

set validated 0
if { $form_posted } {
    if { [info exists input_array(x) ] } {
        unset input_array(x)
    }
    if { [info exists input_array(y) ] } {
        unset input_array(y)
    }
    set mode $input_array(mode)
    set next_mode $input_array(next_mode)
}

set p $input_array(p)
# validate input
# make sure p is clean
regsub -all -- {[^[:alnum:]\.\/\-]} $p {-} p
# standardize p , making it absolute ref
set p [file normalize $p]
set p_url $p

# make p relative
set p_rel [string range $p 1 end]

set p_oacs [file join $oacs_fullpath_root_dir $p_rel]
set p_is_dir_p [file isdirectory $p_oacs]
# is p_oacs file (set file_p)
if { $p_is_dir_p } {
    set p_is_file_p 0
} else {
    set p_is_file_p [file isfile $p_oacs]
} 
if { $p_is_file_p } {
    set p_oacs_dir [file dirname $p_oacs]
    set p_oacs_tail [file tail $p_oacs]
} else {
    set p_oacs_dir $p_oacs
    set p_oacs_tail ""
}
ns_log Notice "file-utility.tcl(114): p_is_dir_p $p_is_dir_p p_is_file_p $p_is_file_p "

set p_fullpath_trash_dir [file join $acs_root_dir $fu_trash_seg $package_dir]
set p_fullpath_trash [file join $p_fullpath_trash_dir [file tail $p_oacs] ]
set pt_is_dir_p [file isdirectory $p_fullpath_trash]
if { $pt_is_dir_p } {
    set pt_is_file_p 0
} else {
    set pt_is_file_p [file isfile $p_fullpath_trash]
}
if { $pt_is_file_p } {
#    set p_fullpath_trash_dir \[file dirname $p_fullpath_trash\]
#    set p_trash_tail \[file tail $p_fullpath_trash\]
    set p_trash_tail $p_oacs_tail
} else {
    set p_fullpath_trash $p_fullpath_trash_dir
    set p_trash_tail ""
}
ns_log Notice "file-utility.tcl(89): p_url $p_url p_oacs $p_oacs p_oacs_dir $p_oacs_dir p_fullpath_trash $p_fullpath_trash"

# does p_oacs exist?
set p_oacs_p [file exists $p_oacs]
set p_trash_p [file exists $p_fullpath_trash]
set p_exists [expr { $p_oacs_p || $p_trash_p } ]
ns_log Notice "file-utility.tcl(94): p_oacs_p $p_oacs_p p_trash_p $p_trash_p"

if { $p_oacs_p } {
    # is p within boundary?
    set p_test_len [expr { [string length $oacs_fullpath_root_dir] - 1 } ]
    if { [string range $p_oacs 0 $p_test_len] eq $oacs_fullpath_root_dir } {
        set validated 1
    }
} 



if { $validated } {

    # cleanse, validate mode
    # determine input completeness
    # form has modal inputs, so validation is a matter of cleansing data and verifying references
    
    switch -exact -- $mode {
        d {
            ns_log Notice "file-utility.tcl validate for d"
            if { !$delete_p } {
                lappend user_message_list "You do not have permission to delete."
                set mode "p"
                set next_mode ""
                set validated 0
            }
        }
        t {
            ns_log Notice "file-utility.tcl validate for t"
            if { !$trash_p } {
                lappend user_message_list "You do not have permission to trash."
                set mode "p"
                set next_mode ""
                set validated 0
            } 
        }
        u {
            ns_log Notice "file-utility.tcl validate for t"
            if { !$trash_p } {
                lappend user_message_list "You do not have permission to trash."
                set mode "p"
                set next_mode ""
                set validated 0
            } 
        }
        c {
            ns_log Notice "file-utility.tcl validate for c"
            if { !$create_p } {
                lappend user_message_list "You do not have permission to copy."
                set validated 0
                set mode "p"
                set next_mode ""
                set validated 0
            } 
        }
        r {
            ns_log Notice "file-utility.tcl validate for r"
            if { !$write_p } {
                lappend user_message_list "You do not have permission to write or rename."
                set validated 0
                set mode "p"
                set next_mode ""
            } 
            
        }
        default {
            ns_log Notice "file-utility.tcl validate for v"
            # determine if url exists and is within root folder
            if { $read_p } {
                set mode "v"
              
            } else {
                set mode "p"
                set next_mode ""
            } 
        }
    }
    # end switch

    # execute validated input
    
    if { $mode eq "d" } {
        #  delete.... removes context     
        ns_log Notice "file-utility.tcl mode = delete"
        if { [qf_is_natural_number $initial_conditions_tid] } {
            # delete file
            lappend user_message_list "filepath deleted."
        }
        
        set mode $next_mode
        set next_mode ""
    }
    if { $mode eq "t" } {
        #  trash.... moves item to a holding dir in ad_root_folder with same file tree
        ns_log Notice "file-utility.tcl mode = trash"
        # trash file
        if { [file exists $p_fullpath_trash ] } {
            lappend user_message_list "cannot trash file. Item of same name already trashed."
        } else {
            ec_assert_directory $p_fullpath_trash_dir
            if { [catch { file rename $p_oacs $p_fullpath_trash } error_msg] } {
                lappend user_message_list "Unable to trash. Got: $error_msg"
            } else {
                lappend user_message_list "filepath trashed."
            } 
        }
        set mode $next_mode
        set next_mode ""
    }
    if { $mode eq "u" } {
        #  untrash.... moves item from a holding dir in ad_root_folder with same file tree to it's published location
        ns_log Notice "file-utility.tcl mode = untrash"
        # trash file
        
        if { [file exists $p_oacs ] } {
            lappend user_message_list "cannot untrash file. Item of same name is already published."
        } else {
            ec_assert_directory $p_oacs_dir
            if { [catch { file rename $p_fullpath_trash $p_oacs } error_msg] } {
                lappend user_message_list "Unable to trash. Got: $error_msg"
            } else {
                lappend user_message_list "filepath un-trashed."
            } 
        }
        set mode $next_mode
        set next_mode ""
    }
    if { $mode eq "c" } {
        #  copy  copies item
        ns_log Notice "file-utility.tcl mode = copy"
        regsub -all -- {[^[:alnum:]\.\-]} $new_name {-} new_name
        if { [string length $new_name] > 0 } {
            if { [catch { file copy $p_oacs [file join $p_oacs_dir $new_name] } error_msg] } {
                lappend user_message_list "Unable to copy. Got: $error_msg"
            } else {
                lappend user_message_list "File ${p_oacs_tail} copied to ${new_name}."
            }
        } else {
            lappend user_message_list "Unable to copy. New name can only contain letters, numerals, dot (.) or dashes(-)."
        }
        set mode $next_mode
        set next_mode ""
    }
    
    if { $mode eq "r" } {
        #  rename .. renames item
        ns_log Notice "file-utility.tcl mode = rename"
        regsub -all -- {[^[:alnum:]\.\-]} $new_name {-} new_name
        if { [string length $new_name] > 0 } {
            if { [catch { file copy $p_oacs [file join $p_oacs_dir $new_name] } error_msg] } {
                lappend user_message_list "Unable to rename. Got: $error_msg"
            } else {
                lappend user_message_list "File ${p_oacs_tail} renamed to ${new_name}."
            }
        } else {
            lappend user_message_list "Unable to rename. New name can only contain letters, numerals, dot (.) or dashes(-)."
        }
        set mode $next_mode
        set next_mode ""
    }
}
# end validated input if


set menu_list [list [list file-utility ""]]

switch -exact -- $mode {
    default {
        # default includes v
        #  present...... presents a list of files/dirs in $url
        if { $form_posted } {
        ns_log Notice "file-utility.tcl mode = $mode ie. default"
        ns_log Notice "file-utility.tcl acs_root_dir $acs_root_dir sitewide_seg $sitewide_seg fu_trash_seg $fu_trash_seg package_dir $package_dir local_root_seg $local_root_seg"
        ns_log Notice "file-utility.tcl: oacs_fullpath_root_dir $oacs_fullpath_root_dir url_fullpath_root_dir $url_fullpath_root_dir"
        ns_log Notice "file-utility.tcl: p_oacs $p_oacs p_oacs_dir $p_oacs_dir p_oacs_tail $p_oacs_tail "
        ns_log Notice "file-utility.tcl: p_rel $p_rel p_oacs_p $p_oacs_p p_trash_p $p_trash_p p_exists $p_exists p_is_dir_p $p_is_dir_p p_is_file_p $p_is_file_p"
        ns_log Notice "file-utility.tcl: p_fullpath_trash_dir $p_fullpath_trash_dir p_fullpath_trash $p_fullpath_trash"
        }

        if { $p_is_dir_p } {

            # make a table with 4 columns
            # column 1: $write_action_list 'select copy, rename' and any other command requiring an $arg1
            # column 2: $p_oacs  shows directory tree above current location (rowpan all). if p_is_dir_p,includes directory name 
            # column 3: $tailname  shows files as names. if dir, shows link to that dir if file, shows link to file, if p_is_dir_p, this contains column $4 arg1 field
            # column 4 $rNname2   arg1 field (used for renaming or moving)
            # column 5: att_arr(size)  
            # column 6: att_arr(mtime)
            #      This form is built to allow multiple commands at the same time (but only 1 per item).
            set write_action_list [list ]
            if { $write_p } {
                lappend write_action_list [list label copy value copy] [list label rename value rename] 
            }
            if { $trash_p } { 
                lappend write_action_list [list label trash value trash]
            }

            
            qf_form action file-utility method post id 20120708
            
            #        qf_input type hidden value w name mode label ""
            #        qf_append html "<div style=\"width: 70%; text-align: right;\">"
            #        qf_input type text value "" name r1 label "Table name:" size 40 maxlength 40
            #        qf_choice type select/radio name model value $models_list
            
            set dir_list [glob -path $p_oacs -- *]
            set row 0
            #            set table_lists [list ] <- cabn't do this, because we are building inside a qf_form
            foreach tailname $dir_list {
                set filenamepath [file join $p_oacs $tailname]
                set fnp_exists_p [file exists $filenamepath]
                if { $fnp_exists_p } {
                    set fnp_is_file_p [file isfile $filenamepath]
                    if { $fnp_is_file_p }
                    set fnp_is_dir_p 0
                } else {
                    set fnp_is_dir_p [file isdirectory $filenamepath]
                }
                if { $fnp_is_dir_p } {
                    incr row
                    append tailname [file separator]
                    # $write_action_list $p_oacs $tailname 
                    set name "r${row}name2"
                    file stat $filenamepath att_arr
                    set c5 $att_arr(size)
                    set c6 $att_arr(mtime)
                    array unset att_arr
                    # build form row
                    qf_append html "<tr><td>"
                    qf_choice type select name "r{$row}c1" value $write_action_list
                    qf_append html "</td><td>"
                    if { $row == 1 } {
                        qf_append html "<tt>$p_url</tt></td><td>"
                    } else {
                        qf_append html "&nbsp;</td><td>"
                    }
                    qf_append html "<tt><a href=\"${p_url}/${tailname}</tt></td><td>"
                    qf_input type text value "" name "r${row}c4" label "" size 20 maxlength 25
                    qf_append html "</td><td>$c5</td><td>$c6</td></tr>"
                } elseif { $fnp_is_file_p } {
                    incr row
                   # $tailname
                    set name "r${row}name2"
                    file stat $filenamepath att_arr
                    set c5 $att_arr(size)
                    set c6 $att_arr(mtime)
                    array unset att_arr
                    # build form row
                } else {
                    ns_log Error "file-utility.tcl(l350): non-file/dir item included in table. tail: $tailname path $p_oacs"
                }
                
            }
            #screen list to only include files and dirs
            # add attributes for files and dirs
            #make talbe list_of_lists
            # convert to html
            
            
            
            qf_input type submit value "Submit"
            qf_close
            set form_html [qf_read]
        }
    }
}
# end of switches


# final setup before passing to file-utility.adp
set menu_html ""
foreach item_list $menu_list {
    set label [lindex $item_list 0]
    set url [lindex $item_list 1]
    append menu_html "<a href=\"file-utility?${url}\">${label}</a>&nbsp;"
}

set user_message_html ""
foreach user_message $user_message_list {
    append user_message_html "<li>${user_message}</li>"
}
