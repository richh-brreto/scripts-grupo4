"""
Glue Job: boost-logs-bronze-to-silver
-------------------------------------
Lê as tabelas bronze de logs (catalogadas pelo crawler) e grava a camada silver
em Parquet particionado, atualizando o Glue Data Catalog.

  bronze_containers -> silver_containers  (partições: servico, dt)
  bronze_nginx      -> silver_nginx       (partições: tipo, dt)
  bronze_sistema    -> silver_sistema     (partições: categoria, dt)

Job bookmarks ligados: cada execução processa só arquivos novos do bronze.

Parâmetros do job: --DATABASE  --SILVER_PATH  (ex.: s3://<bucket-silver>/logs)

Execução local (sem Glue), para teste:
  python logs_bronze_to_silver.py --local <pasta_bronze_logs> <pasta_saida_silver>
"""
import sys

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F

ASSETS = ["png", "jpg", "jpeg", "gif", "svg", "webp", "ico", "css", "js",
          "map", "woff", "woff2", "ttf", "otf", "mp4", "webm", "json"]


# ----------------------------------------------------------------------------
# utilitários
# ----------------------------------------------------------------------------
def col(df: DataFrame, nome: str, tipo: str = "string"):
    """Coluna se existir no bronze; nulo tipado se ainda não apareceu nos logs."""
    return F.col(nome).cast(tipo) if nome in df.columns else F.lit(None).cast(tipo)


def base(df: DataFrame) -> dict:
    ts = F.col("timestamp").cast("timestamp")
    return {
        "ts": ts,
        "dt": F.date_format(ts, "yyyy-MM-dd"),
        "node": col(df, "node"),
        "role": col(df, "role"),
        "ambiente": col(df, "ambiente"),
    }


def id_evento(*cols):
    return F.sha2(F.concat_ws("|", *[F.coalesce(c.cast("string"), F.lit("")) for c in cols]), 256)


# ----------------------------------------------------------------------------
# transformações (PySpark puro, testáveis fora do Glue)
# ----------------------------------------------------------------------------
def transformar_containers(df: DataFrame) -> DataFrame:
    b = base(df)
    log = col(df, "log")
    mensagem = F.coalesce(col(df, "mensagem"), log)

    # nível: Spring (já extraído pelo Fluent Bit) ou MySQL "[Warning]" / "[ERROR]"
    nivel_mysql = F.upper(F.regexp_extract(log, r"^\S+\s+\d+\s+\[(\w+)\]", 1))
    nivel = F.coalesce(
        F.upper(col(df, "nivel")),
        F.when(nivel_mysql == "WARNING", "WARN")
         .when(nivel_mysql.isin("NOTE", "SYSTEM"), "INFO")
         .when(nivel_mysql == "ERROR", "ERROR"),
        F.when(col(df, "stream") == "stderr", "STDERR").otherwise("STDOUT"),
    )
    excecao = F.regexp_extract(mensagem, r"\n([\w$.]+(?:Exception|Error))\b", 1)

    out = df.select(
        b["ts"].alias("ts"),
        col(df, "servico").alias("servico"),
        b["node"].alias("node"), b["role"].alias("role"), b["ambiente"].alias("ambiente"),
        col(df, "container_name").alias("container"),
        col(df, "container_id").alias("container_id"),
        col(df, "stream").alias("stream"),
        nivel.alias("nivel"),
        col(df, "thread").alias("thread"),
        col(df, "logger").alias("logger"),
        F.split(mensagem, "\n").getItem(0).alias("mensagem"),
        F.when(excecao != "", excecao).alias("excecao"),
        log.contains("\n\tat ").alias("tem_stacktrace"),
        log.alias("log_raw"),
        b["dt"].alias("dt"),
    )
    out = out.withColumn("is_erro", F.col("nivel").isin("ERROR", "FATAL"))
    out = out.withColumn("id_evento", id_evento(F.col("node"), F.col("container_id"),
                                                F.col("ts"), F.col("log_raw")))
    return out.dropDuplicates(["id_evento"])


def transformar_nginx(df: DataFrame) -> DataFrame:
    b = base(df)
    tipo = F.coalesce(col(df, "tipo"), F.regexp_replace(col(df, "tipo_log"), "^nginx_", ""))
    xff = col(df, "x_forwarded_for")
    ip_cliente = F.when(xff.isNotNull() & (xff != "-"), F.trim(F.split(xff, ",").getItem(0))) \
                  .otherwise(col(df, "remote_addr"))
    path = col(df, "path")
    path_limpo = F.regexp_extract(path, r"^[^?#]*", 0)
    extensao = F.lower(F.regexp_extract(path_limpo, r"\.([A-Za-z0-9]+)$", 1))
    status = col(df, "status", "int")
    bytes_ = F.when(col(df, "bytes") == "-", F.lit(0)).otherwise(col(df, "bytes", "bigint"))
    ua = col(df, "user_agent")

    out = df.select(
        b["ts"].alias("ts"),
        tipo.alias("tipo"),
        b["node"].alias("node"), b["role"].alias("role"), b["ambiente"].alias("ambiente"),
        col(df, "servico").alias("origem"),          # frontend (container) ou nginx-host
        ip_cliente.alias("ip_cliente"),
        col(df, "remote_addr").alias("ip_conexao"),   # normalmente o IP interno do ALB
        col(df, "metodo").alias("metodo"),
        path_limpo.alias("path"),
        F.when(extensao != "", extensao).alias("extensao"),
        extensao.isin(*ASSETS).alias("is_asset"),
        col(df, "protocolo").alias("protocolo"),
        status.alias("status"),
        F.when(status.isNotNull(), F.concat(F.substring(status.cast("string"), 1, 1), F.lit("xx")))
         .alias("status_classe"),
        bytes_.alias("bytes"),
        col(df, "referer").alias("referer"),
        ua.alias("user_agent"),
        ua.rlike("(?i)ELB-HealthChecker|kube-probe|curl/").alias("is_healthcheck"),
        F.lower(col(df, "nivel")).alias("nivel_erro"),
        col(df, "mensagem").alias("mensagem_erro"),
        F.when(F.regexp_extract(col(df, "mensagem"), r'open\(\) "([^"]+)" failed', 1) != "",
               F.regexp_extract(col(df, "mensagem"), r'open\(\) "([^"]+)" failed', 1))
         .alias("arquivo_nao_encontrado"),
        col(df, "log").alias("log_raw"),
        b["dt"].alias("dt"),
    )
    out = out.withColumn("id_evento", id_evento(F.col("node"), F.col("ts"), F.col("log_raw")))
    return out.dropDuplicates(["id_evento"])


def transformar_sistema(df: DataFrame) -> DataFrame:
    b = base(df)
    msg = col(df, "message")
    evento_ssh = (F.when(msg.rlike(r"Failed password|Invalid user|authentication failure|Connection closed by invalid user"), "falha")
                   .when(msg.rlike(r"^Accepted (password|publickey)"), "sucesso"))

    out = df.select(
        b["ts"].alias("ts"),
        col(df, "categoria").alias("categoria"),
        b["node"].alias("node"), b["role"].alias("role"), b["ambiente"].alias("ambiente"),
        col(df, "hostname").alias("hostname"),
        col(df, "systemd_unit").alias("unidade"),
        col(df, "syslog_identifier").alias("programa"),
        col(df, "priority", "int").alias("prioridade"),
        col(df, "nivel").alias("nivel"),
        col(df, "pid", "int").alias("pid"),
        msg.alias("mensagem"),
        evento_ssh.alias("evento_ssh"),
        F.when(F.regexp_extract(msg, r"from (\d{1,3}(?:\.\d{1,3}){3})", 1) != "",
               F.regexp_extract(msg, r"from (\d{1,3}(?:\.\d{1,3}){3})", 1)).alias("ip_origem"),
        b["dt"].alias("dt"),
    )
    out = out.withColumn("is_erro", F.col("prioridade") <= 3)
    out = out.withColumn("id_evento", id_evento(F.col("node"), F.col("ts"), F.col("programa"),
                                                F.col("pid"), F.col("mensagem")))
    return out.dropDuplicates(["id_evento"])


FONTES = {
    "containers": (transformar_containers, ["servico", "dt"]),
    "nginx": (transformar_nginx, ["tipo", "dt"]),
    "sistema": (transformar_sistema, ["categoria", "dt"]),
}


# ----------------------------------------------------------------------------
# execução no AWS Glue
# ----------------------------------------------------------------------------
def main_glue():
    from awsglue.context import GlueContext
    from awsglue.dynamicframe import DynamicFrame
    from awsglue.job import Job
    from awsglue.utils import getResolvedOptions
    from pyspark.context import SparkContext

    args = getResolvedOptions(sys.argv, ["JOB_NAME", "DATABASE", "SILVER_PATH"])
    sc = SparkContext.getOrCreate()
    glue = GlueContext(sc)
    spark = glue.spark_session
    spark.conf.set("spark.sql.session.timeZone", "UTC")
    job = Job(glue)
    job.init(args["JOB_NAME"], args)

    db, silver = args["DATABASE"], args["SILVER_PATH"].rstrip("/")

    for nome, (transformar, particoes) in FONTES.items():
        try:
            dyf = glue.create_dynamic_frame.from_catalog(
                database=db, table_name=f"bronze_{nome}",
                transformation_ctx=f"bronze_{nome}")      # chave do bookmark
        except Exception as erro:                          # tabela ainda não criada
            print(f"[{nome}] ignorado: {erro}")
            continue

        df = dyf.resolveChoice(choice="cast:string").toDF()
        if df.rdd.isEmpty():
            print(f"[{nome}] nenhum arquivo novo no bronze")
            continue

        saida = transformar(df)
        print(f"[{nome}] {saida.count()} eventos -> {silver}/{nome}/")

        sink = glue.getSink(
            connection_type="s3", path=f"{silver}/{nome}/",
            enableUpdateCatalog=True, updateBehavior="UPDATE_IN_DATABASE",
            partitionKeys=particoes, transformation_ctx=f"silver_{nome}")
        sink.setFormat("glueparquet", compression="snappy")
        sink.setCatalogInfo(catalogDatabase=db, catalogTableName=f"silver_{nome}")
        sink.writeFrame(DynamicFrame.fromDF(saida, glue, f"silver_{nome}"))

    job.commit()


# ----------------------------------------------------------------------------
# execução local (teste sem AWS)
# ----------------------------------------------------------------------------
def main_local(bronze_logs: str, silver_dir: str):
    spark = (SparkSession.builder.master("local[2]").appName("teste-logs-silver")
             .config("spark.sql.session.timeZone", "UTC")
             # o crawler do Glue cataloga partições como string; reproduz isso aqui
             .config("spark.sql.sources.partitionColumnTypeInference.enabled", "false")
             .getOrCreate())
    for nome, (transformar, particoes) in FONTES.items():
        origem = f"{bronze_logs.rstrip('/')}/{nome}"
        df = spark.read.option("basePath", origem).option("recursiveFileLookup", "false").json(origem)
        saida = transformar(df)
        print(f"[{nome}] {saida.count()} eventos")
        saida.write.mode("overwrite").partitionBy(*particoes).parquet(f"{silver_dir}/{nome}")
    return spark


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--local":
        main_local(sys.argv[2], sys.argv[3])
    else:
        main_glue()
