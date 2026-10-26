-- Passageiros por mês em cada estação do ano
SELECT
  estacao,
  count(*)                                AS meses,
  round(avg(qtd_voos))                    AS voos_por_mes,
  round(avg(nr_passageiros))              AS passageiros_por_mes
FROM boost_analise.vw_voos_mensal
GROUP BY estacao
ORDER BY passageiros_por_mes DESC
