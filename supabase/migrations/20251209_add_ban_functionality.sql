-- 1. Agregar columna de estado a la tabla profiles (si no existe)
alter table profiles 
add column if not exists status text default 'active';

-- 2. Crear función para banear/desbanear usuarios
create or replace function toggle_ban(user_id uuid, new_status text)
returns void
language plpgsql
security definer
as $$
begin
  update profiles
  set status = new_status
  where id = user_id;
end;
$$;