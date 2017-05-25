--------------------------------------------
--- get all available information on the 'completed' buildings
select * from asset.ve_object o 
where 
o.survey_gid=6 and 
o.rrvs_status='COMPLETED';

--------------------------------------------
--- get all available information on the 'completed' buildings for a specific user
select o.* from asset.ve_object o,
users.users u,
users.tasks_users tu,
users.tasks t,
asset.object_attribute oa
where 
u.id = tu.user_id and 
tu.task_id = t.id and
o.gid = any( t.bdg_gids ) and 
oa.object_id=o.gid and
o.survey_gid = 6 and 
oa.attribute_type_code = 'RRVS_STATUS' and 
oa.attribute_value = 'COMPLETED' and
u.name='Tobias';


--------------------------------------------
---
--- NOTE: This is only a collection of sql snippets to 
---       query the centralized database and inquire 
---       about the survey progression
---
---	M. Pittore, May 25, 2017
--------------------------------------------


--------------------------------------------
--- get a basic statistics on the individual users
select count(u.id), u.name from
users.users u,
users.tasks_users tu,
users.tasks t,
asset.object_attribute oa, 
asset.object o
where 
u.id = tu.user_id and 
tu.task_id = t.id and
o.gid = any( t.bdg_gids ) and 
oa.object_id=o.gid and
o.survey_gid = 6 and 
oa.attribute_type_code = 'RRVS_STATUS' and 
oa.attribute_value = 'COMPLETED'
group by u.name order by count desc;--- limit 2;

--------------------------------------------
--- basic information on the completed buildings
select count(*) from 
asset.object_attribute oa,
asset.object o
where 
oa.object_id=o.gid and
o.survey_gid = 6 and 
oa.attribute_type_code = 'RRVS_STATUS' and 
oa.attribute_value = 'COMPLETED';

--------------------------------------------

select oq.* from 
asset.object o,
asset.object_attribute oa,
asset.object_attribute_qualifier oq
where 
oa.object_id = o.gid and
oq.attribute_id = oa.gid and
o.survey_gid = 6;
