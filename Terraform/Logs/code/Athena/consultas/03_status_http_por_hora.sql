-- Distribuição de status HTTP por hora (UTC), excluindo health checks
SELECT
  date_trunc('hour', ts)   AS hora_utc,
  status_classe,
  count(*)                 AS requisicoes
FROM boost_logs.silver_nginx
WHERE tipo = 'access'
  AND NOT is_healthcheck
GROUP BY 1, 2
ORDER BY 1, 2
