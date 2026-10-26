-- Índice sazonal por mês: passageiros médios do mês em relação à média geral (100 = mês típico)
WITH por_mes AS (
  SELECT
    mes,
    count(*)             AS anos_observados,
    avg(qtd_voos)        AS media_voos,
    avg(nr_passageiros)  AS media_passageiros
  FROM boost_analise.vw_voos_mensal
  GROUP BY mes
)
SELECT
  mes,
  anos_observados,
  round(media_voos)                                                       AS media_voos,
  round(media_passageiros)                                                AS media_passageiros,
  round(100 * media_passageiros / avg(media_passageiros) OVER (), 1)      AS indice_sazonal
FROM por_mes
ORDER BY mes
