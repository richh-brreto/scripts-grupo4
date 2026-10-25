-- Eventos do sistema operacional com prioridade err ou pior (ex.: OOM killer)
SELECT
  ts,
  node,
  categoria,
  programa,
  nivel,
  mensagem
FROM boost_logs.silver_sistema
WHERE is_erro
ORDER BY ts DESC
LIMIT 100
