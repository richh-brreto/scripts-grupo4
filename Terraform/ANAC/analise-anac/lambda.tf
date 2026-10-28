# =====================================================================
#  Ingestão: Function URL -> Lambda -> bucket bronze
#
#  Cada parte gerada pelo chunk_arquivos.py é enviada com
#  POST <url>?filename=combinadaYYYY-MM/combinadaYYYY-MM_parteNNNN.csv
#  e gravada no bronze com essa chave.
# =====================================================================

data "aws_iam_role" "lambda" {
  name = var.lambda_role_name
}

data "archive_file" "lambda_ingestao" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/.terraform/lambda_ingestao.zip" # .terraform/ já é ignorado pelo git
}

resource "aws_lambda_function" "ingestao" {
  function_name    = var.lambda_function_name
  description      = "Recebe as partes da base da ANAC pela Function URL e grava no bucket bronze"
  role             = data.aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.lambda_ingestao.output_path
  source_code_hash = data.archive_file.lambda_ingestao.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BUCKET_NAME = var.bronze_bucket
    }
  }
}

resource "aws_lambda_function_url" "ingestao" {
  function_name      = aws_lambda_function.ingestao.function_name
  authorization_type = "NONE"
}

# Function URL pública: desde out/2025 a AWS exige as duas permissões abaixo.
resource "aws_lambda_permission" "url_invoke_url" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.ingestao.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke_function" {
  statement_id  = "FunctionURLInvokeAllowPublicAccess"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestao.function_name
  principal     = "*"
}
