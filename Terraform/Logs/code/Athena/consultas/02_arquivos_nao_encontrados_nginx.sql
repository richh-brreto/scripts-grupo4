-- Caminhos que o nginx tentou abrir no disco do container e não achou (error log)
SELECT
  arquivo_nao_encontrado,
  count(*)   AS ocorrencias,
  max(ts)    AS ultima_vez
FROM boost_logs.silver_nginx
WHERE tipo = 'error'
  AND arquivo_nao_encontrado IS NOT NULL
GROUP BY 1
ORDER BY ocorrencias DESC
