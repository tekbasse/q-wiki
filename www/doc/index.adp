<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>

<h3>introduction</h3>
<p>
Q-Wiki is an OpenACS wiki using a templating system that allows tcl procedures to be used in a web-based publishing environment
 without being tied to other applications, such as ecommerce.
</p>
<p>
Q-Wiki is derived from OpenACS' ecommerce package with feedback from administrators that have voiced interest in having some kind of strictly filtered ACS developer support dynamics for user content.
</p>
<h3>features</h3>
<p>Pages automatically have revisioning.</p>
<p>Pages must be trashed before being deleted. Trashed pages can be untrashed. Trashed pages are not published.</p>
<p>Users with create permission can also trash their own creations.</p>
<p>No UI javascript is used, so technologies with limited UI or computing power can use it.</p>
<p>Tcl procedures pass through two filters:  a list of glob expressions stating which procedures are allowed to be used, and a second list of specifically banned procedures.</p>
<p>A package parameter can switch the TCL/ADP rendering of content on or off.</p>
<p>The wiki web-app consists of a single q-wiki tcl/adp page pair and an extra unused "flags" field, which makes the app easily modifiable for custom applications.</p>
<p>Comments, keywords, and page description fields are included with each page for web-based publishing SEO optimization.</p>
<p>
Here is an example dynamic template to hint at its capabilities:
<p>
<hr>
<pre>
&lt;%
    set contributors_list [qw_contributors]
    set pretty_contributors_list [template::util::tcl_to_sql_list $contributors_list]
    set user_id [lindex $contributors_list 0]
    set user_name [person::name -person_id $user_id] 
    set pages_of_user_list [qw_user_contributions $user_id] 
    set pages_of_user [template::util::tcl_to_sql_list $pages_of_user_list]
%&gt;
&lt;p&gt;
  Wiki last edited on: &lt;%= [lindex [qw_most_recent_edit_stats ] 1] %&gt;
&lt;/p&gt;
&lt;p&gt;
  Contributor user numbers: \@pretty_contributors_list\@
&lt;/p&gt;

&lt;p&gt;
  Most recent contributor, \@user_name\@, 
  made these contributions: \@pages_of_user\@.
&lt;/p&gt;
</pre>
<hr>
<p>And here's the output for a test installation:</p>
<p>
Wiki last edited on: 2013-03-12 17:46:20.250505+00
</p>
<p>
Contributor user numbers: '667'
</p>

<p>Most recent contributor, Admin for or97 net, 
made these contributions: '10222', '10221', '10220', '10219', '10218', '10217', '10216', '10215', '10214', '10213', '10212', '10211', '10210', '10209', '10208', '10207', '10206', '10205', '10204', '10203', '10202', '10201', '10200', '10199', '10198', '10197', '10196', '10195', '10194', '10193'.</p>

<hr>
