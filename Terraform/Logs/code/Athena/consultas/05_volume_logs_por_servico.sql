-- Volume de logs por dia, serviço, máquina e nível
SELECT
  dt,
  servico,
  node,
  nivel,
  count(*) AS eventos
FROM boost_logs.silver_containers
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4
