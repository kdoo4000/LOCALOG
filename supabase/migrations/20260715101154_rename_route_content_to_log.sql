update public.routes
set title = replace(replace(title, '루트', '로그'), 'Route', 'Log'),
    description = replace(
      replace(description, '루트', '로그'),
      'Route',
      'Log'
    )
where title like '%루트%'
   or title like '%Route%'
   or description like '%루트%'
   or description like '%Route%';

update public.route_places
set memo = replace(replace(memo, '루트', '로그'), 'Route', 'Log')
where memo like '%루트%'
   or memo like '%Route%';
update public.routes
set title = replace(replace(title, '루트', '로그'), 'Route', 'Log'),
    description = replace(
      replace(description, '루트', '로그'),
      'Route',
      'Log'
    )
where title like '%루트%'
   or title like '%Route%'
   or description like '%루트%'
   or description like '%Route%';

update public.route_places
set memo = replace(replace(memo, '루트', '로그'), 'Route', 'Log')
where memo like '%루트%'
   or memo like '%Route%';
