-- Conferência direto no bronze (JSON bruto): eventos por serviço e hora de chegada
SELECT
  servico,
  ano, mes, dia, hora,
  count(*)               AS eventos,
  min("timestamp")       AS primeiro,
  max("timestamp")       AS ultimo
FROM boost_logs.bronze_containers
GROUP BY 1, 2, 3, 4, 5
ORDER BY 2, 3, 4, 5, 1
