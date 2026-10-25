-- View: saúde do front (nginx) por hora, sem health checks do ALB
CREATE OR REPLACE VIEW boost_logs.vw_saude_http_hora AS
SELECT
  date_trunc('hour', ts)                                        AS hora_utc,
  node,
  count(*)                                                      AS requisicoes,
  count_if(status BETWEEN 400 AND 499)                          AS erros_4xx,
  count_if(status >= 500)                                       AS erros_5xx,
  count_if(status = 404 AND is_asset)                           AS assets_404,
  round(100.0 * count_if(status >= 400) / count(*), 2)          AS pct_erro,
  sum(bytes)                                                    AS bytes_enviados,
  count(DISTINCT ip_cliente)                                    AS clientes_unicos
FROM boost_logs.silver_nginx
WHERE tipo = 'access' AND NOT is_healthcheck
GROUP BY 1, 2
