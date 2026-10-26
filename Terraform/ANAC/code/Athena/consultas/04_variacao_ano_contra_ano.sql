-- Variação de passageiros contra o mesmo mês do ano anterior (só meses com os dois anos)
SELECT
  atual.competencia,
  anterior.nr_passageiros                                                         AS passageiros_ano_anterior,
  atual.nr_passageiros                                                            AS passageiros,
  round(100.0 * (atual.nr_passageiros - anterior.nr_passageiros) / anterior.nr_passageiros, 1) AS variacao_pct
FROM boost_analise.vw_voos_mensal AS atual
JOIN boost_analise.vw_voos_mensal AS anterior
  ON anterior.mes = atual.mes
 AND anterior.ano = atual.ano - 1
ORDER BY atual.competencia
