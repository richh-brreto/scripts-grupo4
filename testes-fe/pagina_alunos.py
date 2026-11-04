# Page Object da tela de alunos do Boost (rota /alunos).
#
# PAPEL DESTE ARQUIVO:
#   Guardar os detalhes de como cadastrar, localizar e inativar um aluno. O teste
#   só chama os métodos daqui, em linguagem de negócio.
#
# O cadastro não termina na tela de alunos: ao salvar, o frontend redireciona
# para /contratos e abre o modal "Configurar contrato". Os elementos desse passo
# ficam aqui porque ainda fazem parte do fluxo de cadastro do aluno.
#
# Componentes do frontend representados aqui:
#   src/components/students/Students.jsx
#   src/components/students/components/AddStudentModal.jsx
#   src/components/students/components/StudentCard.jsx
#   src/components/contracts/Contracts.jsx (fechamento do modal de contrato)

from dataclasses import dataclass  # @dataclass gera __init__/__repr__ automaticamente

from playwright.sync_api import Locator, Page  # tipos usados nas assinaturas


@dataclass
class DadosAluno:
    """Dados preenchidos no formulário 'Adicionar Aluno'."""

    nome: str
    email: str
    telefone: str  # só números: o backend aceita no máximo 11 caracteres
    nivel: str  # texto de uma das opções do select, ex.: "B1 - Intermediário"


class PaginaAlunos:
    """Representa a página de alunos e o fluxo de cadastro."""

    # Rota da tela e rota para onde o cadastro redireciona.
    CAMINHO = "/alunos"
    CAMINHO_CONTRATOS = "/contratos"

    # Textos exibidos pela tela; centralizados para não repetir no teste.
    TITULO_MODAL_CADASTRO = "Adicionar Aluno"
    TITULO_MODAL_CONTRATO = "Configurar contrato"
    TITULO_DADOS_INVALIDOS = "Dados inválidos"
    TITULO_SAIR_SEM_CONTRATO = "Sair sem criar o contrato?"
    TITULO_ALUNO_CRIADO = "Aluno criado!"
    TITULO_ALTERACOES_NAO_SALVAS = "Alterações não salvas"
    TEXTO_TODOS_CAMPOS_INVALIDOS = (
        "Verifique os seguintes campos: nome, e-mail, telefone com DDD "
        "e nível de inglês."
    )
    TEXTO_EMAIL_DUPLICADO = "Este e-mail já está cadastrado para um aluno ou professor."

    def __init__(self, pagina: Page, url_base: str) -> None:
        # Guarda a aba do navegador para usar em todos os locators e ações.
        self.pagina = pagina

        # Guarda a URL da aplicação; quem cria o objeto decide onde testar.
        self.url_base = url_base

    @property
    def url_alunos(self) -> str:
        """URL completa da tela de alunos."""
        return f"{self.url_base}{self.CAMINHO}"

    @property
    def url_contratos(self) -> str:
        """URL completa da tela de contratos."""
        return f"{self.url_base}{self.CAMINHO_CONTRATOS}"

    # -------------------------------------------------------------------------
    # Navegação
    # -------------------------------------------------------------------------

    def abrir(self) -> None:
        """Abre a tela pelo menu lateral, como o usuário faria.

        O menu só existe depois do login, então este método exige sessão ativa.
        """
        self.link_menu_alunos.click()

    # -------------------------------------------------------------------------
    # Elementos da listagem
    # -------------------------------------------------------------------------

    @property
    def link_menu_alunos(self) -> Locator:
        """Item 'Alunos' do menu lateral."""
        return self.pagina.locator(".sidebar-nav").get_by_role(
            "link", name="Alunos", exact=True
        )

    @property
    def titulo_pagina(self) -> Locator:
        """Título 'Alunos' no topo da tela."""
        return self.pagina.get_by_role("heading", name="Alunos", exact=True)

    @property
    def campo_busca(self) -> Locator:
        """Campo de busca por nome."""
        return self.pagina.get_by_placeholder("Buscar aluno por nome...")

    @property
    def botao_adicionar_aluno(self) -> Locator:
        """Botão que abre o formulário de cadastro."""
        return self.pagina.get_by_role("button", name="Adicionar aluno")

    @property
    def botao_filtro_inativos(self) -> Locator:
        """Botão do filtro que lista apenas os alunos inativos."""
        return self.pagina.get_by_role("button", name="Inativos", exact=True)

    def card_aluno(self, email: str) -> Locator:
        """Devolve o card do aluno com o e-mail informado."""
        # O e-mail é único, então identifica o card melhor do que a posição.
        return self.pagina.locator(".student-card").filter(has_text=email)

    # -------------------------------------------------------------------------
    # Elementos do formulário "Adicionar Aluno"
    # -------------------------------------------------------------------------

    @property
    def modal_cadastro(self) -> Locator:
        """Modal do formulário de cadastro."""
        return self.pagina.get_by_role("dialog", name=self.TITULO_MODAL_CADASTRO)

    @property
    def campo_nome(self) -> Locator:
        """Campo 'Nome' do formulário."""
        return self.pagina.locator("#student-create-name")

    @property
    def campo_email(self) -> Locator:
        """Campo 'Email' do formulário."""
        return self.pagina.locator("#student-create-email")

    @property
    def campo_telefone(self) -> Locator:
        """Campo 'Telefone' do formulário."""
        return self.pagina.locator("#student-create-phone")

    @property
    def select_nivel(self) -> Locator:
        """Lista de seleção 'Nível' do formulário."""
        return self.pagina.locator("#student-create-level")

    @property
    def botao_salvar(self) -> Locator:
        """Botão 'Salvar' do formulário."""
        return self.modal_cadastro.get_by_role("button", name="Salvar")

    @property
    def botao_cancelar(self) -> Locator:
        """Botão 'Cancelar' do formulário."""
        return self.modal_cadastro.get_by_role("button", name="Cancelar")

    @property
    def erro_formulario(self) -> Locator:
        """Mensagem de erro exibida dentro do formulário."""
        return self.pagina.locator(".student-form-error")

    # -------------------------------------------------------------------------
    # Elementos do modal "Configurar contrato" (aberto após o cadastro)
    # -------------------------------------------------------------------------

    @property
    def modal_contrato(self) -> Locator:
        """Modal de contrato que abre logo depois de salvar o aluno."""
        return self.pagina.get_by_role("dialog", name=self.TITULO_MODAL_CONTRATO)

    @property
    def botao_fechar_contrato(self) -> Locator:
        """Botão 'X' do modal de contrato."""
        return self.modal_contrato.get_by_role("button", name="Fechar diálogo")

    # -------------------------------------------------------------------------
    # Elementos dos alertas (SweetAlert2)
    # -------------------------------------------------------------------------

    @property
    def alerta(self) -> Locator:
        """Caixa do alerta exibido na tela."""
        return self.pagina.locator(".swal2-popup")

    @property
    def titulo_alerta(self) -> Locator:
        """Título do alerta."""
        return self.pagina.locator(".swal2-title")

    @property
    def texto_alerta(self) -> Locator:
        """Texto do alerta."""
        return self.pagina.locator(".swal2-html-container")

    @property
    def botao_confirmar_alerta(self) -> Locator:
        """Botão de confirmação do alerta."""
        return self.pagina.locator(".swal2-confirm")

    @property
    def campo_codigo_acesso(self) -> Locator:
        """Campo com o código de acesso gerado para o aluno."""
        return self.pagina.locator("#codigo-acesso-copy-input")

    # -------------------------------------------------------------------------
    # Ações do usuário
    # -------------------------------------------------------------------------

    def clicar_adicionar_aluno(self) -> None:
        """Abre o formulário de cadastro."""
        self.botao_adicionar_aluno.click()

    def preencher_formulario(self, aluno: DadosAluno) -> None:
        """Preenche todos os campos do formulário de cadastro."""
        self.campo_nome.fill(aluno.nome)
        self.campo_email.fill(aluno.email)
        self.campo_telefone.fill(aluno.telefone)
        self.select_nivel.select_option(label=aluno.nivel)

    def clicar_salvar(self) -> None:
        """Clica em 'Salvar' no formulário."""
        self.botao_salvar.click()

    def clicar_cancelar(self) -> None:
        """Clica em 'Cancelar' no formulário."""
        self.botao_cancelar.click()

    def confirmar_alerta(self) -> None:
        """Clica no botão de confirmação do alerta aberto."""
        self.botao_confirmar_alerta.click()

    def cadastrar(self, aluno: DadosAluno) -> None:
        """Fluxo completo: abre o formulário, preenche e salva."""
        self.clicar_adicionar_aluno()
        self.preencher_formulario(aluno)
        self.clicar_salvar()

    def fechar_modal_contrato(self) -> None:
        """Fecha o modal de contrato, o que pede confirmação ao usuário."""
        self.botao_fechar_contrato.click()

    def buscar(self, nome: str) -> None:
        """Pesquisa um aluno pelo nome."""
        # A tela espera 400 ms depois da digitação para consultar a API. Quem
        # chamou deve usar expect() no resultado, que já aguarda essa consulta.
        self.campo_busca.fill(nome)

    def inativar(self, email: str) -> None:
        """Clica em 'Inativar' no card do aluno."""
        self.card_aluno(email).get_by_role("button", name="Inativar").click()

    def mostrar_inativos(self) -> None:
        """Muda o filtro da listagem para os alunos inativos."""
        self.botao_filtro_inativos.click()
