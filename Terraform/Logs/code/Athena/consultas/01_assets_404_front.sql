-- Imagens/arquivos estáticos do front que retornam 404 (diagnóstico do problema de caminhos do front)
SELECT
  path,
  extensao,
  count(*)                     AS ocorrencias,
  count(DISTINCT ip_cliente)   AS clientes_afetados,
  max(referer)                 AS pagina_que_pediu,
  min(ts)                      AS primeira_vez,
  max(ts)                      AS ultima_vez
FROM boost_logs.silver_nginx
WHERE tipo = 'access'
  AND status = 404
  AND is_asset
  AND dt >= cast(current_date - interval '7' day AS varchar)
GROUP BY 1, 2
ORDER BY ocorrencias DESC
LIMIT 50
