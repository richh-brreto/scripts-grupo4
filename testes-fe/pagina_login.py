# Page Object da tela de login do Boost (rota /login).
#
# PAPEL DESTE ARQUIVO:
#   Guardar TODOS os detalhes de como interagir com a tela: seletores, campos,
#   botões e os "passos" que o usuário faria (preencher, clicar, entrar). O teste
#   NÃO conhece esses detalhes; ele só chama os métodos daqui. Se o HTML mudar,
#   basta ajustar este arquivo.
#
# Componentes do frontend representados aqui:
#   src/components/login/card-form/Card.jsx
#   src/components/login/input/Input.jsx

from playwright.sync_api import Locator, Page  # tipos usados nas assinaturas


class PaginaLogin:
    """Representa a página de login.

    Recebe a "aba" do navegador (Page) já aberta e expõe:
      - propriedades com os elementos (locators) da tela;
      - métodos com as ações possíveis (abrir, preencher, entrar).
    """

    # Rota da tela e rota para onde o usuário vai depois de autenticar.
    CAMINHO = "/login"
    CAMINHO_APOS_LOGIN = "/overview"

    # Textos exibidos pela tela; centralizados para não repetir no teste.
    TEXTO_CAMPO_OBRIGATORIO = "Campo obrigatório."
    TEXTO_CREDENCIAIS_INVALIDAS = (
        "E-mail ou senha inválidos. Confira os dados e tente novamente."
    )

    def __init__(self, pagina: Page, url_base: str) -> None:
        # Guarda a aba do navegador para usar em todos os locators e ações.
        self.pagina = pagina

        # Guarda a URL da aplicação; quem cria o objeto decide onde testar.
        self.url_base = url_base

    @property
    def url_apos_login(self) -> str:
        """URL completa da tela que abre depois de um login bem-sucedido."""
        return f"{self.url_base}{self.CAMINHO_APOS_LOGIN}"

    # -------------------------------------------------------------------------
    # Navegação
    # -------------------------------------------------------------------------

    def abrir(self) -> None:
        """Navega até a tela de login."""
        self.pagina.goto(f"{self.url_base}{self.CAMINHO}")

    # -------------------------------------------------------------------------
    # Elementos da página (locators)
    #
    # São @property porque o locator do Playwright é "preguiçoso": ele só busca
    # o elemento na hora em que é usado. Assim, mesmo que o React recrie o HTML,
    # o locator continua válido.
    # -------------------------------------------------------------------------

    @property
    def campo_email(self) -> Locator:
        """Campo de e-mail."""
        return self.pagina.locator("#email")

    @property
    def campo_senha(self) -> Locator:
        """Campo de senha."""
        return self.pagina.locator("#senha")

    @property
    def botao_entrar(self) -> Locator:
        """Botão que envia o formulário (vira 'Entrando...' durante o envio)."""
        return self.pagina.locator(".login-card button[type='submit']")

    @property
    def botao_mostrar_senha(self) -> Locator:
        """Botão que alterna a senha entre visível e oculta."""
        return self.pagina.locator(".login-card .toggle")

    @property
    def erros_de_campo(self) -> Locator:
        """Avisos 'Campo obrigatório.' exibidos abaixo dos campos."""
        return self.pagina.locator(".login-card .error")

    @property
    def mensagem_erro(self) -> Locator:
        """Mensagem exibida quando o login é recusado."""
        return self.pagina.locator(".login-error")

    # -------------------------------------------------------------------------
    # Ações do usuário
    # -------------------------------------------------------------------------

    def preencher_email(self, email: str) -> None:
        """Substitui o conteúdo do campo de e-mail."""
        self.campo_email.fill(email)

    def preencher_senha(self, senha: str) -> None:
        """Substitui o conteúdo do campo de senha."""
        self.campo_senha.fill(senha)

    def tocar_campo_email_sem_preencher(self) -> None:
        """Entra e sai do campo de e-mail, o que dispara a validação de vazio."""
        self.campo_email.focus()
        self.campo_email.blur()

    def alternar_visibilidade_senha(self) -> None:
        """Clica em 'Mostrar'/'Ocultar' ao lado do campo de senha."""
        self.botao_mostrar_senha.click()

    def clicar_entrar(self) -> None:
        """Clica no botão 'Entrar'."""
        self.botao_entrar.click()

    def entrar(self, email: str, senha: str) -> None:
        """Fluxo completo de login: preenche os dois campos e envia.

        Junta as três ações em um único passo de negócio, para o teste ficar
        expressivo: `login.entrar(email, senha)`.
        """
        self.preencher_email(email)
        self.preencher_senha(senha)
        self.clicar_entrar()
