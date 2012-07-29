-- q-wiki-drop.sql
--
-- @author Dekka Corp.
-- @for OpenACS.org
-- @cvs-id
--
drop index qw_page_url_map_url_idx;
drop index qw_page_url_map_page_id_idx;
drop table qw_page_url_map;

drop index qw_wiki_page_trashed_idx;
drop index qw_wiki_page_user_id_idx;
drop index qw_wiki_page_instance_id_idx;
drop index qw_wiki_page_template_id_idx;
drop index qw_wiki_page_id_idx;
drop table qw_wiki_page;

drop sequence qw_page_id_seq;
drop table qw_page_object_id_map;

