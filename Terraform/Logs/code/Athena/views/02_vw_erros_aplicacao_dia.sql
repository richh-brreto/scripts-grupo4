-- View: erros por dia, serviço e tipo de exceção (backend Spring, MySQL e demais containers)
CREATE OR REPLACE VIEW boost_logs.vw_erros_aplicacao_dia AS
SELECT
  dt,
  servico,
  coalesce(excecao, logger, 'sem-classificacao')                AS origem_erro,
  count(*)                                                      AS ocorrencias,
  count(DISTINCT node)                                          AS maquinas,
  min(ts)                                                       AS primeira_ocorrencia,
  max(ts)                                                       AS ultima_ocorrencia,
  max(mensagem)                                                 AS exemplo_mensagem
FROM boost_logs.silver_containers
WHERE is_erro
GROUP BY 1, 2, 3
