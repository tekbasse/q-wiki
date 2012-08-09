<master>
  <property name="doc(title)">@title;noquote@</property>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>

<if @menu_html@ not nil>
  @menu_html;noquote@
</if>

<if @user_message_html@ not nil>
  @user_message_html;noquote@
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

<if @page_contents_filtered@ not nil>
  @page_contents_filtered;noquote@
</if>
<if @page_html@ not nil>
  @page_html;noquote@
</if>


