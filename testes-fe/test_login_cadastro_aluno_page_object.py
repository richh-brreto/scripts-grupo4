"""
Teste de UI do login e do cadastro de aluno — padrão Page Object.
=================================================================

Organização dos arquivos:

  testes-fe/
    configuracao.py   -> URL, usuário, navegador, headless, viewport e print de erro
    navegador.py      -> abre/fecha o navegador e salva o print quando algo falha
    pagina_login.py   -> Page Object: locators e ações da tela de login
    pagina_alunos.py  -> Page Object: locators e ações da tela de alunos
    test_login_cadastro_aluno_page_object.py  -> ESTE ARQUIVO: o roteiro do teste

Instalação (uma vez, dentro de testes-fe):

    python3 -m venv .venv
    source .venv/bin/activate
    pip install playwright
    playwright install chromium

Antes de executar, deixe no ar:

  - o backend, em http://localhost:8080 (com MySQL e RabbitMQ);
  - o frontend, em http://localhost:5173. Prefira o build de produção, porque com
    "npm run dev" o React recarrega a cada alteração de arquivo e isso pode gerar
    falsos negativos:

        npm run build
        npm run preview -- --port 5173

Como executar (a senha é a do usuário administrador do seu banco):

    BOOST_SENHA='sua-senha' python3 test_login_cadastro_aluno_page_object.py

    # Sem abrir a janela do navegador:
    BOOST_HEADLESS=1 BOOST_SENHA='sua-senha' python3 test_login_cadastro_aluno_page_object.py

Atenção: o teste grava no banco apontado pelo backend. A cada execução ele cria um
aluno com e-mail único e, no final, o inativa. A API faz exclusão lógica, então o
registro continua na tabela como inativo.
"""

import sys  # usado para o código de saída do processo
import time  # usado para gerar dados únicos a cada execução
import traceback  # imprime a pilha de chamadas completa quando um teste falha

# expect() = asserções do Playwright. Elas repetem a verificação até o tempo
# limite, então já funcionam como esperas explícitas.
from playwright.sync_api import expect

# Configuração centralizada (URL, usuário, navegador, headless, viewport...).
from configuracao import ConfiguracaoTeste

# Context manager que abre/fecha o navegador e função que salva o print de erro.
from navegador import abrir_navegador, capturar_tela

# Page Objects: ocultam todos os locators e ações das telas.
from pagina_alunos import DadosAluno, PaginaAlunos
from pagina_login import PaginaLogin

# E-mail que não existe no banco, diferente a cada execução. O backend bloqueia
# um e-mail depois de 5 tentativas erradas e passa a responder 429 em vez de 401.
# Com um e-mail fixo, a etapa 3 deixaria de testar a resposta de login recusado.
EMAIL_INEXISTENTE = f"inexistente.{int(time.time())}@example.com"


def criar_aluno_de_teste() -> DadosAluno:
    """Monta um aluno com nome e e-mail únicos, para o teste poder ser repetido."""
    identificador = int(time.time())

    # O domínio example.com é reservado para testes: nunca entrega e-mail real.
    return DadosAluno(
        nome=f"Aluno Teste {identificador}",
        email=f"aluno.teste.{identificador}@example.com",
        telefone="11987654321",
        nivel="B1 - Intermediário",
    )


# -----------------------------------------------------------------------------
# ETAPA 1 — Carregamento da tela de login
# -----------------------------------------------------------------------------
def verificar_carregamento_login(login: PaginaLogin) -> None:
    """Abre a tela e valida os elementos do formulário."""

    # 1) Abre a tela de login.
    login.abrir()

    # 2) Asserção: os campos e o botão aparecem na tela?
    expect(login.campo_email).to_be_visible()
    expect(login.campo_senha).to_be_visible()
    expect(login.botao_entrar).to_have_text("Entrar")


# -----------------------------------------------------------------------------
# ETAPA 2 — Comportamento dos campos
# -----------------------------------------------------------------------------
def verificar_campos_login(login: PaginaLogin) -> None:
    """Valida o aviso de campo vazio e o botão de mostrar a senha."""

    # 1) Entra e sai do campo de e-mail sem digitar nada.
    login.tocar_campo_email_sem_preencher()

    # 2) Asserção: o aviso de campo obrigatório aparece?
    expect(login.erros_de_campo).to_have_text(login.TEXTO_CAMPO_OBRIGATORIO)

    # 3) Preenche o campo.
    login.preencher_email(EMAIL_INEXISTENTE)

    # 4) Asserção: com o campo preenchido, o aviso some?
    expect(login.erros_de_campo).to_have_count(0)

    # 5) Asserção: a senha começa oculta?
    login.preencher_senha("senha-de-teste")
    expect(login.campo_senha).to_have_attribute("type", "password")

    # 6) Asserção: depois de clicar em "Mostrar", a senha fica visível?
    login.alternar_visibilidade_senha()
    expect(login.campo_senha).to_have_attribute("type", "text")
    expect(login.botao_mostrar_senha).to_have_text("Ocultar")

    # 7) Asserção: depois de clicar em "Ocultar", a senha volta a ficar oculta?
    login.alternar_visibilidade_senha()
    expect(login.campo_senha).to_have_attribute("type", "password")


# -----------------------------------------------------------------------------
# ETAPA 3 — Login recusado
# -----------------------------------------------------------------------------
def verificar_login_invalido(login: PaginaLogin) -> None:
    """Tenta entrar com um usuário inexistente."""

    # 1) Envia o formulário com credenciais que não existem.
    login.entrar(EMAIL_INEXISTENTE, "senha-incorreta")

    # 2) Asserção: a mensagem de credenciais inválidas aparece?
    expect(login.mensagem_erro).to_have_text(login.TEXTO_CREDENCIAIS_INVALIDAS)

    # 3) Asserção: o usuário continua na tela de login?
    expect(login.pagina).to_have_url(f"{login.url_base}{login.CAMINHO}")


# -----------------------------------------------------------------------------
# ETAPA 4 — Login aceito
# -----------------------------------------------------------------------------
def verificar_login_valido(login: PaginaLogin, config: ConfiguracaoTeste) -> None:
    """Entra com o usuário administrador."""

    # 1) Envia o formulário com as credenciais da configuração.
    login.entrar(config.email_login, config.senha_login)

    # 2) Asserção: o usuário foi levado para a tela inicial do sistema?
    expect(login.pagina).to_have_url(login.url_apos_login)


# -----------------------------------------------------------------------------
# ETAPA 5 — Validação do formulário de cadastro
# -----------------------------------------------------------------------------
def verificar_validacao_cadastro(alunos: PaginaAlunos) -> None:
    """Tenta salvar o formulário sem preencher nenhum campo."""

    # 1) Abre a tela de alunos pelo menu.
    alunos.abrir()

    # 2) Asserção: a tela de alunos abriu?
    expect(alunos.pagina).to_have_url(alunos.url_alunos)
    expect(alunos.titulo_pagina).to_be_visible()

    # 3) Abre o formulário e salva sem preencher nada.
    alunos.clicar_adicionar_aluno()
    alunos.clicar_salvar()

    # 4) Asserção: o alerta lista os quatro campos inválidos?
    expect(alunos.titulo_alerta).to_have_text(alunos.TITULO_DADOS_INVALIDOS)
    expect(alunos.texto_alerta).to_have_text(alunos.TEXTO_TODOS_CAMPOS_INVALIDOS)

    # 5) Fecha o alerta.
    alunos.confirmar_alerta()

    # 6) Asserção: o formulário continua aberto, com a mesma mensagem de erro?
    expect(alunos.erro_formulario).to_have_text(alunos.TEXTO_TODOS_CAMPOS_INVALIDOS)

    # 7) Cancela. Sem nada preenchido, o formulário fecha sem pedir confirmação.
    alunos.clicar_cancelar()
    expect(alunos.modal_cadastro).to_be_hidden()


# -----------------------------------------------------------------------------
# ETAPA 6 — Cadastro de um aluno válido
# -----------------------------------------------------------------------------
def verificar_cadastro_aluno(alunos: PaginaAlunos, aluno: DadosAluno) -> None:
    """Cadastra o aluno e conclui o fluxo sem criar contrato."""

    # 1) Abre o formulário, preenche os campos e salva.
    alunos.cadastrar(aluno)

    # 2) Asserção: o sistema redirecionou para a configuração do contrato?
    expect(alunos.pagina).to_have_url(alunos.url_contratos)
    expect(alunos.modal_contrato).to_be_visible()

    # 3) Fecha o modal de contrato.
    alunos.fechar_modal_contrato()

    # 4) Asserção: o sistema pede confirmação para sair sem contrato?
    expect(alunos.titulo_alerta).to_have_text(alunos.TITULO_SAIR_SEM_CONTRATO)

    # 5) Confirma que o cadastro termina sem contrato.
    alunos.confirmar_alerta()

    # 6) Asserção: o alerta final mostra um código de acesso preenchido?
    expect(alunos.titulo_alerta).to_have_text(alunos.TITULO_ALUNO_CRIADO)
    expect(alunos.campo_codigo_acesso).not_to_have_value("")

    # 7) Esse alerta fecha sozinho em 3 segundos: espera em vez de clicar nele,
    #    o que evita disputar o clique com o temporizador.
    expect(alunos.alerta).to_be_hidden()


# -----------------------------------------------------------------------------
# ETAPA 7 — O aluno aparece na listagem
# -----------------------------------------------------------------------------
def verificar_aluno_na_listagem(alunos: PaginaAlunos, aluno: DadosAluno) -> None:
    """Procura o aluno recém-cadastrado na tela de alunos."""

    # 1) Volta para a tela de alunos e pesquisa pelo nome.
    alunos.abrir()
    alunos.buscar(aluno.nome)

    # 2) Asserção: só o aluno pesquisado aparece, com os dados informados?
    card = alunos.card_aluno(aluno.email)
    expect(card).to_have_count(1)
    expect(card).to_contain_text(aluno.nome)
    expect(card).to_contain_text(aluno.nivel)
    expect(card).to_contain_text("Ativo")


# -----------------------------------------------------------------------------
# ETAPA 8 — Bloqueio de e-mail duplicado
# -----------------------------------------------------------------------------
def verificar_email_duplicado(alunos: PaginaAlunos, aluno: DadosAluno) -> None:
    """Tenta cadastrar outro aluno usando o mesmo e-mail."""

    # 1) Tenta cadastrar com o e-mail do aluno criado na etapa 6.
    alunos.cadastrar(aluno)

    # 2) Asserção: o formulário recusa o e-mail repetido?
    expect(alunos.erro_formulario).to_have_text(alunos.TEXTO_EMAIL_DUPLICADO)

    # 3) Cancela. Com dados preenchidos, o sistema pede confirmação.
    alunos.clicar_cancelar()
    expect(alunos.titulo_alerta).to_have_text(alunos.TITULO_ALTERACOES_NAO_SALVAS)
    alunos.confirmar_alerta()

    # 4) Asserção: o formulário fechou?
    expect(alunos.modal_cadastro).to_be_hidden()


# -----------------------------------------------------------------------------
# ETAPA 9 — Inativação do aluno de teste
# -----------------------------------------------------------------------------
def verificar_inativacao_aluno(alunos: PaginaAlunos, aluno: DadosAluno) -> None:
    """Inativa o aluno, para não deixar registros de teste na lista de ativos."""

    # 1) Inativa o aluno pelo card.
    alunos.inativar(aluno.email)

    # 2) Asserção: o aluno saiu da lista de ativos?
    expect(alunos.card_aluno(aluno.email)).to_have_count(0)

    # 3) Muda o filtro para os alunos inativos.
    alunos.mostrar_inativos()

    # 4) Asserção: o aluno aparece na lista de inativos?
    expect(alunos.card_aluno(aluno.email)).to_contain_text("Inativo")


# -----------------------------------------------------------------------------
# Execução do roteiro completo
# -----------------------------------------------------------------------------
def executar_testes() -> int:
    """Roda as etapas em sequência e devolve o código de saída do processo.

    0 = tudo certo; 1 = alguma verificação falhou.
    """
    # Cria a configuração (edite configuracao.py ou use variáveis de ambiente).
    config = ConfiguracaoTeste()

    # Dados únicos desta execução.
    aluno = criar_aluno_de_teste()

    # O "with" abre o navegador no início e o fecha no final, sempre.
    # A variável "pagina" é a aba pronta para uso.
    with abrir_navegador(config) as pagina:

        # Instancia os Page Objects, informando a aba e a URL da aplicação.
        login = PaginaLogin(pagina, url_base=config.url_base)
        alunos = PaginaAlunos(pagina, url_base=config.url_base)

        try:
            # As etapas dependem da anterior: cada uma parte da tela deixada
            # pela etapa que veio antes.
            verificar_carregamento_login(login)
            verificar_campos_login(login)
            verificar_login_invalido(login)
            verificar_login_valido(login, config)
            verificar_validacao_cadastro(alunos)
            verificar_cadastro_aluno(alunos, aluno)
            verificar_aluno_na_listagem(alunos, aluno)
            verificar_email_duplicado(alunos, aluno)
            verificar_inativacao_aluno(alunos, aluno)

            # Só chega aqui se nenhuma asserção falhou.
            print("\r\n ✅ Testes passaram com sucesso! \r\n")

            # Finaliza com sucesso.
            return 0

        except Exception as e:
            # Qualquer falha (asserção ou erro do Playwright) cai aqui.
            print(f"Ocorreu um erro: {e}")

            # Imprime a pilha de chamadas para facilitar o diagnóstico.
            traceback.print_exc()

            # Salva o print da tela como evidência da falha.
            capturar_tela(pagina, config.caminho_screenshot)
            print(f"Print da tela salvo em: {config.caminho_screenshot}")

            # Finaliza indicando erro.
            return 1


# Ponto de entrada do script: só executa se o arquivo for chamado diretamente
# (e não quando for importado por outro módulo/teste).
if __name__ == "__main__":
    # sys.exit propaga o código de retorno para o terminal/CI.
    sys.exit(executar_testes())
