# /packages/intranet-reporting/www/new.tcl
#
# Copyright (c) 2003-2007 ]project-open[
# all@devcon.project-open.com
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract {
    New page is basic...
    @author frank.bergmann@project-open.com
} {
    report_id:integer,optional
    {return_url "/intranet-reporting/index"}
    {form_mode "edit"}
}

if {[info exists var_name]} { ad_return_complaint 1 "var_name = $var_name" }

set user_id [ad_maybe_redirect_for_registration]
set page_title [lang::message::lookup "" intranet-reporting.New_Report "New Report"]
set context [im_context_bar $page_title]


# ---------------------------------------------------------------
# Options

set project_options [im_project_options]

set report_type_options [db_list_of_lists report_type_options "
	select	report_type, report_type_id
	from	im_report_types
	order by report_type_id
"]

set parent_menu_options [db_list_of_lists parent_menu_options "
	select	m.name, m.menu_id
	from	im_menus m
	where	parent_menu_id in (
			select	menu_id
			from	im_menus
			where 	label = 'reporting'
		)
"]


# ---------------------------------------------------------------
# Setup the form

set form_id "form"
ad_form \
    -name $form_id \
    -mode $form_mode \
    -export "return_url" \
    -form {
	report_id:key
	{report_name:text(text) {label "[lang::message::lookup {} intranet-reporting.Report_Name {Report Name}]"} {html {size 60}}}
	{parent_menu_id:text(select) {label "[lang::message::lookup {} intranet-reporting.Report_Group {Report Group}]"} {options $parent_menu_options} }
	{report_type_id:text(select) {label "[lang::message::lookup {} intranet-reporting.Reports_Type Type]"} {options $report_type_options} }
	{sort_order:integer(text),optional {label "[lang::message::lookup {} intranet-reporting.Report_Sort_Order {Sort Order}]"}}
	{report_sql:text(textarea) {label "[lang::message::lookup {} intranet-reporting.Reports_SQL {Report SQL}]"} {html {cols 60 rows 10} }}
    }

ad_form -extend -name $form_id \
    -select_query {
	select	*
	from	im_reports
	where	report_id = :report_id
    } -new_data {

	set report_id [db_nextval "acs_object_id_seq"]
	set package_name "intranet-reporting"
	set label [im_mangle_user_group_name $report_name]
	set name $report_name
	set url "/intranet-reporting/run?report_id=$report_id"
	if {![info exists sort_order] || "" == $sort_order} { set sort_order 100 }

	set report_menu_id [db_exec_plsql menu_new "
        	SELECT im_menu__new (
        	        null,                   -- p_menu_id
        	        'im_menu',              -- object_type
        	        now(),                  -- creation_date
        	        null,                   -- creation_user
        	        null,                   -- creation_ip
        	        null,                   -- context_id

        	        :package_name,          -- package_name
        	        :label,                 -- label
        	        :name,                  -- name
        	        :url,                   -- url
        	        :sort_order,            -- sort_order
        	        :parent_menu_id,	-- parent_menu_id
        	        null                    -- p_visible_tcl
        	)
	"]

	db_exec_plsql create_report "
		SELECT im_report__new(
			:report_id,
			'im_report',
			now(),
			:user_id,
			'[ad_conn peeraddr]',
			null,

			:report_name,
			:report_type_id,
			[im_report_status_active],
			:report_menu_id,
			:report_sql::text
		)
        "
    } -edit_data {
	db_dml edit_report "
		update im_reports
		set report = :report_name
		where report_id = :report_id
	"
    } -after_submit {
	ad_returnredirect $return_url
	ad_script_abort
    }

