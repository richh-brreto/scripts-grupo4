-- IPs com mais falhas de login SSH (bastion e instâncias)
SELECT *
FROM boost_logs.vw_seguranca_ssh
WHERE falhas > 0
ORDER BY falhas DESC
LIMIT 20
