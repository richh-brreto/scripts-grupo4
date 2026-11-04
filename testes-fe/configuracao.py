# Configurações centralizadas dos testes de UI do frontend do Boost.
#
# Ficam em um único lugar para facilitar trocar de navegador, de URL ou rodar em
# CI sem mexer no código do teste nem nos Page Objects.
#
# Os dados que mudam de ambiente podem ser informados por variável de ambiente:
#   BOOST_URL      -> URL do frontend
#   BOOST_EMAIL    -> e-mail do usuário administrador
#   BOOST_SENHA    -> senha desse usuário (obrigatória, não fica no código)
#   BOOST_HEADLESS -> "1" para rodar sem abrir a janela do navegador

import os  # leitura das variáveis de ambiente
from dataclasses import dataclass, field  # @dataclass gera __init__/__repr__
from pathlib import Path  # usado para montar o caminho do print de erro
from typing import Dict, Optional  # Optional = pode ser None; Dict = dicionário tipado

# Pasta deste arquivo: o print de erro fica aqui, de onde quer que o teste rode.
PASTA_TESTES = Path(__file__).resolve().parent


@dataclass
class ConfiguracaoTeste:
    """Agrupa todas as configurações do ambiente usadas pelos testes."""

    # ---------------------------------------------------------------------
    # Aplicação testada
    # ---------------------------------------------------------------------

    # URL onde o frontend está publicado.
    # Importante: o backend só libera CORS para as portas 3000, 5173 e 8005 (veja
    # SecurityConfiguration.java). Em qualquer outra origem o navegador bloqueia
    # as chamadas à API e o login falha, mesmo com a senha certa.
    url_base: str = field(
        default_factory=lambda: os.getenv("BOOST_URL", "http://localhost:5173")
    )

    # Usuário do teste. Precisa ser administrador: só ele vê a tela "Configurar
    # contrato", que abre logo depois do cadastro do aluno.
    email_login: str = field(
        default_factory=lambda: os.getenv("BOOST_EMAIL", "admin@sptech.school")
    )

    # A senha não tem valor padrão para não ficar gravada no repositório.
    senha_login: str = field(default_factory=lambda: os.getenv("BOOST_SENHA", ""))

    # ---------------------------------------------------------------------
    # Navegador
    # ---------------------------------------------------------------------

    # Engine do Playwright que será usada: "chromium", "firefox" ou "webkit".
    navegador: str = "chromium"

    # Canal de um navegador JÁ INSTALADO no sistema (só vale para chromium):
    #   None      -> usa o Chromium baixado pelo próprio Playwright
    #   "msedge"  -> usa o Microsoft Edge instalado
    #   "chrome"  -> usa o Google Chrome instalado
    canal: Optional[str] = None

    # True  -> roda sem abrir a janela do navegador (ideal para CI/servidor)
    # False -> abre a janela, útil para acompanhar o teste "ao vivo"
    headless: bool = field(
        default_factory=lambda: os.getenv("BOOST_HEADLESS") == "1"
    )

    # ---------------------------------------------------------------------
    # Janela (viewport) e tempos de espera
    # ---------------------------------------------------------------------

    # Largura da janela em pixels.
    largura: int = 1300

    # Altura da janela em pixels.
    altura: int = 1000

    # Tempo máximo padrão, em milissegundos, que cada ação espera antes de falhar.
    timeout_padrao_ms: int = 5000

    # ---------------------------------------------------------------------
    # Diagnóstico de falhas
    # ---------------------------------------------------------------------

    # Onde salvar o print da tela quando o teste falhar. A pasta é criada
    # automaticamente caso não exista (veja capturar_tela em navegador.py).
    caminho_screenshot: str = str(
        PASTA_TESTES / "telas_erros" / "test_login_cadastro_aluno_page_object.png"
    )

    @property
    def viewport(self) -> Dict[str, int]:
        """Devolve a janela no formato que o Playwright espera: {"width", "height"}."""
        return {"width": self.largura, "height": self.altura}

    def validar(self) -> None:
        """Confere se a configuração faz sentido antes de abrir o navegador.

        Dessa forma o erro aparece como uma mensagem clara, e não como um
        traceback obscuro lá dentro do Playwright.
        """
        # Sem senha o login nunca passa: avisa antes de abrir o navegador.
        if not self.senha_login:
            raise ValueError(
                "Senha não informada. Defina a variável de ambiente BOOST_SENHA."
            )

        # Só existem três engines de navegador no Playwright.
        if self.navegador not in ("chromium", "firefox", "webkit"):
            raise ValueError(
                f"Navegador inválido: {self.navegador!r}. "
                "Use 'chromium', 'firefox' ou 'webkit'."
            )

        # "canal" (msedge/chrome) é um recurso exclusivo dos navegadores Chromium.
        if self.canal and self.navegador != "chromium":
            raise ValueError(
                f"O canal {self.canal!r} só funciona com navegador 'chromium'. "
                f"Configuração atual: {self.navegador!r}."
            )
