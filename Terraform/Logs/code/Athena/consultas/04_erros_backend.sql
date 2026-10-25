-- Erros do backend Spring Boot, com a exceção e a primeira linha da mensagem
SELECT
  ts,
  node,
  container,
  thread,
  logger,
  excecao,
  mensagem,
  tem_stacktrace
FROM boost_logs.silver_containers
WHERE servico = 'backend'
  AND is_erro
ORDER BY ts DESC
LIMIT 100
