<master>
  <property name="doc(title)">@title@</property>
  <property name="title">@title@</property>
  <property name="context">@context;noquote@</property>

<if @menu_html@ not nil>
  <p>@menu_html;noquote@</p>
</if>

<if @user_message_html@ not nil>
<ul>
  @user_message_html;noquote@
</ul>
</if>

<if @form_html@ not nil>
 @form_html;noquote@
</if>

<if @page_stats_html@ not nil>
 @page_stats_html;noquote@
</if>

<if @page_trashed_html@ not nil>
 @page_trashed_html;noquote@
</if>

<if @page_main_code_html@ not nil>
 @page_main_code_html;noquote@
</if>



