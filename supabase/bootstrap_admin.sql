-- Run after creating the admin user in Supabase Authentication > Users. Replace the email and run once.
insert into public.profiles(user_id,email,full_name,role,is_active)
select id,email,'مدير النظام','admin',true from auth.users
where lower(email)=lower('YOUR_ADMIN_EMAIL@example.com')
on conflict(user_id) do update set role='admin',is_active=true,email=excluded.email;
select user_id,email,role,is_active from public.profiles where role='admin';
