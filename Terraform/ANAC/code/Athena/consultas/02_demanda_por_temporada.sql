-- Passageiros por mês em cada temporada do calendário escolar (férias, volta às aulas, período letivo)
SELECT
  temporada,
  count(*)                                AS meses,
  round(avg(qtd_voos))                    AS voos_por_mes,
  round(avg(nr_passageiros))              AS passageiros_por_mes,
  round(avg(passageiros_por_voo), 1)      AS passageiros_por_voo
FROM boost_analise.vw_voos_mensal
GROUP BY temporada
ORDER BY passageiros_por_mes DESC
