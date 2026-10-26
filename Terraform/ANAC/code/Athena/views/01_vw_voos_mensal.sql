-- View: série mensal de voos Brasil -> EUA, Canadá e Reino Unido, pronta para cruzar com a base interna
-- Exclui meses residuais (menos de 10% da média de voos), como agosto/2026, que só tem
-- voos que partiram em agosto mas vieram no arquivo de julho da ANAC.
CREATE OR REPLACE VIEW boost_analise.vw_voos_mensal AS
WITH base AS (
  SELECT
    ano,
    mes,
    estacao,
    temporada,
    qtd_voos,
    nr_passageiros,
    avg(qtd_voos) OVER () AS media_voos
  FROM boost_analise.voos_brasil_paises_ingleses
)
SELECT
  date(concat(cast(ano AS varchar), '-', lpad(cast(mes AS varchar), 2, '0'), '-01')) AS competencia,
  ano,
  mes,
  estacao,
  temporada,
  qtd_voos,
  nr_passageiros,
  round(nr_passageiros * 1.0 / qtd_voos, 1)        AS passageiros_por_voo
FROM base
WHERE qtd_voos >= 0.1 * media_voos
