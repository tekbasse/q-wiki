<master>
    <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
<h1>@title@</h1>
<if @menu_html@ not nil>
@menu_html;noquote@
</if>

<if @user_message_html@ not nil>
<ul>
@user_message_html;noquote@
</ul>
</if>


<if @form_html@ not nil>
@form_html;noquote@
</if>

<if @initial_conditions_html@ not nil>
<div style="width: 60%; float: right;">
<table border="0" cellspacing="0" cellpadding="5">
<tr>
<td valign="top"><tt>y1</tt></td>
<td valign="top">The low limit of Y.
 </td>
</tr><tr>
<td valign="top"><tt>y2</tt></td>
<td valign="top">The high limit of Y.
 </td>
</tr><tr>
<td valign="top"><tt>yc</tt></td>
<td valign="top">The number of points evenly distributed on the Y axis.
 </td>
</tr><tr>
<td valign="top"><tt>x1</tt></td>
<td valign="top">The low limit of X.
 </td>
</tr><tr>
<td valign="top"><tt>x2</tt></td>
<td valign="top">The high limit of X.
 </td>
</tr><tr>
<td valign="top"><tt>xc</tt></td>
<td valign="top">The number of points evenly distributed on the X axis.
 </td>
</tr></table>
</div>
@initial_conditions_html;noquote@
</if>


<if @compute_message_html@ not nil>
<ul>
@compute_message_html;noquote@
</ul>
</if>

<if @computation_report_html@ not nil>
@computation_report_html;noquote@
</if>

<if @table_stats_html@ not nil>
@table_stats_html;noquote@
</if>

