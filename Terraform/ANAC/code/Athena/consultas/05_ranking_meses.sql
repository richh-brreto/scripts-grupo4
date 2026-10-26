-- Meses com mais passageiros em toda a série
SELECT
  rank() OVER (ORDER BY nr_passageiros DESC)  AS posicao,
  competencia,
  temporada,
  qtd_voos,
  nr_passageiros
FROM boost_analise.vw_voos_mensal
ORDER BY posicao
LIMIT 10
