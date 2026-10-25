-- View: tentativas de acesso SSH por IP de origem
CREATE OR REPLACE VIEW boost_logs.vw_seguranca_ssh AS
SELECT
  ip_origem,
  count_if(evento_ssh = 'falha')                                AS falhas,
  count_if(evento_ssh = 'sucesso')                              AS sucessos,
  count(DISTINCT node)                                          AS maquinas_alvo,
  min(ts)                                                       AS primeira_tentativa,
  max(ts)                                                       AS ultima_tentativa
FROM boost_logs.silver_sistema
WHERE categoria = 'auth' AND evento_ssh IS NOT NULL
GROUP BY 1
