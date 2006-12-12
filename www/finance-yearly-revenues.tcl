# /packages/intranet-reporting/www/finance-yearly-revenues.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.


ad_page_contract {
	testing reports	
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { start_date "" }
    { end_date "" }
    { cost_creation_user_id 0 }
    { customer_type_id:integer 0 }
    { customer_id:integer 0 }
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set menu_label "reporting-finance-yearly-revenues"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

set read_p "t"

if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
[lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

# Check that Start & End-Date have correct format
if {"" != $start_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {"" != $end_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}


# ------------------------------------------------------------
# Page Settings

set grey "grey"

set page_title [lang::message::lookup "" intranet-reporting.Yearly_Revenues_by_Project_Type "Yearly Revenues by Project Type"]
set context_bar [im_context_bar $page_title]
set context ""
set help_text "<strong>$page_title</strong><br>

This report shows the evolution of sales of different service 
types on a monthly scale.<br>

The purpose of this report is to check if customers suddenly stop
to purchase certain service types and start buying something else.
An example could be a customer that still buys one type of service,
while changing the provider for a different type of service.
"



# ------------------------------------------------------------
# Defaults

set rowclass(0) "roweven"
set rowclass(1) "rowodd"

set days_in_past 7

set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set cur_format [im_l10n_sql_currency_format]
set date_format [im_l10n_sql_date_format]

db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month,
	to_char(sysdate::date - :days_in_past::integer, 'DD') as todays_day
from dual
"

if {"" == $start_date} { 
    set start_date "$todays_year-$todays_month-01"
}

db_1row end_date "
select
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'YYYY') as end_year,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'MM') as end_month,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'DD') as end_day
from dual
"

if {"" == $end_date} { 
    set end_date "$end_year-$end_month-01"
}


set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting/finance-quotes-pos" {start_date end_date} ]


# ------------------------------------------------------------
# Options

set start_years {2000 2000 2001 2001 2002 2002 2003 2003 2004 2004 2005 2005 2006 2006}
set start_months {01 Jan 02 Feb 03 Mar 04 Apr 05 May 06 Jun 07 Jul 08 Aug 09 Sep 10 Oct 11 Nov 12 Dec}
set start_weeks {01 1 02 2 03 3 04 4 05 5 06 6 07 7 08 8 09 9 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19 20 20 21 21 22 22 23 23 24 24 25 25 26 26 27 27 28 28 29 29 30 30 31 31 32 32 33 33 34 34 35 35 36 36 37 37 38 38 39 39 40 40 41 41 42 42 43 43 44 44 45 45 46 46 47 47 48 48 49 49 50 50 51 51 52 52}
set start_days {01 1 02 2 03 3 04 4 05 5 06 6 07 7 08 8 09 9 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19 20 20 21 21 22 22 23 23 24 24 25 25 26 26 27 27 28 28 29 29 30 30 31 31}


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {0 != $customer_id} {
    lappend criteria "pcust.company_id = :customer_id"
}

if {0 != $cost_creation_user_id} {
    lappend criteria "creation_user = :cost_creation_user_id"
}

if {"" != $customer_type_id && 0 != $customer_type_id} {
    lappend criteria "pcust.company_type_id in (
	select	child_id
	from	im_category_hierarchy
	where	(parent_id = :customer_type_id or child_id = :customer_type_id)
    )"
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#


set inner_sql "
	select
		c.*,
		round((c.paid_amount * 
		  im_exchange_rate(c.effective_date::date, c.currency, 'EUR')) :: numeric
		  , 2) as paid_amount_converted,
		round((c.amount * 
		  im_exchange_rate(c.effective_date::date, c.currency, 'EUR')) :: numeric
		  , 2) as amount_converted,
		p.project_id
	from
		im_costs c
		LEFT OUTER JOIN (
			select	p.project_id,
				p.project_type_id,
				r.object_id_two as cost_id
			from
				im_projects p,
				acs_rels r
			where
				 r.object_id_one = p.project_id
		) p ON (c.cost_id = p.cost_id)
	where
		c.cost_type_id in (3700, 3702, 3724)
		and c.cost_type_id in (3700)
"


set sql "
select
	c.*,
	to_char(c.effective_date, :date_format) as effective_date_formatted,
	to_char(c.effective_date, 'YYMM')::integer * customer_id as effective_month,
	substring(c.cost_name, 1, 14) as cost_name_cut,
	CASE WHEN c.cost_type_id = 3700 THEN c.amount_converted END as invoice_amount,
	CASE WHEN c.cost_type_id = 3702 THEN c.amount_converted END as quote_amount,
	CASE WHEN c.cost_type_id = 3724 THEN c.amount_converted END as delnote_amount,
	p.project_name,
	p.project_nr
from
	($inner_sql) c
	LEFT OUTER JOIN im_projects p ON (c.project_id = p.project_id)
where
	1 = 1
	$where_clause
order by
	pcust.company_name,
	p.project_name
"


# ------------------------------------------------------------
# Start formatting the page
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format "html"

ns_write "
[im_header]
[im_navbar]
<table cellspacing=0 cellpadding=0 border=0>
<tr valign=top>
<td>
<form>
	[export_form_vars project_id]
	<table border=0 cellspacing=1 cellpadding=1>
	<tr>
	  <td class=form-label>Start Date</td>
	  <td class=form-widget>
	    <input type=textfield name=start_date value=$start_date>
	  </td>
	</tr>
	<tr>
	  <td class=form-label>End Date</td>
	  <td class=form-widget>
	    <input type=textfield name=end_date value=$end_date>
	  </td>
	</tr>
	<tr>
	  <td class=form-label></td>
	  <td class=form-widget><input type=submit value=Submit></td>
	</tr>
	</table>
</form>
</td>
<td>
	<table cellspacing=2 width=90%>
	<tr><td>$help_text</td></tr>
	</table>
</td>
</tr>
</table>
<table border=0 cellspacing=1 cellpadding=1>
"


# ------------------------------------------------------------
# Execute query and read values into a Hash array

db_foreach query $sql {

    # Sum up the values for the matrix cells
    set key "${effective_month}.${project_type_id}"
    set sum 0
    if {[info exists hash($key)]} { set sum $hash($key) }
    set sum [expr sum + $amount_converted]
    set hash($key) $sum

    # Get the list of distinct keys for the left dimension
    set left_key ${effective_month}
    set left($left_key) $left_key

    # Get the list of distinct keys for the top dimension
    set top_key ${project_type_id}
    set top($top_key) $top_key

}


# ------------------------------------------------------------
# Display the contents of the Hash array

ns_write "<tr><td>&nbsp;</td>\n"
foreach key [array names top] {
    ns_write "<td class=rowtitle>$key</td>\n"
}
ns_write "</tr>\n"




ns_write "</table>\n[im_footer]\n"


