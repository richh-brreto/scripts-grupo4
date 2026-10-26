-- Conferência da carga: o que está na tabela do silver e o que a view descartou como mês residual
SELECT
  t.ano,
  t.mes,
  t.qtd_voos,
  t.nr_passageiros,
  v.competencia IS NOT NULL  AS entra_na_view
FROM boost_analise.voos_brasil_paises_ingleses AS t
LEFT JOIN boost_analise.vw_voos_mensal AS v
  ON v.ano = t.ano
 AND v.mes = t.mes
ORDER BY t.ano, t.mes
