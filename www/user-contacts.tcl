# /packages/intranet-reporting/www/user-contacts.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.

ad_page_contract {
    Shows a list of all users in the system, together with
    their contact information, 
} {
    { level_of_detail:integer 3 }
    { company_id 0 }
    { filter_company_type_id 0 }
    { profile_id ""}
    { output_format "html" }
    { redirect_p "1" }
    { page 0}
    { limit 1000 }
}

# set current_user_id [ad_maybe_redirect_for_registration]
set current_user_id [ad_get_user_id]
set menu_label "reporting-user-contacts"
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

if {![string equal "t" $read_p]} {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }


set return_url [im_url_with_query]
set role_id 1300
set object_id 0
set notify_asignee 1

set offset [expr $page * $limit]

# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#

set page_title [lang::message::lookup "" intranet-reporting_Users_and_Contacts "Users and Contacts"]
set context_bar [im_context_bar $page_title]
set help_text [lang::message::lookup "" intranet-reporting_Users_and_Contacts_help "
	<strong>Users and Contacts:</strong><br>
        This report shows all users in the system, together with
        their state and their contact details.
"]


# ------------------------------------------------------------
# Default Values and Constants
#

set rowclass(0) "roweven"
set rowclass(1) "rowodd"
set class "roweven"

set currency_format [im_l10n_sql_currency_format]
set date_format [im_l10n_sql_date_format]
set levels {3 "All Details"} 
set limits {1 1 10 10 100 100 1000 1000 10000 10000 100000 100000}

set company_url "/intranet/companies/view?company_id="
set user_url "/intranet/users/view?user_id="
set this_url "/intranet-reporting/user-contacts?"

set pages [list]
for {set i 0} {$i < 100} {incr i} { 
    lappend pages $i
    lappend pages $i
}

# ------------------------------------------------------------
# Report SQL

set filter_sql ""
if {"" != $company_id && 0 != $company_id} {
    set filter_sql "and c.company_id = :company_id\n"
}

if {"" != $filter_company_type_id && 0 != $filter_company_type_id} {
    append filter_sql "and c.company_type_id = :filter_company_type_id\n"
}

if {"" != $profile_id && 0 != $profile_id} {
    append filter_sql "and u.user_id in (select member_id from group_distinct_member_map where group_id = :profile_id)\n"
}

set nospam_sql ""
if {[im_column_exists persons spam_frequency_id]} {
    set nospam_sql "and pe.spam_frequency_id != 11130"
}

set report_sql "
select	t.*,
	c.*,
	im_category_from_id(c.company_status_id) as company_status,
	im_category_from_id(c.company_type_id) as company_type
from	(select	
		p.email,
		pe.*,
		uc.*,
		u.*,
		(	select	min(company_id) 
			from	im_companies c, 
				acs_rels r 
			where	u.user_id = r.object_id_two and 
				r.object_id_one = c.company_id and
				c.company_type_id not in (select * from im_sub_categories([im_company_type_provider]))
		) as company_id,
		im_name_from_user_id(u.user_id) as user_name,
		im_country_from_code(uc.ha_country_code) as ha_country,
		im_country_from_code(uc.wa_country_code) as wa_country,
		(select 'e' from group_distinct_member_map gdmm where gdmm.group_id = 463 and gdmm.member_id = u.user_id) as employee_p,
		(select 'c' from group_distinct_member_map gdmm where gdmm.group_id = 461 and gdmm.member_id = u.user_id) as customer_p,
		(select 'f' from group_distinct_member_map gdmm where gdmm.group_id = 465 and gdmm.member_id = u.user_id) as freelancer_p
	from
		parties p,
		persons pe,
		users u
		LEFT OUTER JOIN users_contact uc ON (u.user_id = uc.user_id)
	where
		u.user_id = p.party_id and
		u.user_id = pe.person_id
		$nospam_sql
		$filter_sql
	) t
	LEFT OUTER JOIN im_companies c ON (t.company_id = c.company_id)
where   1=1
order by
	company_type_id,
	company_name,
	user_name
LIMIT	:limit
OFFSET	:offset
"


# ------------------------------------------------------------
# Report Definition
#


# Global Header Line
set header0 [list \
		 "<input type=checkbox name=_dummy onclick=\\\"acs_ListCheckAll('user',this.checked)\\\">" \
		 [lang::message::lookup "" intranet-reporting.Company_short Comp]  \
		 [lang::message::lookup "" intranet-reporting.Customer_oneletter "C"] \
		 [lang::message::lookup "" intranet-reporting.Employee_oneletter "E"] \
		 [lang::message::lookup "" intranet-reporting.Freelancer_oneletter "F"] \
		 [_ intranet-core.Email] \
		 [_ intranet-core.Name] \
		 [_ intranet-core.Home_phone] \
		 [_ intranet-core.Work_phone] \
		 [_ intranet-core.Cell_phone] \
		 [_ intranet-core.Pager] \
		 [_ intranet-core.Fax] \
		 [_ intranet-core.Aim_Screen_Name] \
		 [lang::message::lookup "" intranet-core.MSN "MSN"] \
		 [_ intranet-core.ICQ_Number] \
		 [_ intranet-core.Home_Country] \
		 [_ intranet-core.Work_Country] \
		 [_ intranet-core.Note] \
		]



# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by company_type_id \
    header {
	"\#colspan=18 <a href=$this_url&company_type_id=$company_type_id&level_of_detail=4 
	target=_blank><img src=/intranet/images/plus_9.gif width=9 height=9 border=0></a> 
	<b>$company_type</b>"
    } \
        content [list \
            group_by company_id \
            header { 
		""
		"\#colspan=17 <a href='$company_url$company_id'>$company_name</a>"
	    } \
	    content [list \
		    header {
			"<input type=checkbox name=user_id_from_search value=$user_id id=user,$user_id>"
			""
			"$customer_p"
			"$employee_p"
			"$freelancer_p"
			"$email"
			"<a href=$user_url$user_id>$user_name</a>"
			"$home_phone"
			"$work_phone"
			"$cell_phone"
			"$pager"
			"$fax"
			"$aim_screen_name"
			"$msn_screen_name"
			"$icq_number"
			"$ha"
			"$wa"
			"$note"
		    } \
		    content {} \
	    ] \
            footer {} \
    ] \
    footer {} \
]

# Global Footer Line
set footer0 {
	"" 
	"" 
	""
	""
	""
	""
	""
	""
	""
	""
	""
	"" 
	"" 
	"" 
	"" 
	"" 
	"" 
	"" 
}


# ------------------------------------------------------------
# Counters
#

set counters [list]

# Set the values to 0 as default (New!)


# ------------------------------------------------------------
# Start Formatting the HTML Page Contents

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -report_name $menu_label -output_format $output_format

switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td width='30%'>
		<form>
		<table cellspacing=2>
		<tr class=rowtitle>
		  <td class=rowtitle colspan=2 align=center>[lang::message::lookup "" intranet-core.Filters "Filters"]</td>
		</tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-reporting.Level_of_Detail "Level of<br>Detail"]</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>[_ intranet-core.Company_Type]</td>
		  <td class=form-widget>
		    [im_category_select -include_empty_p 1 "Intranet Company Type" filter_company_type_id $filter_company_type_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-core.User_Profile "User Profile"]</td>
		  <td class=form-widget>
		    [im_select -ad_form_option_list_style_p 1 profile_id [im_profile::profile_options_all -include_empty_p 1 -include_empty_name [_ intranet-core.All]] $profile_id]
		  </td>
		</tr>

		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-core.Pagination Pagination]</td>
		  <td class=form-widget>
		    [lang::message::lookup "" intranet-reporting.Entries_per_Page "Entries per Page"]:
		    [im_select -translate_p 0 limit $limits $limit]
		    [lang::message::lookup "" intranet-reporting.Page Page]:
		    [im_select -translate_p 0 page $pages $page]
		  </td>
		</tr>


		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-reporting.Format Format]</td>
		  <td class=form-widget>
		    [im_report_output_format_select output_format "" $output_format]
		  </td>
		</tr>

		<tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value='[_ intranet-core.Submit]'></td>
		</tr>
		</table>
		</form>
	  </td>
	  <td align=center>
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	  </td>
	</tr>
	</table>
	
	<!-- Here starts the main report table -->
	<form action='/intranet/member-add-2' method=POST>
	[export_form_vars return_url role_id object_id notify_asignee]
	<table border=0 cellspacing=1 cellpadding=1>
        "
    }
    default { }
}



# ------------------------------------------------------
# The following report loop is "magic"

set footer_array_list [list]
set last_value_list [list]

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set counter 0
db_foreach sql $report_sql {

    set company_type [im_category_from_id $company_type_id]
    set company_status [im_category_from_id $company_status_id]

	set ha_list [list]
	if {"" != $ha_line1} { lappend ha_list $ha_line1 }
	if {"" != $ha_line2} { lappend ha_list $ha_line2 }
	if {"" != $ha_postal_code} { lappend ha_list $ha_postal_code }
	if {"" != $ha_city} { lappend ha_list $ha_city }
	if {"" != $ha_state} { lappend ha_list $ha_state }
	if {"" != $ha_country} { lappend ha_list $ha_country }
	set ha [join $ha_list ", "]

	set wa_list [list]
	if {"" != $wa_line1} { lappend wa_list $wa_line1 }
	if {"" != $wa_line2} { lappend wa_list $wa_line2 }
	if {"" != $wa_postal_code} { lappend wa_list $wa_postal_code }
	if {"" != $wa_city} { lappend wa_list $wa_city }
	if {"" != $wa_state} { lappend wa_list $wa_state }
	if {"" != $wa_country} { lappend wa_list $wa_country }
	set wa [join $wa_list ", "]

	# Select either "roweven" or "rowodd" from
	# a "hash", depending on the value of "counter".
	# You need explicite evaluation ("expre") in TCL
	# to calculate arithmetic expressions. 
	set class $rowclass([expr $counter % 2])

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	im_report_update_counters -counters $counters

	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	set footer_array_list [im_report_render_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	incr counter
}

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1


# Write out the HTMl to close the main report table
# and write out the page footer.
#
switch $output_format {
    html { 
        ns_write "
	</table>
	<tr><td colspan=99>
	<input type=submit>
	</td></tr>
	</form>
	[im_footer]
	"
    }
}
