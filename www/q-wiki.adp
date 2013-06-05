<master>
  <property name="doc(title)">@title@</property>
  <property name="title">@title@</property>
  <property name="context">@context;noquote@</property>


<if @menu_html@ not nil>
  <div style="text-align: right; margin: 0; padding: 0;">@menu_html;noquote@</div>
</if>
<h1>@title@</h1>
<if @user_message_html@ not nil>
<ul>
  @user_message_html;noquote@
</ul>
</if>

<if @form_html@ not nil>
 @form_html;noquote@
</if>

<if @page_stats_html@ not nil>
 <h3>#acs-admin.Pages#</h3>
 @page_stats_html;noquote@
</if>

<if @page_trashed_html@ not nil>
<h3>#acs-kernel.member_state_Deleted#</h3>
 @page_trashed_html;noquote@
</if>

<if @page_main_code_html@ not nil>
 @page_main_code_html;noquote@
</if>



