<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
<h1>Q-Wiki Documentation</h1>

<pre>(c) 2013 by Benjamin Brink
po box 20, Marylhurst, OR 97036-0020 usa
email: kappa@dekka.com</pre>
<p>Open source <a href="LICENSE.html">License under GNU GPL</a></p>
<pre>
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
</pre>
<h2>introduction</h2>
<p>
Q-Wiki is an OpenACS wiki using a templating system that allows tcl procedures to be used in a web-based publishing environment
 without being tied to other applications, such as ecommerce.
</p>
<p>
Q-Wiki is derived from OpenACS' ecommerce package with feedback from administrators that have voiced interest in having some kind of strictly filtered ACS developer support dynamics for user content.
</p>
<h2>features</h2>
<p>Pages automatically have revisioning ie multi-undo.</p>
<p>Pages must be trashed before being deleted. Trashed pages can be untrashed. Trashed pages are not published.</p>
<p>Users with create permission can also trash their own creations.</p>
<p>No UI javascript is used, so technologies with limited UI or computing power can use it.</p>
<p>Tcl procedures pass through two filters:  a list of glob expressions stating which procedures are allowed to be used, and a second list of specifically banned procedures.</p>
<p>A package parameter can switch the TCL/ADP rendering of content on or off.</p>
<p>The wiki web-app consists of a single q-wiki tcl/adp page pair and an extra unused "flags" field, which makes the app easily modifiable for custom applications.</p>
<p>Comments, keywords, and page description fields are included with each page for web-based publishing SEO optimization.</p>
<p>Extensible. More fields can be added to the page for customized applications.</p>
<h3>
An example dynamic template to hint at its capabilities:
</h3>
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
<h3>An example showing how to extend Q-wiki for customized applications.
</h3>
<p>file list and example changes:</p>
<ul><li>Modify target file and add new fields in <a href="index-extended-vuh.txt">www/index.vuh</a>.</li>
<li>Define 3 new API procs in <a href="qwbw-wiki-procs-tcl.txt">tcl/qwbw-wiki-procs.tcl</a></li>
<li>and call procs and add fields to <a href="q-wiki-extended-tcl.txt">www/q-wiki-extended.tcl</a>.</li>
<li>Make any display alterations in <a href="q-wiki-extended-adp.txt">www/q-wiki-extended.adp</a>.</li>
</ul>
<p>An example simlar to this has been fully implemented in a package called cl-custom at 
<a href="https://github.com/tekbasse/cl-custom">https://github.com/tekbasse/cl-custom</a>
</p>
<h2>Templates
</h2>
<p>Q-wiki can be setup as a template for tables (and lists and forms) as well as pages for wiki and ecommerce catalog apps.
</p>
<p>Q-wiki page content stores html for displaying a row.
$1 $2 $3 .. $9 are used to reference variable values by column number.
$1 is value for column 1 etc.
</p>
<p>A standard table row might have content like this:
</p>
<pre>
&lt;tr&gt; &lt;td&gt;$1&lt;/td&gt; &lt;td&gt;$2&lt;/td&gt; &lt;td&gt;$3&lt;/td&gt; &lt;/tr&gt;
</pre>
<p>However, TABLEs are too wide for convenient display on many small devices.
</p>
<p>Lists and DIVs that wrap using responsive style techniques are preferred.
</p>
<p>Standard workflow is to aply changes to code where html is hardcoded.
Hardcoded html makes code updates for admins a laborious task;
Admins have to re-integrate html changes into each updated code release.
In addition to the extra workload, there's always a risk that something will break in the upgrade.
</p>
<p>How can style be adjusted without hard-coding customizations? 
</p>
<p>By keeping customizations in the db. One way is by referencing page content using Q-wiki API.
And building a report (list, table etc) using OpenACS procs. 
</p>
<p>qw_template_custom_read allows column orders to be customized on up to a per user case.
This information can then be used to build reports with column in different orders etc.
Each case is set with qw_template_custom_set .
</p>
