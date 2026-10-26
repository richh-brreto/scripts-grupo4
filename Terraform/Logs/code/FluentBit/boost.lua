-- =====================================================================
--  Funções Lua usadas pelo Fluent Bit - Boost Your English (Grupo 4)
--  Retorno 2 = registro modificado mantendo o timestamp original.
-- =====================================================================

-- Descobre o serviço a partir do nome do container. Cobre os nomes do
-- docker-compose (backend-grupo4, frontend-g4, boost-db) e do Swarm
-- (backend.1.xxxx, frontend.2.yyyy).
local function servico_de(nome)
  local n = string.lower(nome or "")
  if n == "" then return "outros" end
  if n:find("front") then return "frontend" end
  if n:find("back") then return "backend" end
  if n:find("mysql") or n:find("db") or n:find("banco") then return "mysql" end
  return "outros"
end

-- Linha no formato de acesso do nginx: IP - usuario [data] "METODO ...
local function eh_nginx_access(linha)
  return linha:match('^%S+ %- %S+ %[[^%]]+%] "') ~= nil
end

-- Linha no formato de erro do nginx: 2026/10/07 21:00:00 [error] ...
local function eh_nginx_error(linha)
  return linha:match('^%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d %[%a+%]') ~= nil
end

function classificar_container(tag, ts, record)
  local nome = record["container_name"]

  if nome == nil then
    -- veio do tail de /var/log/nginx no host
    record["container_name"] = "host"
    record["servico"] = "nginx-host"
    record["stream"] = "file"
  else
    nome = nome:gsub("^/", "")
    record["container_name"] = nome
    record["servico"] = servico_de(nome)
    -- o driver fluentd do Docker chama de "source" (stdout/stderr)
    record["stream"] = record["source"]
    record["source"] = nil
  end

  local linha = record["log"] or ""
  -- remove \r\n finais que alguns containers deixam
  linha = linha:gsub("[\r\n]+$", "")
  record["log"] = linha

  if eh_nginx_access(linha) then
    record["tipo_log"] = "nginx_access"
  elseif eh_nginx_error(linha) then
    record["tipo_log"] = "nginx_error"
  else
    record["tipo_log"] = "container"
  end

  return 2, ts, record
end

-- Prioridade syslog (0..7) -> nome
local NIVEIS = { [0]="emerg", [1]="alert", [2]="crit", [3]="err",
                 [4]="warning", [5]="notice", [6]="info", [7]="debug" }

-- Programas cujos logs são de autenticação/acesso
local AUTH = { sshd=true, sudo=true, su=true, login=true,
               ["systemd-logind"]=true, ["pam_unix"]=true, passwd=true,
               useradd=true, usermod=true, groupadd=true, chpasswd=true }

function classificar_sistema(tag, ts, record)
  local ident = record["syslog_identifier"] or ""
  local transporte = record["transport"] or ""

  if transporte == "kernel" or ident == "kernel" then
    record["categoria"] = "kernel"
  elseif AUTH[ident] then
    record["categoria"] = "auth"
  else
    record["categoria"] = "geral"
  end

  local p = tonumber(record["priority"])
  if p ~= nil then
    record["priority"] = p
    record["nivel"] = NIVEIS[p] or "desconhecido"
  end

  return 2, ts, record
end
